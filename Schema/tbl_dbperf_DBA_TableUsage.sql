

/****************************************************************
 *
 * NAME: [dbperf].[DBA_TableUsage]
 *
 * PURPOSE:			Record storage growth.
 * DESCRIPTION:		
 * INSTALLATION:	
 * USAGE: 
 *		
 *
 *	Latest Version: 8/4/2023 
 *  Created By: James Nafpliotis
 *
 *****************************************************************/

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbperf].[DBA_TableUsage]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbperf].[DBA_TableUsage](
	[instance_id] [int] NOT NULL,
	[snapshot_date] [datetime] NOT NULL,
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
	) ON [PRIMARY]
END
GO



