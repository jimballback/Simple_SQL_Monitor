USE [XAdminDB]
GO

/****** Object:  StoredProcedure [dbadmin].[uspDBA_Monitor_DBUsage]    Script Date: 6/19/2023 10:32:52 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER OFF
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbadmin].[uspDBA_Monitor_DBUsage]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbadmin].[uspDBA_Monitor_DBUsage] AS' 
END
GO

ALTER PROCEDURE [dbadmin].[uspDBA_Monitor_DBUsage]


as
/****************************************************************
 *
 * 
 * NAME: exec [dbadmin].[uspDBA_Monitor_DBUsage] 
 *
 * PURPOSE:  Summarizes daily object sizes, file sizes, and disk sizes.
 * DESCRIPTION: Will alert if a disk threshold is specified on the server level.
 *				Typically since this procedure is usually run daily, you may increase this threshold
 *				To give advanced warning.
 *	
 *
 * USAGE: exec spDBA_Monitor_Daily_DBUsage @disk_freepct_threshold = 15.00
 * AUTHOR: James Nafpliotis	LAST MODIFIED BY: $Author:  $
 * CREATED: 5/23/2007	LAST MODIFIED ON: $Modtime: $
 *  Jnaf     4/16/2010 --- changed stored procedure name in preparation of rewrite.
 *  Jnaf	12/10/2010 -- removed Disk capacity alerting as that is now taken care of by another process.
 * CURRENT REVISION: $Revision:  $
 * HISTORY (Most recent first): $History:  $
 * 
 * Updated in $
 *
 * 
 *****************************************************************/
	DECLARE			
            @errno int,                                     /* used to return a number on error              */
            @errmsg varchar(50),                            /* used for custom on the fly errror messages   */
            @err_param1 varchar(50),                        /* the first error parameter passed that interpolates based on the sysmessages entry */
            @err_param2 varchar(50),                        /* the second error parameter passed that interpolates based on the sysmessages entry */
            @syserror varchar(6),                           /*  a system error code checked via  system error function @@error to determine that an error occured  */
            @operational_modification_date datetime, 				/* the date the operations fields in the target system wil haave populated within a transaaction */
            @tran_id UNIQUEIDENTIFIER,            					/* standard  operations hist field specifying a transaction   */
            @stmt_id UNIQUEIDENTIFIER,             					/* standard  operations hist field specifying a dml statement */
						@rowcount int																		/* a count of records returned from the last statement				*/		
	DECLARE @snapshot_date datetime														/* the date of this snapshot 							*/
	DECLARE @server_name sysname															/* the name of the server...   */
	DECLARE @diskmessage	varchar(1000)																		/* disk aleret message				*/
	SET NOCOUNT ON
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED  --  Do Not need to use any lock resources

	BEGIN
	
-------------------- intialization ----------------------------------------------------------------------
	
SELECT @syserror = 0   -- sql 2000 error handling backward compatible

--------------------------------------------- retrieve all the filegroup names ---------------------
-- For each databaase retrieve all the filegroup names
				CREATE 
				TABLE #group
				( 
					dbid 					int					/* the database key for a particular instance on master..sysdatabases */
				,	database_name sysname
				,	groupid 			int	  	/* the filegroup key int is own sysfilegroups table			*/
				,	db_filegroup_name 		sysname /* the name of the file group within a particular database */
				)

				CREATE 
				TABLE #db_filestats -- restriction required for spMS_foreachdb 128 characters */
					(	fileid 						int					/* the database key for a particular instance on master..sysdatabases */
					,	groupid 					int
					,	totalpages			bigint	  	/* the filegroup key int is own sysfilegroups table			*/
					,	usedpages				bigint
					,	logical_file_name	sysname /* the name of the file group within a particular database */
					,	db_file_name 			sysname	
					,	dbid							int)

		CREATE 
		TABLE #DBA_TableUsage
	 (		[dbid] 							[int] 					NOT NULL 
		,	[database_name] 		[sysname] 			NOT NULL 
		,	[db_filegroup_name] [sysname] 			NOT NULL 
		,	[Table_name] 				[sysname] 			NOT NULL
		, [Table_size_used_in_mb]	NUMERIC(18,2)	NOT NULL
		, [Table_size_used_in_kb]	NUMERIC(18,2)	NOT NULL
		, [Total_table_object_size_used_in_mb]	NUMERIC(18,2)	NOT NULL
		, [Total_table_object_size_used_in_kb]	NUMERIC(18,2)	NOT NULL
		, [Total_table_object_size_allocated_in_mb]	NUMERIC(18,2)	NOT NULL
		, [Total_table_object_size_allocated_in_kb]	NUMERIC(18,2)	NOT NULL
		,	[row_count]					[bigint]				NOT NULL
		,	[Table_type]				[varchar](30) 	NOT NULL
		, [column_count]			[smallint] 			NOT NULL
		, [last_statistics_date] [datetime]		NULL 
		,	[dml_cnt_since_stats_dt] [bigint]		NULL

		)			


	
				INSERT 
				INTO #group(dbid,database_name,groupid,db_filegroup_name)  
				EXEC sp_MSforeachdb @command1 = " use ? select db_id('?') ,'?',groupid,groupname from sysfilegroups UNION select db_id('?'),'?' ,0,'LOG'"
		select @syserror =@@error,@rowcount = @@ROWCOUNT
      IF (@syserror <>0)
			  BEGIN
    		  SELECT @errno = 300000,@err_param1='error',@err_param2 =' spDBA_Monitor_Daily_DBUsage'
				  GOTO error
			   END
--- GRAB FILE USAGE DATA IN  64 k extents

			EXEC sp_MSforeachdb 
			@command1 =  'use [?] 
					INSERT 
					INTO #db_filestats 
					(	fileid
					,	groupid
					,	totalpages
					,	usedpages
					,	logical_file_name
					,	db_file_name
					) 
					select 	
						fileid
					,	groupid
					,	size
					,	FILEPROPERTY(name,''spaceused'')
					,	name
					,	filename
					from sysfiles'	
			,@command2 = "use [?] update #db_filestats set dbid =db_id('?') where dbid is null "		

		select @syserror =@@error,@rowcount = @@ROWCOUNT
      IF (@syserror <>0)
			  BEGIN
    		  SELECT @errno = 300000,@err_param1='error',@err_param2 =' spDBA_Monitor_Daily_DBUsage'
				  GOTO error
			   END


		select @syserror =@@error,@rowcount = @@ROWCOUNT
      IF (@syserror <>0)
			  BEGIN
    		  SELECT @errno = 300000,@err_param1='error',@err_param2 =' spDBA_Monitor_Daily_DBUsage'
				  GOTO error
			   END
--------------------------------------------- date initialization ------------------------------------
				SELECT @snapshot_date = CURRENT_TIMESTAMP
					,@server_name = @@SERVERNAME
				


/*----------------basic error ---------------------------
error       severity dlevel description  
100100      12       128    Insert failed on %s. Called by %s.                                                                                                                                                                                                                              1033
100120      12       128    Update failed on %s. Called by %s.                                                                                                                                                                                                                              1033
100140      12       128    Delete failed on %s. Called by %s.                                                                                                                                                                                                                              1033
300000      12       0      General Validation error: %s. Called by %s.    

*/ 

	INSERT 
	INTO [xadmindb].[dbadmin].[DBA_FileUsage]
	(	[server_name]
	, [dbid]
	, [database_name]
	, [logical_file_name]
	, [db_file_name]
	, [db_filegroup_name]
	, [server_drive_partition]
	,	[db_file_size_in_mb]
	,	[db_file_used_in_mb]
	, [snapshot_date]
	)


select @server_name

			,fg.dbid
			,fg.database_name
			,fs.logical_file_name
			,fs.db_file_name
			,fg.db_filegroup_name
			,UPPER(substring(fs.db_file_name,1,3))	 
			,cast(fs.totalpages*8.00/1024.00 as numeric(18,2))
			,cast(fs.usedpages*8.00/1024.00  as numeric(18,2))
			,@snapshot_date
