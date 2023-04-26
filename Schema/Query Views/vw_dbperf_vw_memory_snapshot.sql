CREATE VIEW dbperf.vw_memory_snapshot
as
/*****************************************************************************************
 *
 * NAME: dbperf.vw_memory_snapshot
 *
 * PURPOSE:			View of memory snapshot counters. 
 * DESCRIPTION:		'Granted Workspace Memory (KB)' value 
 *					depends on the polling granularity and if the Queries have a long execution time.
 * INSTALLATION:	Install on a seperated schema in Azure SQL database.
 *
 * USAGE: 
 		select * 
 		from dbperf.vw_memory_snapshot
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
	,	MAX(CASE WHEN counter_nm = 'Total Server Memory (KB)'
				THEN Instance_perf_value/1024/1024
			END)  AS Total_Server_Memory_GB
	,	MAX(CASE WHEN counter_nm = 'Target Server Memory (KB)'
				THEN Instance_perf_value/1024/1024 
			END)  AS Target_Server_Memory_GB
	,	MAX(CASE WHEN counter_nm = 'Database Cache Memory (KB)'
				THEN Instance_perf_value/1024/1024 
			END)  AS Database_Cache_Memory_GB
	,	MAX(CASE WHEN counter_nm = 'Stolen Server Memory (KB)'
				THEN Instance_perf_value/1024/1024 
			END)  AS StolenServer_Memory_GB
	,	MAX(CASE WHEN counter_nm = 'Maximum Workspace Memory (KB)'
				THEN  Instance_perf_value/1024/1024 
			END) Maximum_Workspace_Memory_GB
	,	MAX(CASE WHEN counter_nm = 'Granted Workspace Memory (KB)'
				THEN Instance_perf_value/1024/1024 
			END)  AS Granted_Workspace_Memory_GB
	,	MAX(CASE WHEN counter_nm = 'Free Memory (KB)'
				THEN Instance_perf_value/1024/1024 
			END)  AS Free_Memory_GB
	,	MAX(CASE WHEN counter_nm = 'Connection Memory (KB)'
				THEN Instance_perf_value/1024/1024 
			END)  AS Connection_Memory_GB
	,	MAX(CASE WHEN counter_nm = 'Page life expectancy'
				THEN Instance_perf_value 
			END)  AS Page_life
	FROM [dbperf].[dba_Instance_perf_param] p
	JOIN  [dbperf].[dba_Instance_perf_snap] s
	ON p.[Inst_perf_param_id]= s.[Inst_perf_param_id]
	WHERE startup_measure_ind =0
	AND  (		object_nm like '%Memory Manager'
			OR object_nm like '%Buffer Manager')
	AND (		 instance_nm ='_Total'
			OR	instance_nm =''	)
	GROUP BY snapshot_date