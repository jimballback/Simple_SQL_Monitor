IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbperf].[uspDBA_AZURE_Monitor_DBUsage]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbperf].[uspDBA_AZURE_Monitor_DBUsage] AS' 
END
GO
ALTER PROCEDURE [dbperf].[uspDBA_AZURE_Monitor_DBUsage]  
		(      
			@snapshot_date datetime = NULL		/* use to pass in if called from a job with other per procs			 */   
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
 * DESCRIPTION: Replaces [dbadmin].[uspDBA_Monitor_DBUsage] , which was still using sql 2000 VUews
 *		Tables: [dbperf].[DBA_TableUsage],[dbperf].[DBA_FileUsage]
 * Replacec the old old one built in 2007. This version only supports user tables at the moment
 * USAGE: exec [dbperf].[uspDBA_AZURE_Monitor_DBUsage] 
 *	DEBUG: exec [dbperf].[uspDBA_AZURE_Monitor_DBUsage] @debug = 1
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
	DECLARE @stmt nvarchar(4000)					/* loop though each database. removing sp_msforeachdb */
	DECLARE @database_name sysname					

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
	[total_table_object_size_used_in_Gb] [numeric](18, 2) NOT NULL,
	[total_table_object_size_allocated_in_Gb] [numeric](18, 3) NOT NULL, 
	[total_table_object_size_used_in_Mb] [numeric](18, 3) NOT NULL,-- add extra decimals for small kb tables
	[total_table_object_size_allocated_in_Mb] [numeric](18, 3) NOT NULL,-- add extra decimals for small kb tables
	[row_count] [bigint] NOT NULL,
	[partition_count] [integer] NOT NULL,
	[index_count]	[integer] NOT NULL,
	[column_count] [smallint] NOT NULL,
	[filegroup_count] [integer] NOT NULL,
	[table_type] [varchar](30) NOT NULL,
	[table_create_date] [datetime] NOT NULL,
	[table_modification_date] [datetime] NOT NULL,
	[db_filegroup_name] [sysname] NOT NULL,
	[database_name] [sysname] NOT NULL,
	[last_statistics_date] [datetime] NULL,
	[dml_cnt_since_stats_dt] [bigint] NULL,
) 	
SELECT @step = 'DEBUG: INSERT TEMP TABLE DBA_TableUsage'

		
		
----- Replacing  undocumented proc sp_msforeachdb due to 2000 char limit
--- group by container_id  to include Lob data, Lob data has the same hobt_id
--Columns that are of the large object (LOB) data types ntext, text, varchar(max), nvarchar(max), varbinary(max), xml, or image 
--cant be specified as key columns for an index.

SELECT @max_database_id = MAX(DATABASE_ID) FROM sys.databases WHERE state_desc = 'ONLINE'
WHILE @iteration  <= @max_database_id
BEGIN
  SELECT @database_name = DB_NAME( @iteration)				 
	SET @stmt = N'use '+@database_name+'; 
