IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbperf].[uspdba_AZURE_report_performance]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbperf].[uspdba_AZURE_report_performance] AS' 
END
GO
ALTER PROCEDURE [dbperf].[uspdba_AZURE_report_performance]
(		@startdate datetime =null
    ,	@enddate datetime = null
)
AS
/*****************************************************************************************
 *
 * NAME: [dbperf].[uspdba_AZURE_report_performance]
 *
 * PURPOSE:			Pivots select performance counters as a report.
 * DESCRIPTION:		The defauls is the alst 30 minutes.
 * INSTALLATION:	Install on a seperated schema in Azure SQL database.
 * DEPENDENCIES:	[dbperf].[vw_summary_ratio],[dbperf].[vw_memory_snapshot],[dbperf].[vw_database_Throughput]
 *					[dbperf].[vw_waittime_Snapshot],dbperf.dba_wait_summary
 * USAGE: 
 *		
 *	Last 30 minutes:
 		exec [dbperf].[uspdba_AZURE_report_performance]
 *
 *
 *
 *	Latest Version: 5/3/2023 
 *  Created By: James Nafpliotis
 *
 *****************************************************************************************/

	BEGIN
		SET NOCOUNT ON
		SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
		SELECT @enddate= COALESCE(@enddate,getdate())
		SELECT @startdate = COALESCE(@startdate,dateadd(mi,-30,@enddate))
		SELECT 
			sr.[snapshot_date]
		,	[sql_cpu_usage]
		,	[sql_cpu_effective]
		,	[Total_Server_Memory_GB]
	    ,	[Granted_Workspace_Memory_GB]
		,	[Page_life]
	    ,	[Batch_Requests_sec]
		,	[Transactions_sec]
		,	[logical_reads_sec]
		,	[Page_reads_sec]
		,	[Page_writes_sec]
		,	[Readahead_pages_sec]
		,	[Log_Flush_Waits_sec]
		,	[Bulk_Copy_Throughput_sec]
		,	[Lock_waits_ms]
		,	[Page_IO_latch_waits_ms]
		,	[Network_IO_waits_ms]
		,	[Page_latch_waits_ms]
		,	[Memory_grant_queue_waits_ms]
		,	[Wait_for_the_worker_ms]
		,	[Log_write_waits_ms]
		,	[NON_Page_latch_waits_ms]
		,	[Log_buffer_waits_ms]
	    ,	[buffer_cache_hit_ratio]
	    ,	[Target_Server_Memory_GB]
		,	[Database_Cache_Memory_GB]
		,	[Free_Memory_GB]
		FROM [dbperf].[vw_summary_ratio] sr
		JOIN [dbperf].[vw_memory_snapshot] ms
			ON sr.snapshot_date =ms.snapshot_date
		JOIN [dbperf].[vw_database_Throughput] dt
			ON sr.snapshot_date =dt.snapshot_date
		JOIN [dbperf].[vw_waittime_Snapshot] ws
			ON sr.snapshot_date =ws.snapshot_date
		WHERE sr.snapshot_date between @startdate and @enddate
		ORDER BY sr.snapshot_date DESC


--------------print ' all waits'
		SELECT 
			snapshot_date
		,	wait_type
		,	CAST(SUM(wait_time)
				/
				(	select SUM(wait_time) 
					from dbperf.dba_wait_summary w2
					where w2.snapshot_date =w1.snapshot_date
					group by snapshot_date)*100 as numeric(5,2)
				) AS wait_pct
		,	CAST(SUM(signal_wait_time)
				/
				(	select SUM(signal_wait_time) 
					from dbperf.dba_wait_summary w2
					where w2.snapshot_date =w1.snapshot_date
					group by snapshot_date 
					having SUM(signal_wait_time)>0)*100 as numeric(5,2)
				) AS signal_wait_pct
		,	MAX([wait_time_request_average]) AS wait_time_request_average
		,	MAX([signal_wait_time_request_average]) AS signal_wait_time_request_average
		FROM dbperf.dba_wait_summary w1
		WHERE snapshot_date between @startdate and @enddate 
		GROUP BY wait_type,snapshot_date
		HAVING SUM(wait_time)>0
		ORDER BY 1 DESC,4 DESC
--print '--------------------------- io summary (30 min)------------------------------'
select database_name,sum(num_of_reads) as total_reads,sum(num_of_writes ) as total_writes
,sum(io_stall_ms) as sum_io_stall_ms from 
dbperf.dba_filestats
where snapshot_date between @startdate and @enddate 
group by database_name
--print '--------------------------- DB io summary (30 min)------------------------------'
select database_name,sum(num_of_reads) as total_reads,sum(num_of_writes ) as total_writes
,sum(io_stall_ms) as sum_io_stall_ms from 
dbperf.dba_filestats
where snapshot_date  between @startdate and @enddate 
and db_file_type = 'rows'
group by database_name


--print '--------------------------- io  tlog summary )------------------------------'
select database_name,sum(num_of_reads) as total_reads,sum(num_of_writes ) as total_writes
,sum(io_stall_ms) as sum_io_stall_ms from 
dbperf.dba_filestats
where snapshot_date  between @startdate and @enddate 
and db_file_type = 'LOG'
 group by database_name


END



