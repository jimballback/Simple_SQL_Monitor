/****************************************************************
 *
 * NAME: [dbperf].[DBA_FileUsage]
 *
 * PURPOSE:			Table that holds general information of the database file allocation and size.
 * DESCRIPTION:		
 * INSTALLATION:	
 * USAGE: 
 *		
 *
 *	Latest Version: 6/20/2023 
 *  Created By: James Nafpliotis
 *
 *****************************************************************/

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbperf].[DBA_FileUsage]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbperf].[DBA_FileUsage](
	[instance_id] [int] NOT NULL,
	[snapshot_date] [datetime] NOT NULL,
	[database_name] [sysname] NOT NULL,
	[logical_file_name] [sysname] NOT NULL,
	[db_file_type] [nvarchar](60) NULL,
	[db_file_name] [nvarchar](256) NULL,
	[db_file_state] [nvarchar](60) NULL,
	[db_filegroup_name] [sysname] NOT NULL,
	[db_file_size_in_mb] [numeric](18, 2) NULL,
	[db_file_used_in_mb] [numeric](18, 2) NULL
) ON [PRIMARY]
END
GO

