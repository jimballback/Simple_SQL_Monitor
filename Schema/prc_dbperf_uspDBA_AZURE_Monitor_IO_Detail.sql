IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbperf].[uspDBA_AZURE_Monitor_IO_Detail]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbperf].[uspDBA_AZURE_Monitor_IO_Detail] AS' 
END
GO
ALTER PROCEDURE [dbperf].[uspDBA_AZURE_Monitor_IO_Detail]  
		(      
			@log_data_ind bit  = 0				/* Indicator specifying whether to log this in xadmindb				  */
		,	@snapshot_date datetime = NULL		/* use to pass in if called from a job with other per procs			 */   
		,	@send_alert_ind bit = 0				/*	Future Use:		*/
		,	@debug bit = 0																
  )
AS
/****************************************************************
*
* 
* NAME:	[dbperf].[uspDBA_AZURE_Monitor_IO_Detail]   
*
* PURPOSE:  Monitors io down to the database file level for the specified interval
*						This does not take into account other programs that are using the file system!
* DESCRIPTION: Complete change vs on-premversion  since you cannot use or need to use sys.master_files
*              
*                Per occurring per IO operation in which over 20 ms is bad 
*							
* USAGE:  
		EXEC [dbperf].[uspDBA_AZURE_Monitor_IO_Detail]  @DEBUG =0
* DEBUG:  
			EXEC [dbperf].[uspDBA_AZURE_Monitor_IO_Detail]  @DEBUG =1
*							Each record holds the IO delta measurements during the specified interval
*							Each Record also holds the cumulative number from the start of the instance, which will help
*							in calculating the deltas for a particular interval 
*							The data is stored primarily in the dbperf.dba_filestats table
*				AZURE:
*				DB_ID('tempdb'); retunrs null.. hardcoding 2
*				will only log tempdb and the user database
* Dependencies:	dbperf schema
*					dbperf.dba_filestats table
*					dbperf.[dba_instance] adds dummy record if needed
 *****************************************************************************************/
SET NOCOUNT ON
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED  --  Do Not need to use any lock resources

	DECLARE	@step varchar(80)					/* The user defined step of the procedure for debugging and error handling	*/
			
		
	DECLARE @instance_last_started DATETIME		/* The time the instance was last started */
	DECLARE @last_snapshot_date DATETIME		/* The last snapshot date. indicates the last measurement recorded.			*/
	DECLARE @interval_in_seconds BIGINT			/* The interval in seconds of the snapshot to perform rate calculations.	*/
	DECLARE @server_name SYSNAME				/* The name of the instance.												*/
	DECLARE @first_measure_from_start BIT
	DECLARE @instance_id INTEGER
	DECLARE @EngineEdition INT					/* The database engine id that shwos the SQL product type.					*/
	DECLARE @database_id INT					/*
												--https://learn.microsoft.com/en-us/sql/t-sql/functions/db-id-transact-sql?view=sql-server-ver16
												When used with Azure SQL Database, DB_ID may not return the same result as querying database_id from sys.databases. 
												If the caller of DB_ID is comparing the result to other sys views, then sys.databases should be queried instead.
												*/
	BEGIN
	BEGIN TRY
		SELECT @step = 'Initialization'
		CREATE TABLE #dba_filestats
		( 
			instance_id int
		,	snapshot_date datetime   
		,	database_name sysname
		,	logical_filename sysname
		,	db_file_name varchar(8000)
		,	db_file_type varchar(50)
		,	num_of_reads bigint
		,	num_of_writes bigint
		,	num_of_bytes_read bigint
		,	num_of_bytes_written bigint
		,	io_stall_ms bigint
		,	io_stall_reads_ms bigint
		,	io_stall_writes_ms bigint
		,	size_on_disk_MB numeric(9,2)
		,	interval_in_seconds int
		,	cumulative_num_of_reads bigint
		,	cumulative_num_of_writes bigint
		,	cumulative_num_of_bytes_read bigint
		,	cumulative_num_of_bytes_written bigint
		,	cumulative_io_stall_ms bigint
		,	cumulative_io_stall_reads_ms bigint
		,	cumulative_io_stall_writes_ms bigint
		,	first_measure_from_start bit not null
		)	

	--------------------------------------------- date initialization ------------------------------------
---		Get the SQL product type
		SELECT @EngineEdition = CAST(SERVERPROPERTY('EngineEdition') AS INT);
-- Take into account that the server may be rebooted
		SELECT   
			@snapshot_date = ISNULL(@snapshot_date,CURRENT_TIMESTAMP)
		,	@server_name = @@servername
		--- best guess for Azure
		,	@instance_last_started = sqlserver_start_time
		FROM sys.dm_os_sys_info

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
		FROM dbperf.dba_filestats


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
		---- get the database id for an azure database.
		IF (@EngineEdition = 5 )
		BEGIN
			SELECT @database_id = [database_id] FROM sys.databases WHERE [name] <>'master'
		END
		SELECT @step = 'DEBUG: Variable Values'
--- DEBUG: display variables
		IF @debug = 1
		BEGIN
			SELECT @step as step, @instance_id as instance_id,@snapshot_date as snapshot_date ,@last_snapshot_date as last_napshot_date, @instance_last_started as instance_last_started ,@database_id As database_id
			,@first_measure_from_start as first_measure_from_start
		END		
	--------------------- intialize table vairiable --------------------------------


		
		SELECT @step = 'load table variable'
		IF @debug = 1
		BEGIN
			select	@step			as step
			,	@instance_id	as instance_id
			,	@snapshot_date	as snapshot_date
			,	D.NAME			as  [database_name]
			,	DF.NAME			as	[logical_filename]
			,	PHYSICAL_NAME	as	[db_file_name]
			,	TYPE_DESC		as	[db_file_type]
			,	[num_of_reads]
			,	[num_of_writes]
			,	[num_of_bytes_read]
			,	[num_of_bytes_written]
			,	io_stall					as	[io_stall_ms]
			,	[io_stall_read_ms]			AS	[io_stall_reads_ms]
			,	[io_stall_write_ms]			AS [io_stall_writes_ms]
           	,	cast( 
           		size_on_disk_bytes/1024.0/1024.0 
           			as numeric(9,2)
           			)						as		size_on_disk_MB 
			,	@interval_in_seconds as interval_in_seconds
			,	[num_of_reads]	as [cumulative_num_of_reads]
			,	[num_of_writes]	as[cumulative_num_of_writes]
			,	[num_of_bytes_read]	as [cumulative_num_of_bytes_read]
			,	[num_of_bytes_written]	as [cumulative_num_of_bytes_written]
			,	io_stall			as	[cumulative_io_stall_ms]
			,	[io_stall_read_ms]	as	[cumulative_io_stall_reads_ms]
			,	[io_stall_write_ms]	as	[cumulative_io_stall_writes_ms]
			,	@first_measure_from_start as first_measure_from_start
           
		FROM sys.dm_io_virtual_file_stats( @database_id,null) fs
		JOIN sys.databases D
			ON fs.database_id = D.database_id
		JOIN sys.database_files DF
			ON fs.file_id = DF.file_id

		SELECT
				@instance_id
			,	@snapshot_date
			,	'tempdb'	as  [database_name]
			,	case when file_id =1 then 'tempdb data unknown'
					 when file_id =2 then 'tempdb log unknown'
					 else 'unk'end	as	[logical_filename]
			,	case when file_id =1 then 'tempdb data unknown'
					 when file_id =2 then 'tempdb log unknown'
					 else 'unk'end	as	[db_file_name]
			,	case when file_id =1 then 'data'
					 when file_id =2 then 'log'
					 else 'unk'end as	[db_file_type]
			,	[num_of_reads]
			,	[num_of_writes]
			,	[num_of_bytes_read]
			,	[num_of_bytes_written]
			,	io_stall					as	[io_stall_ms]
			,	[io_stall_read_ms]			AS	[io_stall_reads_ms]
			,	[io_stall_write_ms]			AS [io_stall_writes_ms]
			,	cast( 
           		size_on_disk_bytes/1024.0/1024.0 
           			as numeric(9,2)
           			)						as		size_on_disk_MB 
			,	@interval_in_seconds
			,	[num_of_reads]			as [cumulative_num_of_reads]
			,	[num_of_writes]			as	[cumulative_num_of_writes]
			,	[num_of_bytes_read]		as [cumulative_num_of_bytes_read]
			,	[num_of_bytes_written]	as [cumulative_num_of_bytes_written]
			,	io_stall				as	[cumulative_io_stall_ms]
			,	[io_stall_read_ms]		as	[cumulative_io_stall_reads_ms]
			,	[io_stall_write_ms]		as	[cumulative_io_stall_writes_ms]
			,	@first_measure_from_start
         
		FROM sys.dm_io_virtual_file_stats(2,null) fs
-- tempdb data 

		END		
	
		INSERT 
		INTO #dba_filestats
			(
				[instance_id]
           ,	[snapshot_date]
           ,	[database_name]
           ,	[logical_filename]
           ,	[db_file_name]
           ,	[db_file_type]
           ,	[num_of_reads]
           ,	[num_of_writes]
           ,	[num_of_bytes_read]
           ,	[num_of_bytes_written]
           ,	[io_stall_ms]
           ,	[io_stall_reads_ms]
           ,	[io_stall_writes_ms]
           ,	[size_on_disk_MB] 
           ,	[interval_in_seconds]
           ,	[cumulative_num_of_reads]
           ,	[cumulative_num_of_writes]
           ,	[cumulative_num_of_bytes_read]
           ,	[cumulative_num_of_bytes_written]
           ,	[cumulative_io_stall_ms]
           ,	[cumulative_io_stall_reads_ms]
           ,	[cumulative_io_stall_writes_ms]
           ,	[first_measure_from_start]
           )
       SELECT
				@instance_id
           ,	@snapshot_date
		   ,	D.NAME	as  [database_name]
           ,	DF.NAME				as	[logical_filename]
           ,	PHYSICAL_NAME			as	[db_file_name]
           ,	TYPE_DESC			as	[db_file_type]
           ,	[num_of_reads]
           ,	[num_of_writes]
           ,	[num_of_bytes_read]
           ,	[num_of_bytes_written]
           ,	io_stall					as	[io_stall_ms]
           ,	[io_stall_read_ms]			AS	[io_stall_reads_ms]
           ,	[io_stall_write_ms]			AS [io_stall_writes_ms]
           ,	cast( 
           			size_on_disk_bytes/1024.0/1024.0 
           			as numeric(9,2)
           			)						as		size_on_disk_MB 
           ,	@interval_in_seconds
           ,	[num_of_reads]			as	[cumulative_num_of_reads]
           ,	[num_of_writes]			as	[cumulative_num_of_writes]
           ,	[num_of_bytes_read]		as	[cumulative_num_of_bytes_read]
           ,	[num_of_bytes_written]	as	[cumulative_num_of_bytes_written]
           ,	io_stall				as	[cumulative_io_stall_ms]
           ,	[io_stall_read_ms]		as	[cumulative_io_stall_reads_ms]
           ,	[io_stall_write_ms]		as	[cumulative_io_stall_writes_ms]
           ,	@first_measure_from_start
           
		FROM sys.dm_io_virtual_file_stats(@database_id,null) fs
		JOIN sys.databases D
			ON fs.database_id = D.database_id
		JOIN sys.database_files DF
			ON fs.file_id = DF.file_id
		UNION
		SELECT
				@instance_id
			,	@snapshot_date
			,	'tempdb'	as  [database_name]
			,	case when file_id =1 then 'tempdb data unknown'
					 when file_id =2 then 'tempdb log unknown'
					 else 'unk'end	as	[logical_filename]
			,	case when file_id =1 then 'tempdb data unknown'
					 when file_id =2 then 'tempdb log unknown'
					 else 'unk'end	as	[db_file_name]
			,	case when file_id =1 then 'data'
					 when file_id =2 then 'log'
					 else 'unk'end as	[db_file_type]
			,	[num_of_reads]
			,	[num_of_writes]
			,	[num_of_bytes_read]
			,	[num_of_bytes_written]
			,	io_stall					as	[io_stall_ms]
			,	[io_stall_read_ms]			AS	[io_stall_reads_ms]
			,	[io_stall_write_ms]			AS [io_stall_writes_ms]
			,	cast( 
           		size_on_disk_bytes/1024.0/1024.0 
           			as numeric(9,2)
           			)						as		size_on_disk_MB 
			,	@interval_in_seconds
			,	[num_of_reads]			as [cumulative_num_of_reads]
			,	[num_of_writes]			as	[cumulative_num_of_writes]
			,	[num_of_bytes_read]		as [cumulative_num_of_bytes_read]
			,	[num_of_bytes_written]	as [cumulative_num_of_bytes_written]
			,	io_stall				as	[cumulative_io_stall_ms]
			,	[io_stall_read_ms]		as	[cumulative_io_stall_reads_ms]
			,	[io_stall_write_ms]		as	[cumulative_io_stall_writes_ms]
			,	@first_measure_from_start
         
		FROM sys.dm_io_virtual_file_stats(2,null) fs
-- tempdb data 
		IF @debug = 1
		BEGIN
			select @step as step, * from #dba_filestats
		END
	SELECT @step = 'Calculate Delta'			
----- update if  this is not the firts measure from start
	-- logical_name is unique within each database
	IF (@first_measure_from_start=0)
		BEGIN
			UPDATE #dba_filestats
				set 
			num_of_reads = curr.[cumulative_num_of_reads] - prev.[cumulative_num_of_reads]
           ,num_of_writes =curr.[cumulative_num_of_writes] - prev.[cumulative_num_of_writes]
           ,num_of_bytes_read=curr.[cumulative_num_of_bytes_read] - prev.[cumulative_num_of_bytes_read]
           ,num_of_bytes_written=curr.[cumulative_num_of_bytes_written] - prev.[cumulative_num_of_bytes_written]
           ,io_stall_ms=curr.[cumulative_io_stall_ms]		 - prev.[cumulative_io_stall_ms]
           ,io_stall_reads_ms  = curr.[cumulative_io_stall_reads_ms]	 - prev.[cumulative_io_stall_reads_ms]
           ,io_stall_writes_ms = curr.[cumulative_io_stall_writes_ms] - prev.[cumulative_io_stall_writes_ms]
			FROM  #dba_filestats CURR
			LEFT JOIN dbperf.dba_filestats prev
			ON	curr.database_name = prev.database_name
			AND curr.logical_filename = prev.logical_filename
			AND (prev.snapshot_date = @last_snapshot_date)
	
		END
        SELECT @step = 'Performanc Table Insert'			--- final insert 
		INSERT INTO [dbperf].[dba_Filestats]
           ([instance_id]
           ,[snapshot_date]
           ,[database_name]
           ,[logical_filename]
           ,[db_file_name]
           ,[db_file_type]
           ,[num_of_reads]
           ,[num_of_writes]
           ,[num_of_bytes_read]
           ,[num_of_bytes_written]
           ,[io_stall_ms]
           ,[io_stall_reads_ms]
           ,[io_stall_writes_ms]
           ,[size_on_disk_MB]
           ,[interval_in_seconds]
           ,[cumulative_num_of_reads]
           ,[cumulative_num_of_writes]
           ,[cumulative_num_of_bytes_read]
           ,[cumulative_num_of_bytes_written]
           ,[cumulative_io_stall_ms]
           ,[cumulative_io_stall_reads_ms]
           ,[cumulative_io_stall_writes_ms]
           ,[first_measure_from_start])

		SELECT [instance_id]
           ,[snapshot_date]
           ,[database_name]
           ,[logical_filename]
           ,[db_file_name]
           ,[db_file_type]
           ,[num_of_reads]
           ,[num_of_writes]
           ,[num_of_bytes_read]
           ,[num_of_bytes_written]
           ,[io_stall_ms]
           ,[io_stall_reads_ms]
           ,[io_stall_writes_ms]
           ,[size_on_disk_MB]
           ,[interval_in_seconds]
           ,[cumulative_num_of_reads]
           ,[cumulative_num_of_writes]
           ,[cumulative_num_of_bytes_read]
           ,[cumulative_num_of_bytes_written]
           ,[cumulative_io_stall_ms]
           ,[cumulative_io_stall_reads_ms]
           ,[cumulative_io_stall_writes_ms]
           ,[first_measure_from_start]
		   FROM #dba_filestats

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

 

  
END