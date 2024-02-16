USE [XAdminDB]
GO

/****** Object:  StoredProcedure [dbadmin].[uspDBA_Monitor_Wrapper]    Script Date: 2/15/2024 1:06:54 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbadmin].[uspDBA_Monitor_Wrapper]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbadmin].[uspDBA_Monitor_Wrapper] AS' 
END
GO

-- drop procedure [dbadmin].[uspDBA_Monitor_Wrapper]
ALTER procedure [dbadmin].[uspDBA_Monitor_Wrapper]
	(
		@log_data_ind			bit = 0     /* Log the data or  just return the stats from the last time it was logged */ 
	,	@log_perf_stats			bit = 0     /* Log sql server performance counters */
	,	@log_wait_stats			bit = 0     /* Log sql server Wait statistics */
	,	@log_io_stats			bit = 0     /* Log sql server io details */
	,	@log_query_stats		bit = 0	    /* STUB:Log sql server performance counters */	
    ,   @log_current_SQL_cache  bit = 0     /* STUB: WARNING: resource intensive Logs a snapshot in time of staements in the cache*/	
    ,   @log_buffers_cache      bit = 0     /* STUB: WARNING: resource intensive Logs which objects pages are in the buffer */		
	,	@alert_config_change	bit = 0     /* future use */
	,	@send_alert_ind			bit = 0      /* Future use*/
	

) 
as
/****************************************************************
 *
 * 
 * NAME: dbadmin.uspDBA_Monitor_Wrapper 
 *
 * PURPOSE: The main procedure called by a sql server agent job or other mechanims such as osql 
  * for the purpose of monitoring and alerting performace attributes.
 * DESCRIPTION:   
								

 * 
 * 		

 *
 * USAGE: dbadmin.uspDBA_Monitor_Wrapper 
  		@log_data_ind			 = 1    /* Log the data or  just return the stats from the last time it was logged */ 
	,	@log_perf_stats			 = 1     /* Log sql server performance counters */
	,	@log_wait_stats			 = 1     /* Log sql server Wait statistics */
	,	@log_io_stats			 = 1     /* Log sql server io details */ 
 * AUTHOR: James Nafpliotis	LAST MODIFIED BY: $Author:  $
 * CREATED: 08/31/2007 MODIFIED ON: $Modtime: $
 * MODIFIED:
 *			12/27/2010 Dnaf  
 *
 * CURRENT REVISION: $Revision:  $
 * HISTORY (Most recent first): $History:  $
 * 
 * Updated in $
 *
 * 
 *****************************************************************/

begin
DECLARE @snapshot_date datetime
DECLARE @RC int
DECLARE @step varchar(100)
DECLARE @procedure  sysname


select @snapshot_date  = convert(datetime,cast(getdate() as nvarchar(30)),120)
BEGIN TRY

--config stub
IF  EXISTS (SELECT * 
						FROM sys.objects 
						WHERE object_id = OBJECT_ID(N'[xadmindb].[dbadmin].[uspDBA_Monitor_Instance_Config]')
						 AND type in (N'P', N'PC')
						)
	BEGIN
		select @procedure = '[xadmindb].[dbadmin].[uspDBA_Monitor_Instance_Config]'
		EXECUTE @RC = [xadmindb].[dbadmin].[uspDBA_Monitor_Instance_Config] 
					@snapshot_date
				,	@alert_config_change
	END
-- perf stub
IF  EXISTS (SELECT * 
						FROM sys.objects 
						WHERE object_id = OBJECT_ID(N'[dbperf].[uspDBA_Monitor_Performance]')
						 AND type in (N'P', N'PC')
						)
    AND (@log_perf_stats = 1)
	BEGIN
-- TODO: Set parameter values here.
		select @procedure = '[xadmindb].[dbperf].[uspDBA_Monitor_Performance]'
		EXECUTE @RC = [xadmindb].[dbperf].[uspDBA_Monitor_Performance] 
				@log_data_ind
			,	@snapshot_date
			,	@send_alert_ind
			
	END	
IF  EXISTS (SELECT * 
						FROM sys.objects 
						WHERE object_id = OBJECT_ID(N'[dbperf].[uspDBA_Monitor_Wait_Statistics]')
						 AND type in (N'P', N'PC')
						)
    AND (@log_wait_stats = 1)
	BEGIN
-- TODO: Set parameter values here.
		select @procedure = '[xadmindb].[dbperf].[uspDBA_Monitor_Wait_Statistics]'
		EXECUTE @RC = [xadmindb].[dbperf].[uspDBA_Monitor_Wait_Statistics] 
				@log_data_ind
			,	@snapshot_date
			,	@send_alert_ind
			
	END	
IF  EXISTS (SELECT * 
						FROM sys.objects 
						WHERE object_id = OBJECT_ID(N'[dbperf].[uspDBA_Monitor_IO_Detail]')
						 AND type in (N'P', N'PC')
						)
    AND (@log_io_stats = 1)
		BEGIN
-- TODO: Set parameter values here.
		select @procedure = '[xadmindb].[dbperf].[uspDBA_Monitor_IO_Detail]'
		EXECUTE @RC = [xadmindb].[dbperf].[uspDBA_Monitor_IO_Detail] 
				@log_data_ind
			,	@snapshot_date
			,	@send_alert_ind
			
	END	
IF  EXISTS (SELECT * 
						FROM sys.objects 
						WHERE object_id = OBJECT_ID(N'[dbperf].[uspDBA_Monitor_Query_Stats]')
						 AND type in (N'P', N'PC')
						)
    AND (@log_query_stats = 1)
    BEGIN
    	select @procedure = '[xadmindb].[dbperf].[uspDBA_Monitor_Query_Stats]'
		EXECUTE @RC = [xadmindb].[dbperf].[uspDBA_Monitor_Query_Stats] 
				@log_data_ind
			,	@snapshot_date
			,	@send_alert_ind

    END
END TRY			
BEGIN CATCH
    DECLARE @ErrorMessage NVARCHAR(4000);
    DECLARE @ErrorSeverity INT;
    DECLARE @ErrorState INT;
	if @@trancount<> 0 ROLLBACK TRAN

    SELECT 
        @ErrorMessage = ERROR_MESSAGE()+CHAR(13)+'Called Procedure: '+coalesce(@procedure,'UNKNOWN')+char(13)+'Procedure Step: '+ coalesce(@step,'UNKNOWN'),
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





end



GO

ALTER AUTHORIZATION ON [dbadmin].[uspDBA_Monitor_Wrapper] TO  SCHEMA OWNER 
GO

ALTER AUTHORIZATION ON [dbadmin].[uspDBA_Monitor_Wrapper] TO  SCHEMA OWNER 
GO


