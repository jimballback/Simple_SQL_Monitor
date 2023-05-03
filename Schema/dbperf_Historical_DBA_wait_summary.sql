SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbperf].[Historical_DBA_wait_summary]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbperf].[Historical_DBA_wait_summary](
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
	[date_added] [datetime] NOT NULL,
	[archived_by_user] [varchar](100) NOT NULL
 CONSTRAINT [pk_historical_dba_wait_summary] PRIMARY KEY CLUSTERED 
(
	[snapshot_date] DESC,
	[wait_type] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
GO
ALTER AUTHORIZATION ON [dbperf].[Historical_DBA_wait_summary] TO  SCHEMA OWNER 
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbperf].[df_historical_dba_wait_summary_date_added]') AND type = 'D')
BEGIN
ALTER TABLE [dbperf].[Historical_DBA_wait_summary] ADD  CONSTRAINT [df_historical_dba_wait_summary_date_added]  DEFAULT (getdate()) FOR [date_added]
END
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbperf].[df_historical_dba_wait_summary_archived_by_user]') AND type = 'D')
BEGIN
ALTER TABLE [dbperf].[Historical_DBA_wait_summary] ADD  CONSTRAINT [df_historical_dba_wait_summary_archived_by_user]  DEFAULT (SYSTEM_USER) FOR [archived_by_user]
END
GO