from #db_filestats fs
JOIN #group fg
							ON	fg.groupid = fs.groupid
							AND fg.dbid = fs.dbid

		

drop table #db_filestats

drop table #group


			EXEC sp_MSforeachdb 
			@command1 =  'use [?] 
	INSERT 
	INTO #DBA_TableUsage
	(	
	 [dbid]
	, [database_name]
	, [db_filegroup_name]
	, [Table_name]
	, [Table_size_used_in_mb]
	, [Table_size_used_in_kb]
	, [Total_table_object_size_used_in_mb]
	, [Total_table_object_size_used_in_kb]
	, [Total_table_object_size_allocated_in_mb]
	, [Total_table_object_size_allocated_in_kb]
	, [row_count]
	, [Table_type]
	, [column_count]
	, [last_statistics_date]
	, [dml_cnt_since_stats_dt]
	
	)
select 

		db_id(''?'')
		, ''?''
		,filegroup_name(i.groupid)
		,o.name
		,cast ((dpages*8.0)/1024.0 as numeric(18,2))
		,cast ((dpages*8.0) as numeric(18,2))
		,cast ((used*8.0)/1024.0 as numeric(18,2))
		,cast ((used*8.0) as numeric(18,2))
		,cast ((reserved*8.0)/1024.0 as numeric(18,2))
		,cast ((reserved*8.0) as numeric(18,2))
		,rowcnt
		,case WHEN i.indid = 0 THEN ''Heap Table''
					WHEN i.indid = 1 THEN ''Clustered Table''
			END
		,column_count
		,STATS_DATE(i.id,i.indid)
		,rowmodctr

 from sysobjects o WITH (NOLOCK)
join sysindexes i  WITH (NOLOCK) 
on i.id = o.id 
join (select id,count(*) as column_count
					from syscolumns c
					group by id
					) as c

on c.id = o.id 

where indid <=1
and xtype = ''U'''


	INSERT 
	INTO [xadmindb].[dbadmin].[DBA_TableUsage]	
	(	 
		[server_name]
	,	[dbid]
	, [database_name]
	, [db_filegroup_name]
	, [Table_name]
	, [Table_size_used_in_mb]
	, [Table_size_used_in_kb]
	, [Total_table_object_size_used_in_mb]
	, [Total_table_object_size_used_in_kb]
	, [Total_table_object_size_allocated_in_mb]
	, [Total_table_object_size_allocated_in_kb]
	, [row_count]
	, [Table_type]
	, [column_count]
	, [last_statistics_date]
	, [dml_cnt_since_stats_dt]
	, [snapshot_date] 
	)
	SELECT  
		@server_name
	, [dbid]
	, [database_name]
	, [db_filegroup_name]
	, [Table_name]
	, [Table_size_used_in_mb]
	, [Table_size_used_in_kb]
	, [Total_table_object_size_used_in_mb]
	, [Total_table_object_size_used_in_kb]
	, [Total_table_object_size_allocated_in_mb]
	, [Total_table_object_size_allocated_in_kb]
	, [row_count]
	, [Table_type]
	, [column_count]
	, [last_statistics_date]
	, [dml_cnt_since_stats_dt]
	,	@snapshot_date
FROM #DBA_TableUsage


RETURN @syserror
  



error:
	IF @@TRANCOUNT <>0 ROLLBACK TRAN -- ROLLBACK EVERYTHING IF ANYTHING FAILS
  
	RAISerror (@errno,11,1,@err_param1,@err_param2)  -- WILL GIVE THE error BACK TO CLIENT
	RETURN @errno	
  
END



GO

ALTER AUTHORIZATION ON [dbadmin].[uspDBA_Monitor_DBUsage] TO  SCHEMA OWNER 
GO

ALTER AUTHORIZATION ON [dbadmin].[uspDBA_Monitor_DBUsage] TO  SCHEMA OWNER 
GO