INSERT INTO #DBA_TableUsage
([instance_id]
,[snapshot_date]
,[schema_name]
,[table_name]
,[total_table_object_size_used_in_Gb]
,[total_table_object_size_allocated_in_Gb]
,[total_table_object_size_used_in_Mb]
,[total_table_object_size_allocated_in_Mb]
,[row_count]
,[partition_count]
 ,[index_count]
 ,[column_count]
 ,[filegroup_count]
 ,[table_type]
,[table_create_date]
,[table_modification_date]
,[db_filegroup_name]
,[database_name]
,[last_statistics_date]
,[dml_cnt_since_stats_dt])
SELECT 
NULL
,	NULL
,	S.name AS [schema_name]
,	t.name AS [table_name]
,	[table_size_used_in_Gb]			+ ISNULL(index_size_used_in_Gb,0) AS [total_table_object_size_used_in_Gb]
,	[table_size_allocated_in_Gb]	+ ISNULL(index_size_allocated_in_Gb,0) AS [total_table_size_allocated_in_Gb]
,	[table_size_used_in_Mb]			+ ISNULL(index_size_used_in_mb,0) AS [total_table_size_used_in_Mb]
,	[table_size_allocated_in_Mb]	+ ISNULL(index_size_allocated_in_mb,0) AS [total_table_size_allocated_in_Mb]
,	num_rows AS row_count
,	num_partitions AS [partition_count]
,	ISNULL([index_count],0) AS [index_count]
,	c.column_count  AS [column_count]
,	filegroup_count
,	t.type_desc as [table_type]
,	t.create_date AS [table_create_date]
,	t.modify_date AS  [table_modification_date]
,	Case when num_partitions > 1 then ''Partitioned'' else [filegroup_name] end AS [db_filegroup_name]
,	db_name()	AS [database_name]
,	STATS_DATE(t.object_id, p2.index_id) AS [last_statistics_date]
,	modification_counter AS [dml_cnt_since_stats_dt]
FROM sys.schemas s
JOIN sys.tables t
ON s.schema_id =t.schema_id
JOIN  
(select object_id,count(*) AS column_count
from sys.columns c
group by object_id
) AS c
ON t.object_id = c.object_id
JOIN 
(	SELECT	
object_id
,MAX(index_id) AS index_id
,sum(rows) AS num_rows
,MAX(partition_number) AS num_partitions  
,MAX([table_size_used_in_Gb]) AS  [table_size_used_in_Gb]
,MAX([table_size_allocated_in_Gb]) AS  [table_size_allocated_in_Gb]
 ,MAX([table_size_used_in_Mb]) AS  [table_size_used_in_Mb]
,MAX([table_size_allocated_in_Mb]) AS  [table_size_allocated_in_Mb]
,MAX(filegroup_count) AS  filegroup_count
,max(d.name) AS  [filegroup_name]
FROM sys.partitions p
JOIN 
(SELECT 		
container_id
,	MAX(data_space_id) AS filegroup_count
,	MIN(data_space_id) AS data_space_id
,	SUM(u.used_pages)  * 8.192/1024.0/1024.0 AS [table_size_used_in_Gb]
,	SUM(u.total_pages)* 8.192/1024.0/1024.0 AS [table_size_allocated_in_Gb]
,	SUM(u.used_pages)  * 8.192/1024.0 AS [table_size_used_in_Mb]
,	SUM(u.total_pages)* 8.192/1024.0 AS [table_size_allocated_in_Mb]
FROM sys.allocation_units u
GROUP BY container_id
) AS u
ON u.container_id = p.hobt_id
JOIN sys.data_spaces d
ON d.data_space_id =u.data_space_id
WHERE index_id <=1
GROUP BY object_id
) AS p2
ON p2.object_id=t.object_id
LEFT JOIN
(SELECT object_id
,sum(total_pages*8.192/1024.0/1024.0) AS index_size_allocated_in_Gb
,sum(used_pages*8.192/1024.0/1024.0) AS [index_size_used_in_Gb]
,sum(total_pages*8.192/1024.0) AS index_size_allocated_in_mb
,sum(used_pages*8.192/1024.0) AS [index_size_used_in_Mb]
,count(*) AS index_count
FROM sys.partitions AS p
JOIN sys.allocation_units AS au    
ON p.hobt_id = au.container_id
AND index_id >=2
GROUP BY object_id,partition_number
) AS total
ON total.object_id = t.object_id
OUTER APPLY  sys.dm_db_stats_properties(t.object_id,p2.index_id) sp
'
IF @debug = 1
BEGIN
SELECT @step  as step , @database_name as database_name,@iteration as iteration 
print @stmt
END
exec sp_executesql @stmt
SELECT @iteration = @iteration+1

END -- END WHILE

UPDATE #DBA_tableusage 
set instance_id = @instance_id
	,snapshot_date=@snapshot_date



				SELECT @step = 'DEBUG: INSERT MAIN TABLE DBA_TableUsage'

