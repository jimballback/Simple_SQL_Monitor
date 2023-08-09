IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbperf].[vw_database_throughput]'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE VIEW [dbperf].[vw_database_throughput]
as
SeleCT 1 AS col1'
END
GO
ALTER VIEW dbperf.vw_database_throughput
AS

/*****************************************************************************************
 *
 * NAME: dbperf.vw_database_throughput
 *
 * PURPOSE:			View of counters that can be calculated in a certain interval.
 * DESCRIPTION:		Counters are calculated  by difference.
 *					
 * INSTALLATION:	Install on a seperated schema in Azure SQL database.
 *
 * USAGE: 
 		select * 
 		from dbperf.vw_database_throughput
 		where snapshot_date >= dateadd(hour, -4,getdate())
		order by snapshot_date desc
 *
 *
 *	Latest Version: 4/18/2023 
 *  Created By: James Nafpliotis
 *
 *****************************************************************************************/
  
 SELECT
		snapshot_date
	,	MAX(CASE WHEN counter_nm = 'Batch Requests/sec '
				THEN Instance_perf_value
			END) AS Batch_Requests_sec 
	,	MAX(CASE WHEN	counter_nm = 'Transactions/sec'
					AND instance_nm	='_TOTAL'
				THEN Instance_perf_value
			END) AS Transactions_sec
	,	MAX(CASE WHEN counter_nm = 'Page Lookups/sec'
				THEN Instance_perf_value
			END) AS logical_reads_sec
	,	MAX(CASE WHEN counter_nm = 'Page reads/sec'
				THEN Instance_perf_value
			END) AS Page_reads_sec
	,	MAX(CASE WHEN counter_nm = 'Page writes/sec'
				THEN Instance_perf_value
			END) AS Page_writes_sec
	,	MAX(CASE WHEN counter_nm = 'Readahead pages/sec'
				THEN Instance_perf_value
			END) AS Readahead_pages_sec
	,	MAX(CASE WHEN	counter_nm	= 'Log Flush Waits/sec'
					AND instance_nm	='_TOTAL'
				THEN  Instance_perf_value 
			END) AS Log_Flush_Waits_sec
	,	MAX(CASE WHEN	counter_nm	= 'Bulk Copy Throughput/sec'
					AND instance_nm	='_TOTAL'
				THEN Instance_perf_value 
			END) AS Bulk_Copy_Throughput_sec
	,	MAX(CASE WHEN	counter_nm = 'Errors/sec'
					AND	instance_nm	='_TOTAL'
				THEN Instance_perf_value 
			END) AS Errors_sec 
	,	MAX(CASE WHEN counter_nm = 'Logins/sec'
				THEN Instance_perf_value 
			END) AS Logins_sec 
	,	MAX(CASE WHEN counter_nm = 'Logouts/sec'
				THEN Instance_perf_value 
			END) AS Logouts_sec
	,	MAX(CASE WHEN counter_nm = 'Connection Reset/sec'
				THEN Instance_perf_value 
			END) AS Connection_Reset_sec
	,	MAX(CASE WHEN counter_nm = 'SQL Re-Compilations/sec'
				THEN Instance_perf_value 
			END) AS SQL_ReCompilations_sec
	,	MAX(CASE WHEN counter_nm = 'SQL Compilations/sec'
				THEN Instance_perf_value 
			END) AS SQL_Compilations_sec
	FROM [dbperf].[dba_Instance_perf_param] p
	JOIN  [dbperf].[dba_Instance_perf_snap] s
	ON p.[Inst_perf_param_id]= s.[Inst_perf_param_id]
	WHERE startup_measure_ind =0
	GROUP BY snapshot_date