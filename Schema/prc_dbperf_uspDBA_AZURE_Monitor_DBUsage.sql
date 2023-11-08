IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbperf].[uspDBA_AZURE_Monitor_DBUsage]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbperf].[uspDBA_AZURE_Monitor_DBUsage] AS' 
END
GO
ALTER PROCEDURE [dbperf].[uspDBA_AZURE_Monitor_DBUsage]  
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
 * NAME: exec [dbperf].[uspDBA_AZURE_Monitor_DBUsage] 
 *
 * PURPOSE:		Summarizes daily object sizes, file sizes 
 * DESCRIPTION: Replaces [dbadmin].[uspDBA_Monitor_DBUsage] , whichas still unsing sql 2000 VUews
 *		Tables: [dbperf].[DBA_TableUsage],[dbperf].[DBA_FileUsage]
 *
 * USAGE: exec [dbperf].[uspDBA_AZURE_Monitor_DBUsage] 
 * AUTHOR: James Nafpliotis	LAST MODIFIED BY: $Author:  $
 * CREATED: 6/20/2023	LAST MODIFIED ON: $Modtime: $
 * CURRENT REVISION: $Revision:  $
 * HISTORY (Most recent first): $History:  $
 * 
 * Updated in $
 *
 * 
 *****************************************************************/SELECT db_name() as daabase_name,db_id()
BEGIN
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
	DECLARE @max_database_id int					/* the max  database id in sys.databases. For looping insteadof using sp_MSFOReachdb */
	DECLARE @iteration int =1						/* start of database iteration */


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
		BEGIN TRY

IF (@EngineEdition <= 4 OR  @EngineEdition =8) -- Azure SQL Managed Instance
			BEGIN
------------------------BEGIN on Prem,IAAS -----------------------------------
				CREATE TABLE #DBA_FileUsage
				(
					[instance_id] [int] NULL,
					[snapshot_date] [datetime] NULL,
					[database_name] [sysname] NULL,
					[logical_file_name] [sysname] NOT NULL,
					[db_file_type] [nvarchar](60) NULL,
					[db_file_name] [nvarchar](256) NULL,
					[db_file_state] [nvarchar](60) NULL,
					[db_filegroup_name] [sysname] NOT NULL,
					[db_file_size_in_mb] [numeric](18, 2) NULL,
					[db_file_used_in_mb] [numeric](18, 2) NULL
				)

				SELECT @step = 'DEBUG: INSERT TEMP TABLE [DBA_FileUsage]'

				EXEC sp_MSforeachdb 
				@command1 =  'use [?] ;

				INSERT INTO #DBA_FileUsage
				(	[database_name]
				,	[logical_file_name]
				,	[db_file_type]
				,	[db_file_name]
				,	[db_file_state]
				,	[db_filegroup_name]
				,	[db_file_size_in_mb]
				,	[db_file_used_in_mb])
				SELECT
					db_name() as [database_name]
				,	df.name as  [logical_file_name]
				,	df.type_desc as db_file_type
				,	df.physical_name
				,	df.state_desc
				,	case when df.type_desc =''LOG'' then ''LOG'' else ds.name end  as [db_filegroup_name]
				,	CAST(size*8.00/1024.00 AS numeric(18,2)) as size_MB
				,	CAST(ISNULL(FILEPROPERTY(df.name,''spaceused''),0)*8.00/1024.00 AS numeric(18,2))  as alloc_MB
				
				FROM sys.database_files  df
				Left 
				JOIN  sys.data_spaces ds
					on ds.data_space_id = df.data_space_id'
				SELECT @step = 'DEBUG: UPDATE TEMP TABLE'
				UPDATE #DBA_FileUsage set instance_id = @instance_id
						,snapshot_date=@snapshot_date

				SELECT @step = 'DEBUG: INSERT MAIN TABLE [DBA_FileUsage]'

				INSERT 
				INTO [dbperf].[DBA_FileUsage]
				(	[instance_id]
				,	[snapshot_date]
				,	[database_name]
				,	[logical_file_name]
				,	[db_file_type]
				,	[db_file_name]
				,	[db_file_state]
				,	[db_filegroup_name]
				,	[db_file_size_in_mb]
				,	[db_file_used_in_mb])
				SELECT [instance_id]
				,	[snapshot_date]
				,	[database_name]
				,	[logical_file_name]
				,	[db_file_type]
				,	[db_file_name]
				,	[db_file_state]
				,	[db_filegroup_name]
				,	[db_file_size_in_mb]
				,	[db_file_used_in_mb]
				FROM #DBA_FileUsage


