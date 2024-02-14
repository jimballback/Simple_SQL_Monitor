USE [XAdminDB]
GO

/****** Object:  StoredProcedure [dbadmin].[uspDBA_Monitor_Instance_Config]    Script Date: 2/13/2024 2:48:13 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER OFF
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbadmin].[uspDBA_Monitor_Instance_Config]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbadmin].[uspDBA_Monitor_Instance_Config] AS' 
END
GO


ALTER PROCEDURE [dbadmin].[uspDBA_Monitor_Instance_Config] 
 (      
	@snapshot_date DATETIME  = null
	
	,	@alert_config_change BIT = 0  /* STUB:alert DBA's when configuration has changed */
	,	@debug bit = 0		/* STUB: */
  )
AS


/****************************************************************
 *
 * 
 * NAME: exec dbadmin.uspDBA_Monitor_Instance_Config @snapshot_date = '2009-10-17'
 *
 * PURPOSE: Part of a SQL2005 Isntance or higher Monitoring Solution to log some changes in the  OS system configuratiion that can be tracked by the instance
		such as number of cpu's and memory.
 *                    This does not track instance or database parameters
 * DESCRIPTION: Logs any changes to dba_instance along with the snapshot of when it was logged.
 * 
 * 		
  default instnace
  An instance is either the default instance or a named instance. The default instance name is MSSQLSERVER. 
  instance id will now be based on server name and instance name 
 * https://learn.microsoft.com/en-us/sql/sql-server/install/instance-configuration?view=sql-server-ver16
 Changed 

 *
 * USAGE: dbadmin.uspDBA_Monitor_Instance_Config @snapshot_date= '2008-07-26'
 * AUTHOR: James Nafpliotis	LAST MODIFIED BY: $Author:  $
 * CREATED: 07/25/2008 MODIFIED ON: $Modtime: $
 * Modified:  dnaf 12/27/2010 added better debugging
 *
 * CURRENT REVISION: $Revision:  $
 * HISTORY (Most recent first): $History:  $
 * 
 * Updated in $
 *
 * 
 *****************************************************************/
	BEGIN
	SET NOCOUNT ON
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED  --  Do Not need to use any lock resources

	
	DECLARE	@step varchar(80)   /* the user defined step of the procedure for debugging and error handling */
		
/*--------------------------------------- Standard variable Declaration----------------------------------------------------*/
		DECLARE @Error_msg varchar(200)
		DECLARE @error_num int
 		DECLARE @err_param1 varchar(50)      /* the first error paramaeter passed that interpolates based on the sysmessages entry */
 		DECLARE @err_param2 varchar(50)      /* the second error paramaeter passed that interpolates based on the sysmessages entry */
 		DECLARE @syserror varchar(6)             /*  a system error code checked via  system error function @@error to determine is an error occured  */
           

/*------------------------------------------Custom Variable Declaration -------------------------------------------------*/

		DECLARE @instance_nm sysname
		DECLARE @instance_id int
		DECLARE @currchksum int
		DECLARE @nextchksum int

		DECLARE @dba_instance 
		TABLE ( 
						[instance_id] [int]  NULL,
						[snapshot_date] [datetime] NULL,
						[instance_nm] [sysname] NULL,
						[logical_proc_count] [int]  NULL,
						[hyperthread_ratio]  [int]  NULL,
						[physical_memory_gb] [numeric](18, 2)  NULL,
						[virtual_memory_gb] [numeric](18, 2) NULL,
						[file_version] [varchar](100) NULL,
						[instance_version] [varchar](20) NULL,
						[os_version] [varchar](20)  NULL,
						[scheduler_count] [int]  NULL,
						[max_workers_count] [int]  NULL	
						,bchksum  AS BINARY_CHECKSUM(instance_nm,logical_proc_count,hyperthread_ratio
												,physical_memory_gb,virtual_memory_gb,file_version
												,instance_version,os_version,scheduler_count,max_workers_count
												)
					)

		SELECT @instance_nm =  coalesce(@@servername,'unknown')
				,@snapshot_date = COALESCE(@snapshot_date,current_timestamp)
