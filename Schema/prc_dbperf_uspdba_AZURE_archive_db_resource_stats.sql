IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbperf].[uspdba_AZURE_archive_db_resource_stats]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbperf].[uspdba_AZURE_archive_db_resource_stats] AS' 
END
GO
ALTER PROCEDURE [dbperf].[uspdba_AZURE_archive_db_resource_stats]

AS
/*****************************************************************************************
 *
 * NAME: [dbperf].[uspdba_AZURE_archive_db_resource_stats]
 *
 * PURPOSE:			Archive sys.dm_db_resource_stats 
 * DESCRIPTION:		
 * INSTALLATION:	Install on a seperated schema in Azure SQL database.
 * DEPENDENCIES:	[dbperf].[historical_azure_resource_stats]
 *					
 * USAGE: 
		[dbperf].[uspdba_AZURE_archive_db_resource_stats]
 *
 *
 *
 *	Latest Version: 5/3/2023 
 *  Created By: James Nafpliotis
 *
 *****************************************************************************************/

	BEGIN
		SET NOCOUNT ON
		SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
		DECLARE	@step varchar(80)					/* The user defined step of the procedure for debugging and error handling */
	BEGIN TRY
	INSERT 
	INTO [dbperf].[historical_azure_resource_stats]
           ([end_time]
           ,[avg_cpu_percent]
           ,[avg_data_io_percent]
           ,[avg_log_write_percent]
           ,[avg_memory_usage_percent]
           ,[xtp_storage_percent]
           ,[max_worker_percent]
           ,[max_session_percent]
           ,[dtu_limit]
           ,[avg_login_rate_percent]
           ,[avg_instance_cpu_percent]
           ,[avg_instance_memory_percent]
           ,[cpu_limit]
           ,[replica_role])


		SELECT [end_time]
           ,[avg_cpu_percent]
           ,[avg_data_io_percent]
           ,[avg_log_write_percent]
           ,[avg_memory_usage_percent]
           ,[xtp_storage_percent]
           ,[max_worker_percent]
           ,[max_session_percent]
           ,[dtu_limit]
           ,[avg_login_rate_percent]
           ,[avg_instance_cpu_percent]
           ,[avg_instance_memory_percent]
           ,[cpu_limit]
           ,[replica_role]
		   FROM sys.dm_db_resource_stats 
		   WHERE end_time NOT IN ( 
								SELECT [end_time] 
								FROM [dbperf].[historical_azure_resource_stats]
								)

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
	END;