CREATE TABLE #DBA_TableUsage(

	[instance_id] [int] NULL,
	[snapshot_date] [datetime] NULL,
	[schema_name] [sysname] NOT NULL,
	[table_name] [sysname] NOT NULL,
	[total_table_object_size_used_in_mb] [numeric](18, 2) NOT NULL,
	[total_table_object_size_used_in_kb] [numeric](18, 2) NOT NULL,
	[total_table_object_size_allocated_in_mb] [numeric](18, 2) NOT NULL,
	[total_table_object_size_allocated_in_kb] [numeric](18, 2) NOT NULL,
	[row_count] [bigint] NOT NULL,
	[partition_count] [integer] NOT NULL,
	[filegroup_count] [integer] NOT NULL,
	[table_type] [varchar](30) NOT NULL,
	[column_count] [smallint] NOT NULL,
	[table_create_date] [datetime] NOT NULL,
	[table_modification_date] [datetime] NOT NULL,
	[db_filegroup_name] [sysname] NOT NULL,
	[database_name] [sysname] NOT NULL,
	[last_statistics_date] [datetime] NULL,
	[dml_cnt_since_stats_dt] [bigint] NULL,
) 	
				SELECT @step = 'DEBUG: INSERT TEMP TABLE DBA_TableUsage'


				EXEC sp_MSforeachdb 
				@command1 =  '
				use [?] ;


INSERT INTO #DBA_TableUsage
           ([instance_id]
           ,[snapshot_date]
           ,[schema_name]
           ,[table_name]
           ,[total_table_object_size_used_in_mb]
           ,[total_table_object_size_used_in_kb]
           ,[total_table_object_size_allocated_in_mb]
           ,[total_table_object_size_allocated_in_kb]
           ,[row_count]
           ,[partition_count]
           ,[filegroup_count]
           ,[table_type]
           ,[column_count]
           ,[table_create_date]
           ,[table_modification_date]
           ,[db_filegroup_name]
           ,[database_name]
           ,[last_statistics_date]
           ,[dml_cnt_since_stats_dt]
         )

	SELECT
			NULL
			,NULL
			,s.name as schema_nm
			,t.name as table_nm
			,Used_Space_mb
			,Used_Space_kb
			,Total_Reserved_mb
			,Total_Reserved_kb
			,p2.num_rows
			,num_partitions
			,filegroup_count
			,t.type_desc
			,column_count
			,t.create_date
			,t.modify_date
			,Case when num_partitions > 1 then ''Partitioned'' else  [filegroup_name] end
			,db_name()as db
			,STATS_DATE(t.object_id, p2.index_id) as [last_statistics_date]
			,modification_counter as [dml_cnt_since_stats_dt]
 
	FROM sys.schemas s
	JOIN sys.tables t
		ON s.schema_id =t.schema_id
	JOIN  (select object_id,count(*) as column_count
			from sys.columns c
			group by object_id
		) as c
		ON t.object_id = c.object_id
	JOIN
		(
		SELECT	
			object_id
			,index_id
			,sum(rows) as num_rows
			,max(partition_number) as num_partitions  
		,SUM(u.total_pages) * 8.192 AS Total_Reserved_kb
		,SUM(u.used_pages) * 8.192 AS Used_Space_kb
		,SUM(u.total_pages) * 8.192/1024.0 AS Total_Reserved_mb
		,SUM(u.used_pages) * 8.192/1024.0 AS Used_Space_mb
		,max(u.data_space_id) as filegroup_count
		,max(d.name) as [filegroup_name]
		from sys.partitions p
		join sys.allocation_units AS u
			ON u.container_id = p.hobt_id
		JOIN sys.data_spaces d
			on d.data_space_id =u.data_space_id
		where index_id <=1
		group by object_id,index_id
	) as p2
		ON p2.object_id=t.object_id
	outer apply  sys.dm_db_stats_properties(t.object_id,p2.index_id) sp
	order by p2.num_rows desc
'
				UPDATE #DBA_tableusage set instance_id = @instance_id
						,snapshot_date=@snapshot_date


				SELECT @step = 'DEBUG: INSERT MAIN TABLE DBA_TableUsage'
INSERT INTO [dbperf].[DBA_TableUsage]
           ([instance_id]
           ,[snapshot_date]
           ,[schema_name]
           ,[table_name]
           ,[total_table_object_size_used_in_mb]
           ,[total_table_object_size_used_in_kb]
           ,[total_table_object_size_allocated_in_mb]
           ,[total_table_object_size_allocated_in_kb]
           ,[row_count]
           ,[partition_count]
           ,[filegroup_count]
           ,[table_type]
           ,[column_count]
           ,[table_create_date]
           ,[table_modification_date]
           ,[db_filegroup_name]
           ,[database_name]
           ,[last_statistics_date]
           ,[dml_cnt_since_stats_dt])
	SELECT [instance_id]
           ,[snapshot_date]
           ,[schema_name]
           ,[table_name]
           ,[total_table_object_size_used_in_mb]
           ,[total_table_object_size_used_in_kb]
           ,[total_table_object_size_allocated_in_mb]
           ,[total_table_object_size_allocated_in_kb]
           ,[row_count]
           ,[partition_count]
           ,[filegroup_count]
           ,[table_type]
           ,[column_count]
           ,[table_create_date]
           ,[table_modification_date]
           ,[db_filegroup_name]
           ,[database_name]
           ,[last_statistics_date]
           ,[dml_cnt_since_stats_dt]
		   FROM #DBA_TableUsage
	END

	IF (@EngineEdition =5)
		BEGIN
		INSERT 
		INTO [dbperf].[DBA_FileUsage]
           ([instance_id]
           ,[snapshot_date]
           ,[database_name]
           ,[logical_file_name]
           ,[db_file_type]
           ,[db_file_name]
           ,[db_file_state]
           ,[db_filegroup_name]
           ,[db_file_size_in_mb]
           ,[db_file_used_in_mb]
		   )
		 SELECT
					@instance_id 
				,	@snapshot_date
				,	db_name() as [database_name]
				,	df.name as  [logical_file_name]
				,	df.type_desc as db_file_type
				,	df.physical_name
				,	df.state_desc
				,	case when df.type_desc ='LOG' then 'LOG' else ds.name end  as [db_filegroup_name]
				,	CAST(ISNULL(FILEPROPERTY(df.name,'spaceused'),0)*8.00/1024.00 AS numeric(18,2))  as alloc_MB
				,	CAST(size*8.00/1024.00 AS numeric(18,2)) as size_MB
		FROM sys.database_files  df
		Left 
		JOIN  sys.data_spaces ds
			on ds.data_space_id = df.data_space_id

		INSERT INTO [dbperf].[DBA_TableUsage]
           ([instance_id]
           ,[snapshot_date]
           ,[schema_name]
           ,[table_name]
           ,[total_table_object_size_used_in_mb]
           ,[total_table_object_size_used_in_kb]
           ,[total_table_object_size_allocated_in_mb]
           ,[total_table_object_size_allocated_in_kb]
           ,[row_count]
           ,[partition_count]
           ,[filegroup_count]
           ,[table_type]
           ,[column_count]
           ,[table_create_date]
           ,[table_modification_date]
           ,[db_filegroup_name]
           ,[database_name]
           ,[last_statistics_date]
           ,[dml_cnt_since_stats_dt])

		SELECT
				@instance_id
			,@snapshot_date
			,s.name as schema_nm
			,t.name as table_nm
			,Used_Space_mb
			,Used_Space_kb
			,Total_Reserved_mb
			,Total_Reserved_kb
			,p2.num_rows
			,num_partitions
			,filegroup_count
			,t.type_desc
			,column_count
			,t.create_date
			,t.modify_date
			,Case when num_partitions > 1 then 'Partitioned' else  [filegroup_name] end
			,db_name()as db
			,STATS_DATE(t.object_id, p2.index_id) as [last_statistics_date]
			,modification_counter as [dml_cnt_since_stats_dt]
 
	FROM sys.schemas s
	JOIN sys.tables t
		ON s.schema_id =t.schema_id
	JOIN  (select object_id,count(*) as column_count
			from sys.columns c
			group by object_id
		) as c
		ON t.object_id = c.object_id
	JOIN
		(
		SELECT	
			object_id
			,index_id
			,sum(rows) as num_rows
			,max(partition_number) as num_partitions  
		,SUM(u.total_pages) * 8.192 AS Total_Reserved_kb
		,SUM(u.used_pages) * 8.192 AS Used_Space_kb
		,SUM(u.total_pages) * 8.192/1024.0 AS Total_Reserved_mb
		,SUM(u.used_pages) * 8.192/1024.0 AS Used_Space_mb
		,max(u.data_space_id) as filegroup_count
		,max(d.name) as [filegroup_name]
		from sys.partitions p
		join sys.allocation_units AS u
			ON u.container_id = p.hobt_id
		JOIN sys.data_spaces d
			on d.data_space_id =u.data_space_id
		where index_id <=1
		group by object_id,index_id
	) as p2
		ON p2.object_id=t.object_id
	outer apply  sys.dm_db_stats_properties(t.object_id,p2.index_id) sp
	order by p2.num_rows desc
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
		IF @@TRANCOUNT >0 ROLLBACK TRAN
		RETURN -1
	END CATCH;
RETURN 0
  
END