/****************************************************************
 *
 * NAME: [dbperf].[historical_azure_resource_stats]
 *
 * PURPOSE:			Table historical record from sys.dm_db_resource_stats

 * DESCRIPTION:		Simple hsitorical table.
 * INSTALLATION:	
 * USAGE: 
 *		
 *
 *	Latest Version: 5/08/2023 
 *  Created By: James Nafpliotis
 *
 *****************************************************************/
 IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbperf].[historical_azure_resource_stats]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbperf].[historical_azure_resource_stats](
	[end_time] [datetime] NULL,
	[avg_cpu_percent] [decimal](5, 2) NULL,
	[avg_data_io_percent] [decimal](5, 2) NULL,
	[avg_log_write_percent] [decimal](5, 2) NULL,
	[avg_memory_usage_percent] [decimal](5, 2) NULL,
	[xtp_storage_percent] [decimal](5, 2) NULL,
	[max_worker_percent] [decimal](5, 2) NULL,
	[max_session_percent] [decimal](5, 2) NULL,
	[dtu_limit] [int] NULL,
	[avg_login_rate_percent] [decimal](5, 2) NULL,
	[avg_instance_cpu_percent] [decimal](5, 2) NULL,
	[avg_instance_memory_percent] [decimal](5, 2) NULL,
	[cpu_limit] [decimal](5, 2) NULL,
	[replica_role] [int] NULL
) ON [PRIMARY]
END
GO
CREATE CLUSTERED INDEX CIDX_historical_azure_resource_stats_1  ON [dbperf].[historical_azure_resource_stats](end_time);
GO