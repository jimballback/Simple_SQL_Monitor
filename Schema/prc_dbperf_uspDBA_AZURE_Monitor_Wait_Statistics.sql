IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbperf].[uspDBA_Monitor_Wait_Statistics]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbperf].[uspDBA_Monitor_Wait_Statistics] AS' 
END
GO
ALtER PROCEDURE [dbperf].[uspDBA_AZURE_Monitor_Wait_Statistics] 
 (       
			@snapshot_date datetime = NULL				/* use to pass in if called from a master Caller			 */   
		,	@debug bit = 0	   
        ,   @reinitialize  bit = 0                       /* used to reinitialize after a bug or some other incident is observerd
		,	@send_alert_ind bit = 0						/*	Future Use:		*/                                                          */  
    )
AS
/****************************************************************
 * 
 * NAME:  dbperf.uspDBA_AZURE_Monitor_Wait_Statistics 
 *
 * PURPOSE:	Collects information of all waits  for all processes. 
 * DESCRIPTION: Logs all wait events within a polling time period.
 *
 *
 * USAGE: 
 *		Log Data:	exec dbperf.uspDBA_AZURE_Monitor_Wait_Statistics @debug=0
 *		Debug Mode:	exec dbperf.uspDBA_AZURE_Monitor_Wait_Statistics 	@DEBUG=1 
 *		Reinitalize: exec dbperf.uspDBA_AZURE_Monitor_Wait_Statistics  @reinitialize = 1
 *
 * AUTHOR: James Nafpliotis	LAST MODIFIED BY: 
 * CREATED: 08/31/2007 MODIFIED ON:4/27/2023
 *
 *	DNaf        11/06/2009  version added for sql 2005 . Filters out innoccuous wait type specified in the view
 *              [vw_innocuous_wait_types].
 *  DNaf        4/05/2010  bug fix --- wait types that did not ocur in the previous interval and were  not getting recorded.
 *             wait types of zero are readdedd for now
 *				8/3/2022 -- added Azure version	AND used filter based on from Paul Randal sql skills recommendations.
 *
 *****************************************************************/
		
	SET NOCOUNT ON
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED  --  Do Not need to use any lock resources

	
	DECLARE	@step varchar(80)					/* the user defined step of the procedure for debugging and error handling */
			
		
	DECLARE @instance_last_started datetime		/* the time the instance was last started */
	DECLARE @last_snapshot_date datetime		/* thelast snapshot date											*/
	DECLARE @interval_in_seconds numeric(18,2)	/* the interval in seconds of the snapshot to do rate calculations */
	DECLARE @physical_memory_mb int
	DECLARE @logical_processor_count int
	DECLARE @first_measure_from_start bit
	DECLARE @instance_id INTEGER

									/* IO stalls in milliseconds per IO operation  */
	CREATE TABLE #dba_wait_summary 
    (  [instance_id] int  NULL
    ,  [snapshot_date] [datetime]  NULL 
    ,  [wait_type] [varchar](100)  NULL
    ,  [wait_requests] [numeric](18,2)  NULL
    ,  [wait_time]  [numeric](18,2)  NULL
    ,  [signal_wait_time]  [numeric](18,2)  NULL
    ,  [cumulative_wait_requests] [numeric](18,2)  NOT NULL
    ,  [cumulative_wait_time]  [numeric](18,2)  NOT NULL
    ,  [cumulative_signal_wait_time]  [numeric](18,2) NOT NULL 
    ,  [interval_in_seconds][numeric] (18,2)  NULL 
    ,  [first_measure_from_start] [bit]  NULL
    ,  [date_archived] [datetime]   NULL                        
    )

	BEGIN
--------------------------------------------- date initialization ------------------------------------
	--- SINCE THIS IS USED BY MULTIPLE PROCS...  LOOK INTO POSSIBLE FUNCTION
	-- take into account that the server may be rebooted
	SELECT @step = 'Initialization'
	SELECT   
			@snapshot_date = ISNULL(@snapshot_date,CURRENT_TIMESTAMP)
		--- best guess for Azure
		,	@instance_last_started = sqlserver_start_time
		 FROM sys.dm_os_sys_info

		--sqlserver_start_time