IF @debug = 1
	BEGIN
	SELECT @step
	SELECT 
	[instance_id]
           ,[snapshot_date]
           ,[schema_name]
           ,[table_name]
           ,[total_table_object_size_used_in_Gb]
           ,[total_table_object_size_used_in_Mb]
           ,[total_table_object_size_allocated_in_Gb]
           ,[total_table_object_size_allocated_in_Mb]
           ,[row_count]
		   ,[index_count]
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
	return 0
	END
		INSERT INTO [dbperf].[DBA_TableUsage]
           ([instance_id]
           ,[snapshot_date]
           ,[schema_name]
           ,[table_name]
           ,[total_table_object_size_used_in_Gb]
           ,[total_table_object_size_used_in_Mb]
           ,[total_table_object_size_allocated_in_Gb]
           ,[total_table_object_size_allocated_in_Mb]
           ,[row_count]
		   ,[index_count]
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
	[instance_id]
           ,[snapshot_date]
           ,[schema_name]
           ,[table_name]
           ,[total_table_object_size_used_in_Gb]
           ,[total_table_object_size_used_in_Mb]
           ,[total_table_object_size_allocated_in_Gb]
           ,[total_table_object_size_allocated_in_Mb]
           ,[row_count]
		   ,[index_count]
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
           ,[total_table_object_size_used_in_Gb]
           ,[total_table_object_size_allocated_in_Gb]
           ,[total_table_object_size_used_in_Mb]
           ,[total_table_object_size_allocated_in_Mb]
           ,[row_count]
           ,[partition_count]
           ,[index_count]
           ,[column_count]
           ,[filegroup_count]
           ,[table_type]
           ,[table_create_date]
           ,[table_modification_date]
           ,[db_filegroup_name]
           ,[database_name]
           ,[last_statistics_date]
           ,[dml_cnt_since_stats_dt])

	SELECT 
			@instance_id
		,	@snapshot_date
        ,	S.name AS [schema_name]
        ,	t.name AS [table_name]
		,	[table_size_used_in_Gb]			+ ISNULL(index_size_used_in_Gb,0) AS [total_table_object_size_used_in_Gb]
        ,	[table_size_allocated_in_Gb]	+ ISNULL(index_size_allocated_in_Gb,0) AS [total_table_size_allocated_in_Gb]
        ,	[table_size_used_in_Mb]			+ ISNULL(index_size_used_in_mb,0) AS [total_table_size_used_in_Mb]
		,	[table_size_allocated_in_Mb]	+ ISNULL(index_size_allocated_in_mb,0) AS [total_table_size_allocated_in_Mb]
        ,	num_rows AS row_count
        ,	num_partitions AS [partition_count]
        ,	ISNULL([index_count],0) AS [index_count]
		,	c.column_count  AS [column_count]
		,	filegroup_count
		,	t.type_desc as [table_type]
		,	t.create_date AS [table_create_date]
		,	t.modify_date AS  [table_modification_date]
		,	Case when num_partitions > 1 then 'Partitioned' else [filegroup_name] end AS [db_filegroup_name]
		,	db_name()	AS [database_name]
		,	STATS_DATE(t.object_id, p2.index_id) AS [last_statistics_date]
		,	modification_counter AS [dml_cnt_since_stats_dt]
FROM sys.schemas s
	JOIN sys.tables t
		ON s.schema_id =t.schema_id
	JOIN  
	(
		select object_id,count(*) AS column_count
		from sys.columns c
		group by object_id
	) AS c
	ON t.object_id = c.object_id
	JOIN 
	(
		SELECT	
		object_id
		,MAX(index_id) AS index_id
		,sum(rows) AS num_rows
		,MAX(partition_number) AS num_partitions  
		,MAX([table_size_used_in_Gb]) AS  [table_size_used_in_Gb]
        ,MAX([table_size_allocated_in_Gb]) AS  [table_size_allocated_in_Gb]
        ,MAX([table_size_used_in_Mb]) AS  [table_size_used_in_Mb]
        ,MAX([table_size_allocated_in_Mb]) AS  [table_size_allocated_in_Mb]
		,MAX(filegroup_count) AS  filegroup_count
		,max(d.name) AS  [filegroup_name]
		FROM sys.partitions p
		JOIN 
		(--- group by container_id  to include Lob data, Lob data has the same hobt_id
		-- 
			SELECT 		
			container_id
		,	MAX(data_space_id) AS filegroup_count
		,	MIN(data_space_id) AS data_space_id
		,	SUM(u.used_pages)  * 8.192/1024.0/1024.0 AS [table_size_used_in_Gb]
		,	SUM(u.total_pages)* 8.192/1024.0/1024.0 AS [table_size_allocated_in_Gb]
		,	SUM(u.used_pages)  * 8.192/1024.0 AS [table_size_used_in_Mb]
		,	SUM(u.total_pages)* 8.192/1024.0 AS [table_size_allocated_in_Mb]
			FROM sys.allocation_units u
			GROUP BY container_id
		) AS u
			ON u.container_id = p.hobt_id
		JOIN sys.data_spaces d
			ON d.data_space_id =u.data_space_id
		WHERE index_id <=1
		GROUP BY object_id
	) AS p2
		ON p2.object_id=t.object_id
	-- indexes
	LEFT JOIN
	(	--Columns that are of the large object (LOB) data types ntext, text, varchar(max), nvarchar(max), varbinary(max), xml, or image 
		--cant be specified as key columns for an index.
		SELECT object_id
		,sum(total_pages*8.192/1024.0/1024.0) AS index_size_allocated_in_Gb
		,sum(used_pages*8.192/1024.0/1024.0) AS [index_size_used_in_Gb]
		,sum(total_pages*8.192/1024.0) AS index_size_allocated_in_mb
		,sum(used_pages*8.192/1024.0) AS [index_size_used_in_Mb]
		,count(*) AS index_count
		FROM sys.partitions AS p
		JOIN sys.allocation_units AS au    
		ON p.hobt_id = au.container_id
		AND index_id >=2
		GROUP BY object_id,partition_number
	) AS total
		ON total.object_id = t.object_id
	OUTER APPLY  sys.dm_db_stats_properties(t.object_id,p2.index_id) sp
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