--- tempory table t hold result of extended proc that has version info without the need to parse
--- not sure if this will be deprecated or not
		CREATE
		TABLE #server
					(	id tinyint
					,	srv_attrib varchar(100)
					,	srv_int_val int
					,	srv_char_val varchar(1000)
					)
					
					
		BEGIN TRY
		
		SELECT @STEP = 'load #server Variable'

  		INSERT
		INTO #server
		EXEC master..xp_msver

	--	BEGIN TRY
			SELECT @STEP = 'load @dba_instance Variable'
			INSERT
			INTO	@dba_instance
			SELECT	null as instance_id
						,	@snapshot_date
						,	@instance_nm
						,	cpu_count
						,	hyperthread_ratio
						,	physical_memory_kb/1024.0/1024.0 as physical_memory_gb
						,	virtual_memory_kb/1024.0/1024.0 as virtual_memory_gb
						,	NULL AS file_version
						,	NULL AS instance_version
						,	NULL AS os_version
						,	scheduler_count
						,	max_workers_count
			FROM  sys.dm_os_sys_info
			-- select * from sys.dm_os_sys_info

		SELECT @STEP = 'update @dba_instance Variable'
        UPDATE @dba_instance SET file_version = srv_char_val  
        FROM #server
        WHERE srv_attrib = 'FileVersion'
         UPDATE @dba_instance SET instance_version = srv_char_val  
        FROM #server
        WHERE srv_attrib = 'ProductVersion' 
        UPDATE @dba_instance SET os_version = srv_char_val  
        FROM #server
        WHERE srv_attrib = 'WindowsVersion'
        DROP TABLE #server


-- CHECK IF THIS data needs to be stored
		SELECT @STEP = 'Check for Config Changes'

	SELECT @currchksum =max(bchksum) 
	FROM xadmindb.dbadmin.dba_instance
	where snapshot_date = (select max(snapshot_date)
	from xadmindb.dbadmin.dba_instance)
	
	SELECT @nextchksum = max(bchksum)
	FROM @dba_instance

	IF @nextchksum =@currchksum  return 0
	IF (SELECT COUNT(*) FROM [xadmindb].[dbadmin].[DBA_Instance])  = 0
		BEGIN
			SELECT @instance_id = checksum(@instance_nm)
		END
		ELSE 
			begin
				select @instance_id = max(instance_id)
				from xadmindb.dbadmin.dba_instance
			end

UPDATE @dba_instance SET instance_id = @instance_id  
		SELECT @STEP = 'Load [dbadmin].[DBA_Instance] '
INSERT INTO [xadmindb].[dbadmin].[DBA_Instance]
           ([instance_id]
           ,[snapshot_date]
           ,[instance_nm]
           ,[logical_proc_count]
           ,[hyperthread_ratio]
           ,[physical_memory_gb]
           ,[virtual_memory_gb]
           ,[file_version]
           ,[instance_version]
           ,[os_version]
           ,[scheduler_count]
           ,[max_workers_count])

	SELECT 		
			[instance_id]
           ,[snapshot_date]
           ,[instance_nm]
           ,[logical_proc_count]
           ,[hyperthread_ratio]
           ,[physical_memory_gb]
           ,[virtual_memory_gb]
           ,[file_version]
           ,[instance_version]
           ,[os_version]
           ,[scheduler_count]
           ,[max_workers_count]
	FROM @dba_instance
END TRY
BEGIN CATCH
    DECLARE @ErrorMessage NVARCHAR(4000);
    DECLARE @ErrorSeverity INT;
    DECLARE @ErrorState INT;

    SELECT 
        @ErrorMessage = ERROR_MESSAGE()+CHAR(13)+'Procedure Step: '+ coalesce(@step,'UNKNOWN'),
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
END



GO

ALTER AUTHORIZATION ON [dbadmin].[uspDBA_Monitor_Instance_Config] TO  SCHEMA OWNER 
GO

ALTER AUTHORIZATION ON [dbadmin].[uspDBA_Monitor_Instance_Config] TO  SCHEMA OWNER 
GO


