SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO
/****************************************************************
 *
 * NAME: [dbperf].[dba_wait_summary]
 *
 * PURPOSE:			Table that holds recorded wait information.
 * DESCRIPTION:		Table is denormlized. The future version may be normalized like the performance counter table.
 * INSTALLATION:	
 * USAGE: 
 *		
 *
 *	Latest Version: 4/14/2023 
 *  Created By: James Nafpliotis
 *
 *****************************************************************/
CREATE TABLE [dbperf].[DBA_wait_summary](
	[instance_id] [int] NOT NULL,
	[snapshot_date] [datetime] NOT NULL,
	[wait_type] [varchar](100) NOT NULL,
	[wait_requests] [numeric](18, 2) NOT NULL,
	[wait_time] [numeric](18, 2) NOT NULL,
	[signal_wait_time] [numeric](18, 2) NOT NULL,
	[wait_time_request_average]  AS (case when [wait_requests]=(0) then (0) else CONVERT([numeric](18,2),[wait_time]/[wait_requests]) end),
	[signal_wait_time_request_average]  AS (case when [wait_requests]=(0) then (0) else CONVERT([numeric](18,2),[signal_wait_time]/[wait_requests]) end),
	[max_wait_time_since_start] [int] NULL,
	[cumulative_wait_requests] [numeric](18, 2) NOT NULL,
	[cumulative_wait_time] [numeric](18, 2) NOT NULL,
	[cumulative_signal_wait_time] [numeric](18, 2) NOT NULL,
	[cumulative_wait_time_request_average]  AS (case when [cumulative_wait_requests]=(0) then (0) else CONVERT([numeric](18,2),[cumulative_wait_time]/[cumulative_wait_requests]) end),
	[interval_in_seconds] [numeric](18, 2) NOT NULL,
	[first_measure_from_start] [bit] NOT NULL,
 CONSTRAINT [pk_dba_wait_summary] PRIMARY KEY CLUSTERED 
(
	[snapshot_date] DESC,
	[wait_type] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO


