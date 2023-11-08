IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbperf].[uspDBA_AZURE_Monitor_Performance]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbperf].[uspDBA_AZURE_Monitor_Performance] AS' 
END
GO
ALTER procedure dbperf.uspDBA_AZURE_Monitor_Performance
(
			@log_data_ind bit  = 0						/* Indicator specifying whether to log this in xadmindb				  */
		,	@snapshot_date datetime = NULL    /* use to pass in if called from a job with other per procs			 */   
		,	@send_alert_ind bit = 0					/*	Future Use:		*/
		,	@debug bit = 1
	
		)
 As
 
/*****************************************************************************************
 *
 * NAME: dbperf.uspDBA_AZURE_Monitor_Performance
 *
 * PURPOSE:			Azure version of calculating select SQL Server performance counters.
 * DESCRIPTION:		Calculates  and records from the DMV sys.dm_os_performance_counters.
 *					Counter types 537003264 and 1073939712 counter types are a snapshot of
 *					the ratio if the counter name and counter name base.
 * INSTALLATION:	Install on a seperated schema in Azure SQL database.
 * USAGE: 
 *		
 *	one time execution:
 *		exec dbperf.uspDBA_AZURE_Monitor_Performance  @debug =0
 *
 * DEBUG:  
 *		exec dbperf.uspDBA_AZURE_Monitor_Performance  @debug =1
 *
 *	Latest Version: 4/4/2023 
 *  Created By: James Nafpliotis
 *
 *****************************************************************************************/
 
SET NOCOUNT ON
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED  --  Do Not need to use any lock resources

	DECLARE	@step varchar(80)					/* The user defined step of the procedure for debugging and error handling */
			
		
	DECLARE @instance_last_started DATETIME		/* The time the instance was last started */
	DECLARE @last_snapshot_date DATETIME		/* The last snapshot date. indicates the last measurement recorded.										*/
	DECLARE @interval_in_seconds BIGINT			/* The interval in seconds of the snapshot to perform rate calculations. */
	DECLARE @server_name SYSNAME				/* The name of the instance.   */
	DECLARE @first_measure_from_start BIT
	DECLARE @instance_id INTEGER


 
 	 CREATE TABLE #dba_Instance_perf_snap 
	(	[instance_id] INTEGER NOT NULL DEFAULT 0
	,	[snapshot_date] DATETIME NOT NULL
	,	[inst_perf_param_id] INTEGER NOT NULL
	,	[instance_perf_value] BIGINT  NULL
	,	[cumulative_perf_value] BIGINT NULL
	,	[startup_measure_ind] BIT NOT NULL
	,   [measurement_interval_s] INTEGER NOT NULL
	,	[counter_nm] VARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
	,	[counter_type] INTEGER
	,	[parent_param_id] INTEGER NULL
	);

	--------------------------------------------- date initialization ------------------------------------
	
-- Take into account that the server may be rebooted
		SELECT   
			@snapshot_date = ISNULL(@snapshot_date,CURRENT_TIMESTAMP)
		,	@server_name = @@servername
		--- best guess for Azure
		,	@instance_last_started = sqlserver_start_time
		 FROM sys.dm_os_sys_info

		sqlserver_start_time
--- instance id. Used if you use the whole suite of  perf scripts.
		IF (select count(*) from dbperf.dba_instance) = 0
		BEGIN
			select @instance_id = 0
		END
		ELSE
		BEGIN
			SELECT @instance_id  = max(instance_id) from dbperf.dba_instance;
		END

		--- Get the last snapshot date, if any has been recorded.
		SELECT 
				@last_snapshot_date = MAX(snapshot_date)
		FROM dbperf.dba_Instance_perf_snap


	------ check the snapshot date
	---- if blank or less than the instance start , create the first baseline record.
		IF (
			(	@last_snapshot_date IS NULL ) -- nothing exists
			OR
		 	( @last_snapshot_date < @instance_last_started ) 
		)
		BEGIN
			SELECT
					@interval_in_seconds = DATEDIFF(S,@instance_last_started,@snapshot_date)
				,	@first_measure_from_start = 1
        END
		ELSE
		BEGIN
			SELECT 
					@interval_in_seconds = DATEDIFF(S,@last_snapshot_date,@snapshot_date)
                ,	@first_measure_from_start = 0				
        END
	
		SELECT @step = 'DEBUG: Variable Values'
--- DEBUG: display variables
		IF @debug = 1
		BEGIN
			SELECT @step as step, @instance_id as instance_id,@snapshot_date as snapshot_date ,@last_snapshot_date as last_napshot_date, @instance_last_started as instance_last_started 
			,@first_measure_from_start as first_measure_from_start
		END		

-- begin error handling 
	BEGIN TRY
		
		SELECT @step = 'Load Temp table'

		INSERT 
		INTO #dba_Instance_perf_snap
        (
			[instance_id]
         ,	[snapshot_date]
         ,	[inst_perf_param_id]
		 ,	[instance_perf_value]
        ,	[cumulative_perf_value]
        ,	[startup_measure_ind]
        ,	[measurement_interval_s]
        ,	[counter_nm]  -- need this so we can acces this this multiple times
        ,	[counter_type]
        ,	[parent_param_id]
		) -- need this so we can acces this this multiple times
		SELECT 
			@instance_id,@snapshot_date, inst_perf_param_id,null,abs(cntr_value) ,@first_measure_from_start
		,	@interval_in_seconds,counter_name,counter_type,[parent_param_id]

		FROM sys.dm_os_performance_counters c
	
		JOIN [dbperf].[dba_instance_perf_param] p
		ON c.[object_name] =p.[object_nm]
		AND c.[counter_name] = p.[counter_nm]
		AND c.[instance_name] =p.[instance_nm]
		WHERE [log_ind] = 1
		
		IF @debug = 1
		BEGIN
			select    @step AS step ,* from #dba_Instance_perf_snap
		END		

		SELECT @step = 'Calculate interval Values'
			
		IF @debug = 1
		BEGIN		
			select    @step AS step ,* 
			FROM  #dba_Instance_perf_snap curr
			LEFT OUTER
			JOIN [dbperf].dba_Instance_perf_snap prev
				ON curr.inst_perf_param_id =prev.inst_perf_param_id
			  AND prev.snapshot_date =@last_snapshot_date
			  order by counter_nm desc
		END	

		/* Update total amount for the interval... if  it is the first measure from start then it is the
			same as  the cumulative value.
		*/
		IF (@first_measure_from_start = 1) -- dont bother calculating the first measure when we are int
		BEGIN
			UPDATE #dba_Instance_perf_snap
			SET         instance_perf_value =       [cumulative_perf_value]
		END
-- ELSE use the calcualtions
		ELSE
		BEGIN
		--Fix: you need to treat 537003264 and 1073939712 as just a snapshot.  the difference calculation is totally incorrect. probably we will need to make sure the base is  not zero.
		-- use a view or other code to perform the ratio calculation on the fly instead from [dbperf].dba_Instance_perf_snap table.
			UPDATE #dba_Instance_perf_snap
			SET   instance_perf_value=     CASE 
											WHEN counter_type = '272696576'
											THEN    (curr.[cumulative_perf_value] - isnull(prev.[cumulative_perf_value],0))/@interval_in_seconds 
											WHEN counter_type in('1073874176',-1)   -- will calculate 1073874176 types in a seperate step
											THEN    (curr.[cumulative_perf_value] - isnull(prev.[cumulative_perf_value],0))
											ELSE isnull(curr.[cumulative_perf_value] ,0)
											END
			FROM  #dba_Instance_perf_snap curr
			LEFT OUTER
			JOIN [dbperf].dba_Instance_perf_snap prev
				ON curr.inst_perf_param_id =prev.inst_perf_param_id
			  AND prev.snapshot_date =@last_snapshot_date
		END

		SELECT @step = '1073874176 counter type ratio calculation'
			--------  1073874176 counter type ratio calculation. This calculation is based on the values incremented during the interval as opposed to cumulative like '537003264'
		update curr
		set		instance_perf_value =  curr.[instance_perf_value] 
					/  case when child.instance_perf_value = 0 
							then 1 
							else isnull(child.[instance_perf_value],1)
					   end
		FROM  #dba_Instance_perf_snap  curr
		JOIN  #dba_Instance_perf_snap as child
		ON child.parent_param_id = curr.inst_perf_param_id
		WHERE  curr.counter_type = '1073874176'


		IF @debug = 1
		BEGIN
			select    @step AS step ,* from #dba_Instance_perf_snap
			order by counter_nm desc
		END

		SELECT @step = 'Performance Table Insert'

		IF @debug = 1
		BEGIN 
			SELECT  @step AS step 

		,	[instance_id]
        ,	[snapshot_date]
        ,	[inst_perf_param_id]
        ,	[instance_perf_value]
        ,	[cumulative_perf_value]
        ,	[startup_measure_ind]
        ,	[measurement_interval_s]
			FROM #dba_Instance_perf_snap
			where [instance_perf_value] is not null
		END
		ELSE
		BEGIN

			INSERT 
			INTO [dbperf].[dba_Instance_perf_snap]
		(	[instance_id]
		,	[snapshot_date]
		,	[inst_perf_param_id]
		,	[instance_perf_value]
		,	[cumulative_perf_value]
		,	[startup_measure_ind]
		,	[measurement_interval_s]
		)
			SELECT 
			[instance_id]
        ,	[snapshot_date]
        ,	[inst_perf_param_id]
        ,	[instance_perf_value]
        ,	[cumulative_perf_value]
        ,	[startup_measure_ind]
        ,	[measurement_interval_s]
			FROM #dba_Instance_perf_snap
			WHERE [instance_perf_value] is not null

		END

	
	END TRY
	BEGIN CATCH
		DECLARE @ErrorMessage NVARCHAR(4000);
		DECLARE @ErrorSeverity INT;
		DECLARE @ErrorState INT;

		SELECT 
        @ErrorMessage = ERROR_MESSAGE()+CHAR(13)+'Procedure step: '+ coalesce(@step,'UNKNOWN'),
        @ErrorSeverity = ERROR_SEVERITY(),
        @ErrorState = ERROR_STATE();


    -- Use RAISERROR inside the CATCH block to return error
    -- information about the original error that caused
    -- execution to jump to the CATCH block.
		RAISERROR (@ErrorMessage, -- Message text.
               @ErrorSeverity, -- Severity.
               @ErrorState -- State.
               );
	return -1
	END CATCH;
