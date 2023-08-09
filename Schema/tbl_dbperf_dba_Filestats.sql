/****************************************************************
 *
 * NAME: [dbperf].[dba_Filestats]
 *
 * PURPOSE:			Table that logs IO data for data files.
 * DESCRIPTION:		Data from sys.dm_io_virtual_file_stats.
 * INSTALLATION:	
 * USAGE: 
 *		
 *
 *	Latest Version: 5/14/2023 
 *  Created By: James Nafpliotis
 *
 *****************************************************************/

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbperf].[dba_Filestats]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbperf].[dba_Filestats](
	[instance_id] [int] NULL,
	[snapshot_date] [datetime] NULL,
	[database_name] [sysname] NOT NULL,
	[logical_filename] [sysname] NULL,
	[db_file_name] [varchar](8000) NULL,
	[db_file_type] [varchar](50) NULL,
	[num_of_reads] [bigint] NULL,
	[num_of_writes] [bigint] NULL,
	[num_of_bytes_read] [bigint] NULL,
	[num_of_bytes_written] [bigint] NULL,
	[io_stall_ms] [bigint] NULL,
	[io_stall_reads_ms] [bigint] NULL,
	[io_stall_writes_ms] [bigint] NULL,
	[size_on_disk_GB] [numeric](9, 4) NULL,
	[pdw_node_id] [int] NULL,
	[interval_in_seconds] [int] NULL,
	[cumulative_num_of_reads] [bigint] NULL,
	[cumulative_num_of_writes] [bigint] NULL,
	[cumulative_num_of_bytes_read] [bigint] NULL,
	[cumulative_num_of_bytes_written] [bigint] NULL,
	[cumulative_io_stall_ms] [bigint] NULL,
	[cumulative_io_stall_reads_ms] [bigint] NULL,
	[cumulative_io_stall_writes_ms] [bigint] NULL,
	[first_measure_from_start] [bit] NOT NULL
) ON [PRIMARY]
END
GO
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbperf].[dba_Filestats]') AND type in (N'U'))
BEGIN
ALTER TABLE [dbperf].[dba_Filestats] ADD CONSTRAINT [DF_dba_Filestats_pdw_node_id] DEFAULT  ((0)) FOR [pdw_node_id]
END
GO