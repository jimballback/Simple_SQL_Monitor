IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbperf].[uspDBA_AZURE_Monitor_Instance_Config]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbperf].[uspDBA_AZURE_Monitor_Instance_Config]  AS' 
END
GO


ALTER PROCEDURE [dbperf].[uspDBA_AZURE_Monitor_Instance_Config] 
 (      

			@snapshot_date datetime = NULL    /* use to pass in if called from a job with other per procs			 */   
		,	@send_alert_ind bit = 0					/*	Future Use:		*/
		,	@debug bit = 1
	
		)

  AS
  
/****************************************************************
 *
 * 
 * NAME: exec [dbperf].[uspDBA_AZURE_Monitor_Instance_Config] @snapshot_date = '2009-10-17'
 *
 * PURPOSE: Logs basic system changes likse cpu and memory.
 *                    This does not track instance or database parameters.
 * DESCRIPTION: Logs any changes to dba_instance along with the snapshot of when it was logged.
 * 
 * 		

 *
 * USAGE: dbperf.uspDBA_AZURE_Monitor_Instance_Config @snapshot_date= '2008-07-26'
 * AUTHOR: James Nafpliotis	LAST MODIFIED BY: $Author:  $
 * CREATED: 2/13/2024 MODIFIED ON: $Modtime: $
 
 *

 *
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
	-- checksum compare
	DECLARE @currchksum int
	DECLARE @nextchksum int

	CREATE TABLE #dba_Instance (
	[instance_id] [int] NOT NULL,
	[snapshot_date] [datetime] NOT NULL,
	[instance_nm] [sysname] COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[server_nm]	[sysname] COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[is_clustered] [int] NOT NULL,
	[is_hadr] [int] NOT NULL,
	[logical_proc_count] [int] NOT NULL,
	[hyperthread_ratio] [int] NOT NULL,
	[socket_count] [int] NOT NULL,
	[physical_memory_gb] [numeric](18, 2) NOT NULL,
	[virtual_memory_gb] [numeric](18, 2) NOT NULL,
	[file_version] [varchar](200) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL, /* replaced with the @@version variable */
	[instance_version] [varchar](20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[engine_edition] [varchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[edition] [varchar](50) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[virtual_machine_type_desc] varchar(60) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[scheduler_count] [int] NOT NULL,
	[max_workers_count] [int] NOT NULL,
	[scheduler_total_count] [int] NOT NULL,
	[committed_target_gb] [int] NOT NULL,
	[bchksum] AS (binary_checksum([instance_nm],[server_nm],[is_clustered],[is_hadr] ,[logical_proc_count],
	[hyperthread_ratio],[socket_count],[physical_memory_gb],[virtual_memory_gb],[file_version],
	[instance_version],[engine_edition],[edition],[scheduler_count],[max_workers_count],
	[scheduler_total_count],[committed_target_gb]))
	)	
	BEGIN
	BEGIN TRY
	-- INSTANCE ID
	select @step ='initialize variables'
		SELECT 
		@instance_id	=	CHECKSUM(COALESCE(serverproperty('ComputerNamePhysicalNetBIOS'),@@servername),COALESCE(serverproperty('instancename'),'MSSQLSERVER')) 
	,	@snapshot_date	=	COALESCE(@snapshot_date,current_timestamp)
	SELECT @STEP = 'load  temp table dba_instance'
	-- CHECK IF THIS data needs to be stored

	INSERT 
	INTO #dba_Instance
		(
		[instance_id]
	,	[snapshot_date]
	,	[instance_nm]
	,	[server_nm]
	,	[is_clustered]
	,	[is_hadr]
	,	[logical_proc_count]
	,	[hyperthread_ratio]
	,	[socket_count]
	,	[physical_memory_gb]
	,	[virtual_memory_gb]
	,	[file_version]
	,	[instance_version]
	,	[engine_edition]
	,	[edition]
	,	[virtual_machine_type_desc]
	,	[scheduler_count]
	,	[max_workers_count]
	,	[scheduler_total_count]
	,	[committed_target_gb]
	)
	SELECT 
		@instance_id AS [instance_id]
	,	@snapshot_date AS [snapshot_date]
	,	cast(COALESCE(SERVERPROPERTY('instancename'),'MSSQLSERVER') as sysname)AS [instance_nm]
	,	cast(COALESCE(SERVERPROPERTY('ComputerNamePhysicalNetBIOS'),@@servername) as sysname) AS [server_nm]
	,	cast(COALESCE(SERVERPROPERTY('IsClustered'),0) as int) AS [is_clustered]
	,	cast(SERVERPROPERTY('IsHadrEnabled') as int) AS [is_hadr]
	,	cast(cpu_count as int) AS [logical_proc_count] 
	,	cast(hyperthread_ratio as int) AS [hyperthread_ratio]
	,	cast(socket_count as int) AS [socket_count]
	,	physical_memory_kb/1024.0/1024.0 AS physical_memory_gb
	,	virtual_memory_kb/1024.0/1024.0 AS virtual_memory_gb
	,	cast(@@version as varchar) AS [file_version]
	,	cast(SERVERPROPERTY('ProductVersion') as varchar) AS [instance_version]
	,	EngineEdition = CASE SERVERPROPERTY('EngineEdition')
						WHEN 1 THEN 'Personal or Desktop Engine'
						WHEN 2 THEN 'Standard' 
						WHEN 3 THEN 'Enterprise' 
						WHEN 4 THEN 'Express' 
						WHEN 5 THEN 'SQL Database'
						WHEN 6 THEN 'Azure Synapse Analytics'
						WHEN 8 THEN 'Azure SQL Managed Instance'
						WHEN 9 THEN 'Azure SQL Edge' 
						WHEN 11 THEN 'Azure Synapse serverless SQL pool'
						END
	,	cast(SERVERPROPERTY('Edition') as varchar) AS [edition]
	,	cast([virtual_machine_type_desc] as varchar)
	,	cast([scheduler_count] as int)
	,	cast([max_workers_count] as int)
	,	cast([scheduler_total_count] as int)
	,	committed_target_kb/1024.0/1024.0 AS [committed_target_gb]	
		FROM sys.dm_os_sys_info
		SELECT @STEP = 'Check for Config Changes'

	SELECT @currchksum =bchksum 
	FROM dbperf.dba_instance
	where snapshot_date = (select max(snapshot_date)
	from dbperf.dba_instance)
	
	SELECT @nextchksum = bchksum
	FROM #dba_instance
-- if no config changes .. exit
	IF @nextchksum =@currchksum return 0
-- insert the data

	INSERT 
	INTO dba_Instance
		(
		[instance_id]
	,	[snapshot_date]
	,	[instance_nm]
	,	[server_nm]
	,	[is_clustered]
	,	[is_hadr]
	,	[logical_proc_count]
	,	[hyperthread_ratio]
	,	[socket_count]
	,	[physical_memory_gb]
	,	[virtual_memory_gb]
	,	[file_version]
	,	[instance_version]
	,	[engine_edition]
	,	[edition]
	,	[virtual_machine_type_desc]
	,	[scheduler_count]
	,	[max_workers_count]
	,	[scheduler_total_count]
	,	[committed_target_gb]
	)
SELECT 	[instance_id]
	,	[snapshot_date]
	,	[instance_nm]
	,	[server_nm]
	,	[is_clustered]
	,	[is_hadr]
	,	[logical_proc_count]
	,	[hyperthread_ratio]
	,	[socket_count]
	,	[physical_memory_gb]
	,	[virtual_memory_gb]
	,	[file_version]
	,	[instance_version]
	,	[engine_edition]
	,	[edition]
	,	[virtual_machine_type_desc]
	,	[scheduler_count]
	,	[max_workers_count]
	,	[scheduler_total_count]
	,	[committed_target_gb]
	FROM #dba_instance
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