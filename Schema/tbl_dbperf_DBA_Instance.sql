/****************************************************************
 *
 * NAME: [dbperf].[dba_Instance]
 *
 * PURPOSE:			Table that holds general information for an IAAS or on-prem instance.
 * DESCRIPTION:		Records historical general instance information. For azure , this will be stub for now. Can be used to compare performance after scaleup or scaledown.
 * INSTALLATION:	
 * USAGE: 
 *		
 *
 *	Latest Version: 4/14/2023 
 *  Created By: James Nafpliotis
 *
 *****************************************************************/

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbperf].[DBA_Instance]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbperf].[dba_Instance](
	[instance_id] [int] NOT NULL,
	[snapshot_date] [datetime] NOT NULL,
	[instance_nm] [sysname] NOT NULL,
	[logical_proc_count] [int] NOT NULL,
	[hyperthread_ratio] [int] NOT NULL,
	[socket_count]  AS (CONVERT([numeric](4,1),[logical_proc_count]/[hyperthread_ratio])),
	[physical_memory_gb] [numeric](18, 2) NOT NULL,
	[virtual_memory_gb] [numeric](18, 2) NOT NULL,
	[file_version] [varchar](100) NOT NULL,
	[instance_version] [varchar](20) NOT NULL,
	[os_version] [varchar](20) NOT NULL,
	[scheduler_count] [int] NOT NULL,
	[max_workers_count] [int] NOT NULL,
	[bchksum]  AS (binary_checksum([instance_nm],[logical_proc_count],[hyperthread_ratio],[physical_memory_gb],[virtual_memory_gb],[file_version],[instance_version],[os_version],[scheduler_count],[max_workers_count]))
) ON [PRIMARY]
END
GO




