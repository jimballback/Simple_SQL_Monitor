SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER OFF
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbperf].[vw_wait_category_summary]') AND type in (N'V'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE VIEW [dbperf].[vw_wait_category_summary] AS Select 1 as A' 

END
GO


ALTER VIEW [dbperf].[vw_wait_category_summary]
AS

/****************************************************************
 *
 * NAME: [dbperf].[vw_wait_category_summary]

 *
 * PURPOSE: Query instance level wait snapshot and  assignes a category.
 *
 * DESCRIPTION: FIlters out wait time averages less than 1 ms
 *
 * AUTHOR:  
 * CREATED:  
 *
 * *****************************************************************/


SELECT
		[instance_id]
	,	[snapshot_date]
	,	[wait_type]
	,	[wait_requests]
	,	[wait_time]
	,	[signal_wait_time]
	,	[wait_time_request_average]
	,	[signal_wait_time_request_average]
	,	CASE 
			WHEN wait_type ='ASYNC_NETWORK_IO'
			THEN 'Network IO'
			WHEN wait_type like '%HADR%'
			THEN 'Always ON'
			WHEN wait_type like 'PAGEIO%'
			THEN 'Buffer IO'
			WHEN wait_type like 'PAGELATCH%'
			THEN 'Memory Buffer'
			WHEN wait_type in 
				(	'HADR_AG_MUTEX'
				,	'HADR_AR_CRITICAL_SECTION_ENTRY'
				)
			THEN 'Cluster'
			WHEN wait_type ='WAIT_ON_SYNC_STATISTICS_REFRESH'
			THEN 'Compile'
			WHEN wait_type ='CONNECTION_MGR'
			THEN 'Connection'
			WHEN wait_type IN
				(	'SOS_WORKER_MIGRATION'
				,	'THREADPOOL'
				,	'SOS_SCHEDULER_YIELD'
				)
			THEN 'CPU'
			WHEN wait_type IN
				('HTBUILD'
				,'HTDELETE'
				,'HTMEMO'
				,'HTREPARTITION'
				)
			THEN 'Hash Join'
			WHEN wait_type  like 'LATCH%'
			THEN 'Latch'
			WHEN wait_type  like 'LCK%'
			THEN 'Lock'
			WHEN wait_type IN
				(	'SLEEP_BPOOL_STEAL'
				,	'SLEEP_BUFFERPOOL_HELPLW'
				,	'SLEEP_MEMORYPOOL_ALLOCATEPAGES'
				,	'SOS_MEMORY_TOPLEVELBLOCKALLOCATOR'
				)
			THEN 'Memory'
			WHEN wait_type in 
				(	'IO_COMPLETION'
				,	'ASYNC_IO_COMPLETION'
				,	'WRITE_COMPLETION'
				)
			THEN 'Other Disk IO'
			WHEN wait_type ='CXCONSUMER' 
			THEN 'Parallelism'
			WHEN wait_type ='CXPACKET'
			THEN 'Producer Parallelism'
			WHEN wait_type IN
			(	'LOGBUFFER'
			,	'WRITELOG')
			THEN 'Tran Log IO'
			WHEN wait_type like '%PREEMPTIVE%' 
			THEN 'Preemptive'
			WHEN wait_type IN ('BACKUPTHREAD')
			THEN 'Backup'
			ELSE 'Other'end as Wait_Category
FROM [dbperf].[DBA_wait_summary]
WHERE wait_time_request_average >1
	AND wait_type not in 
		(	select wait_type
			from [dbperf].[vw_innocuous_wait_types]
		)
	AND [first_measure_from_start] =0
	AND wait_type <> 'HADR_BACKUP_QUEUE'
UNION
SELECT
		[instance_id]
	,	[snapshot_date]
	,	[wait_type]
	,	[wait_requests]
	,	[wait_time]
	,	[signal_wait_time]
	,	[wait_time_request_average]
	,	[signal_wait_time_request_average]
	,	CASE 
			WHEN wait_type ='ASYNC_NETWORK_IO'
			THEN 'Network IO'
			WHEN wait_type like '%HADR%'
			THEN 'Always ON'
			WHEN wait_type like 'PAGEIO%'
			THEN 'Buffer IO'
			WHEN wait_type like 'PAGELATCH%'
			THEN 'Memory Buffer'
			WHEN wait_type in 
				(	'HADR_AG_MUTEX'
				,	'HADR_AR_CRITICAL_SECTION_ENTRY'
				)
			THEN 'Cluster'
			WHEN wait_type ='WAIT_ON_SYNC_STATISTICS_REFRESH'
			THEN 'Compile'
			WHEN wait_type ='CONNECTION_MGR'
			THEN 'Connection'
			WHEN wait_type IN
				(	'SOS_WORKER_MIGRATION'
				,	'THREADPOOL'
				,	'SOS_SCHEDULER_YIELD'
				)
			THEN 'CPU'
			WHEN wait_type IN
				('HTBUILD'
				,'HTDELETE'
				,'HTMEMO'
				,'HTREPARTITION'
				)
			THEN 'Hash Join'
			WHEN wait_type  like 'LATCH%'
			THEN 'Latch'
			WHEN wait_type  like 'LCK%'
			THEN 'Lock'
			WHEN wait_type IN
				(	'SLEEP_BPOOL_STEAL'
				,	'SLEEP_BUFFERPOOL_HELPLW'
				,	'SLEEP_MEMORYPOOL_ALLOCATEPAGES'
				,	'SOS_MEMORY_TOPLEVELBLOCKALLOCATOR'
				)
			THEN 'Memory'
			WHEN wait_type in 
				(	'IO_COMPLETION'
				,	'ASYNC_IO_COMPLETION'
				,	'WRITE_COMPLETION'
				)
			THEN 'Other Disk IO'
			WHEN wait_type ='CXCONSUMER' 
			THEN 'Parallelism'
			WHEN wait_type ='CXPACKET'
			THEN 'Producer Parallelism'
			WHEN wait_type IN
			(	'LOGBUFFER'
			,	'WRITELOG')
			THEN 'Tran Log IO'
			WHEN wait_type like '%PREEMPTIVE%' 
			THEN 'Preemptive'
			WHEN wait_type IN ('BACKUPTHREAD')
			THEN 'Backup'
			ELSE 'Other'end as Wait_Category
FROM [dbperf].[Historical_DBA_wait_summary]
WHERE wait_time_request_average >1
	AND wait_type not in (select wait_type
						from [dbperf].[vw_innocuous_wait_types]
					)
	AND wait_type <> 'HADR_BACKUP_QUEUE'
	AND wait_type not in (select wait_type
						from [dbperf].[vw_innocuous_wait_types]
						)
	AND [first_measure_from_start] =0

