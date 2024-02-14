/****************************************************************
 *
 * NAME: [dbperf].[dba_Instance]
 *
 * PURPOSE:			Table that holds general information for an IAAS or on-prem instance.
 * DESCRIPTION:		Records historical general instance information. For azure , this will be stub for now. Can be used to compare performance after scaleup or scaledown.
 * INSTALLATION:	
 * USAGE: 
 *		
 * removal of  os version column  to  be compatible with PAAS  and not to use xp_msver
	fileversion replaced with @@version
	removed OS version .  can be extracted with  via file_version in @@version
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
	[virtual_machine_type_desc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[scheduler_count] [int] NOT NULL,
	[max_workers_count] [int] NOT NULL,
	[scheduler_total_count] [int] NOT NULL,
	[committed_target_gb] [int] NOT NULL,
	[bchksum] AS (binary_checksum([instance_nm],[server_nm],[is_clustered],[is_hadr] ,[logical_proc_count],
	[hyperthread_ratio],[socket_count],[physical_memory_gb],[virtual_memory_gb],[file_version],
	[instance_version],[engine_edition],[edition],[scheduler_count],[max_workers_count],
	[scheduler_total_count],[committed_target_gb]))
) ON [PRIMARY]
END
GO