--- instance id. Used if you use the whole suite of  perf scripts.
	IF (SELECT count(*) FROM dbperf.dba_instance) = 0
		BEGIN
			SELECT @instance_id = 0
		END
		ELSE
		BEGIN
			SELECT @instance_id  = max(instance_id) FROM dbperf.dba_instance;
		END
		--- Get the last snapshot date, if any has been recorded.
	SELECT 
			@last_snapshot_date = MAX(snapshot_date)
	FROM [dbperf].[DBA_wait_summary]
	------ check the snapshot date
	---- if blank or less than the instance start , create the first baseline record.
	IF (
		(	@last_snapshot_date IS NULL ) -- nothing exists
		OR
		 ( @last_snapshot_date < @instance_last_started ) 
		OR (@reinitialize = 1)
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

	IF @debug = 1
		BEGIN
			SELECT @step as step
				,	@last_snapshot_date as last_snapshot_date
				,	@interval_in_seconds as interval_in_seconds
				,	@first_measure_from_start AS first_measure_from_start
		END		

	BEGIN TRY
		
		SELECT @step = 'Load Temp table'

-- INTIAL TABLE VARIABLE of the current cumulative stats
    INSERT 
    INTO #dba_wait_summary
      (

		    [wait_type]
        ,   [cumulative_wait_requests]
        ,   [cumulative_wait_time]
        ,   [cumulative_signal_wait_time]
        ,   [snapshot_date]
        ,   [instance_id]


      )

	SELECT
		wait_type
	,	waiting_tasks_count
	,	wait_time_ms
	,	signal_wait_time_ms
    ,   @snapshot_date
    ,   @instance_id
	FROM sys.dm_os_wait_stats
	WHERE wait_type Not in (SELECT wait_type FROM dbperf.vw_innocuous_wait_types)

		-- waiting_tasks_count > 0   commented out 4/5/2010
    	
    IF @debug = 1
		BEGIN
			SELECT @step AS step, * FROM  #dba_wait_summary
		END		
		
	SELECT @step = 'Calculate interval Values'                         

    -- update total amount for the interval... if  it is the first measure from start then it is the
   -- same as cumulative
    IF (@first_measure_from_start = 1)
              BEGIN
                update #dba_wait_summary
                SET         

                  [wait_requests]           = [cumulative_wait_requests]
                ,  [wait_time]               = [cumulative_wait_time]
                ,  [signal_wait_time]        = [cumulative_signal_wait_time]
                ,  [interval_in_seconds]     = @interval_in_seconds
                ,  [first_measure_from_start] =  @first_measure_from_start

              END
              ELSE
                BEGIN
                -- since we may remove waits that no longer needed to be recorded.
                -- we need to perform a  LEFT JOIN TO keep the current waits.

            -- BUG --- procedure was not recording if the wait did not occur on the last  interval
            -- records all for now. 
			---  in order to keep recrods low, need to dynamicallly determine the last snapshot for each  --- record
                  UPDATE #dba_wait_summary
                  SET         
					   [wait_requests]           = curr.[cumulative_wait_requests] - isnull(prev.[cumulative_wait_requests],0)
                    ,  [wait_time]               = curr.[cumulative_wait_time]     -  isnull(prev.[cumulative_wait_time],0)
                    ,  [signal_wait_time]        = curr.[cumulative_signal_wait_time]  - isnull(prev.[cumulative_signal_wait_time],0)
                    ,  [interval_in_seconds]     = @interval_in_seconds
                    ,  [first_measure_from_start] =  @first_measure_from_start
					FROM #dba_wait_summary curr
					LEFT OUTER 
					JOIN 
                    (   SELECT 
                            prev.[wait_type]
                           , max(snapshot_date) as last_snapshot_date
                         FROM  dba_wait_summary prev
                        WHERE snapshot_date >=@instance_last_started                 
                        GROUP BY wait_type
                        ) as lastsnap
                    ON lastsnap.wait_type = curr.wait_type
                     LEFT
                    JOIN  dba_wait_summary prev
						ON lastsnap.wait_type = prev.wait_type
                        AND  prev.snapshot_date =lastsnap.last_snapshot_Date 
                        
     IF @debug = 1
		BEGIN
			select @step as step, * from  #dba_wait_summary
		END		

                 
	
				
					
				 END
	SELECT @step = 'To Be Loaded'			 
	IF @debug = 1
		BEGIN
			SELECT  @step AS step
			,@interval_in_seconds AS interval_variable
			,	[instance_id]
              , [snapshot_date]
              , [wait_type]
              , [wait_requests]
              , [wait_time]
              , [signal_wait_time]
              , [cumulative_wait_requests]
              , [cumulative_wait_time]
              , [cumulative_signal_wait_time]
              , [interval_in_seconds]
              , [first_measure_from_start]
              FROM #dba_wait_summary
              WHERE wait_requests > 0 
			RETURN 0 
		END		
		
			SELECT @step = 'Performance Table Insert'

            INSERT 
            INTO [dbperf].[dba_wait_summary]
              (
				[instance_id]
              , [snapshot_date]
              , [wait_type]
              , [wait_requests]
              , [wait_time]
              , [signal_wait_time]
              , [cumulative_wait_requests]
              , [cumulative_wait_time]
              , [cumulative_signal_wait_time]
              , [interval_in_seconds]
              , [first_measure_from_start]

              )
             SELECT
				[instance_id]
              , [snapshot_date]
              , [wait_type]
              , [wait_requests]
              , [wait_time]
              , [signal_wait_time]
              , [cumulative_wait_requests]
              , [cumulative_wait_time]
              , [cumulative_signal_wait_time]
              , @interval_in_seconds
              , [first_measure_from_start]
              FROM #dba_wait_summary
              WHERE wait_requests > 0 
		--	IF @debug = 1
		--	BEGIN
		--		select @step as step, * from  [dbperf].[dba_wait_summary]
		--		Where snapshot_date  = @snapshot_date 
		--	IF @@TRANCOUNT > 0	ROLLBACK TRAN
		--	RETURN 0
		--END		
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
		RETURN -1
	END CATCH;
RETURN 0
  
END



GO


