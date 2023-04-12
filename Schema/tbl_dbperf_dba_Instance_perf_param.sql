CREATE TABLE [dbperf].[dba_Instance_perf_param](
	[Inst_perf_param_id] [int] NOT NULL,
	[object_nm] [varchar](128) NOT NULL,
	[counter_nm] [varchar](128) NOT NULL,
	[instance_nm] [varchar](128) NOT NULL,
	[counter_type] [int] NOT NULL,
	[parent_param_id] [int] NULL,
	[Log_ind] [bit] NOT NULL,


 CONSTRAINT [pk_dba_instance_perf_param] PRIMARY KEY CLUSTERED 
(
	[Inst_perf_param_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbperf].[dba_Instance_perf_param] ADD  DEFAULT ((0)) FOR [Log_ind]
GO