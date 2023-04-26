CREATE VIEW dbperf.vw_waittime_Snapshot
AS
/*****************************************************************************************
 *
 * NAME: dbperf.vw_waittime_Snapshot
 *
 * PURPOSE:			View of the wait statistics performance counters with a average wait time instance.
 *					
 * DESCRIPTION:		AS these are snapshots, they might not be quite as useful if your
 *					poll interval is not granular enough.
 *
 * INSTALLATION:	Install on a seperated schema in Azure SQL database or a seperate DB on-pre.IAAS,Managed Instance.
 *
 * USAGE: 
 		select * 
 		FROM dbperf.vw_waittime_Snapshot
 		where snapshot_date >= dateadd(hour, -1,getdate())
		order by snapshot_date desc
 *
 *
 *	Latest VersiON: 4/18/2023 
 *  Created By: James Nafpliotis
 *
 *****************************************************************************************/
	
	SELECT
		snapshot_date
	,	MAX(CASE WHEN counter_nm = 'Lock waits'
					AND instance_nm = 'Average wait time (ms)'
				THEN Instance_perf_value
				END) AS Lock_waits_ms
	,	MAX(CASE WHEN counter_nm = 'Page IO latch waits'
				AND instance_nm = 'Average wait time (ms)'
				THEN Instance_perf_value
				END) AS Page_IO_latch_waits_ms
	,	MAX(CASE WHEN counter_nm = 'Network IO waits'
				AND instance_nm = 'Average wait time (ms)'
				THEN Instance_perf_value 
				END) AS Network_IO_waits_ms
	,
		MAX(CASE WHEN counter_nm = 'Page latch waits'
				AND instance_nm = 'Average wait time (ms)'
				THEN Instance_perf_value 
				END) AS  Page_latch_waits_ms 
	,	MAX(CASE WHEN counter_nm = 'Memory grant queue waits'
				AND instance_nm = 'Average wait time (ms)'
				THEN Instance_perf_value
			END) AS Memory_grant_queue_waits_ms
	,	MAX(CASE WHEN counter_nm = 'Wait for the worker'
				AND instance_nm = 'Average wait time (ms)'
				THEN Instance_perf_value
			END) AS Wait_for_the_worker_ms
	,	MAX(CASE WHEN counter_nm = 'Log write waits'
			AND instance_nm = 'Average wait time (ms)'
			THEN Instance_perf_value
			END) AS Log_write_waits_ms
	,	MAX(CASE WHEN counter_nm = 'NON-Page latch waits'
				AND instance_nm = 'Average wait time (ms)'
				THEN Instance_perf_value 
				END) AS NON_Page_latch_waits_ms
	,	MAX(CASE WHEN counter_nm = 'Log buffer waits'
				AND instance_nm = 'Average wait time (ms)'
				THEN Instance_perf_value
				END) AS Log_buffer_waits_ms
	FROM [dbperf].[dba_Instance_perf_param] p
	JOIN  [dbperf].[dba_Instance_perf_snap] s
		ON p.[Inst_perf_param_id]= s.[Inst_perf_param_id]
	WHERE startup_meASure_ind =0
		AND  object_nm LIKE '%Wait Statistics'
	GROUP BY snapshot_date