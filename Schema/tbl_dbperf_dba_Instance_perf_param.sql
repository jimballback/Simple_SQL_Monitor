



/****************************************************************
 *
 * NAME: [dbperf].[dba_Instance_perf_param]
 *
 * PURPOSE:			Lookup table for performance counters that need to be recorded.
 * DESCRIPTION:		A log indicator flag determines the counters that are actually recorded in the snapshot table. Update the log_ind flag column.
 * INSTALLATION:	
 * USAGE: 
 *		
 *
 *	Created Version: 4/14/2023 
 * Latest version 2/19/2024
 *  Created By: James Nafpliotis
 *
 *****************************************************************/
CREATE TABLE [dbperf].[dba_Instance_perf_param](
	[Inst_perf_param_id] [int] NOT NULL,
	[object_nm] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[counter_nm] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[instance_nm] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[counter_type] [int] ,
	[parent_param_id] [int] NULL,
	[Log_ind] [bit] NOT NULL


 CONSTRAINT [pk_dba_instance_perf_param] PRIMARY KEY CLUSTERED 
(
	[Inst_perf_param_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbperf].[dba_Instance_perf_param] ADD  DEFAULT ((0)) FOR [Log_ind]
GO
--missing index 
CREATE NONCLUSTERED INDEX idx_cover_dba_Instance_perf_param_log_ind
ON [dbperf].[dba_Instance_perf_param] ([Log_ind])
INCLUDE ([object_nm],[counter_nm],[instance_nm],[counter_type],[parent_param_id])
GO
