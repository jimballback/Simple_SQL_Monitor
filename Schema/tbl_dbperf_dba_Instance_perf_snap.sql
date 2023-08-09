CREATE TABLE [dbperf].[dba_Instance_perf_snap](
	[instance_id] [int] NOT NULL,
	[snapshot_date] [datetime] NOT NULL,
	[inst_perf_param_id] [int] NOT NULL,
	[instance_perf_value] [numeric](18, 2) NOT NULL,
	[cumulative_perf_value] [numeric](18, 2) NOT NULL,
	[startup_measure_ind] [bit] NOT NULL,
	[measurement_interval_s] [int] NOT NULL,
 CONSTRAINT [pk_dba_instance_perf_snap] PRIMARY KEY CLUSTERED 
(
	[snapshot_date] DESC,
	[inst_perf_param_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO