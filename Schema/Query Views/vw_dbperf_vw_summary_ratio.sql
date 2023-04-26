CREATE VIEW dbperf.vw_summary_ratio
AS
/*****************************************************************************************
 *
 * NAME: dbperf.vw_summary_ratio
 *
 * PURPOSE:			View  of the main ratio records. SQL CPU and Buffer Cache ratio. 
 *					
 * DESCRIPTION:		As these are snaspshots, they might not be quite as useful if your
 *					poll interval is not granular enough.
 *					Counter types 537003264 and 1073939712 counter types are a snapshot of
 *					the ratio if the counter name and counter name base.
 *					A -1 represents data not being monitored.
 * INSTALLATION:	Install on a seperated schema in Azure SQL database.
 *
 * USAGE: 
 		select * 
 		from dbperf.vw_summary_ratio
 		where snapshot_date >= dateadd(hour, -1,getdate())
		order by snapshot_date desc
 *
 *
 *	Latest Version: 4/18/2023 
 *  Created By: James Nafpliotis
 *
 *****************************************************************************************/
	SELECT
		sbase.snapshot_date
	,	CAST((MAX(CASE	WHEN parent.counter_nm = 'CPU usage %' and parent.instance_nm = 'default'  and pbase.Instance_perf_value is not null
						THEN pbase.Instance_perf_value
						ELSE -1
						END) 
		/
			MAX(CASE WHEN base.counter_nm = 'CPU usage % base' and base.instance_nm = 'default' and sbase.Instance_perf_value is not null and pbase.Instance_perf_value <>0
						THEN sbase.Instance_perf_value
						ELSE -1
						END) *100 )  AS NUMERIC(5,2) ) 
		 AS	sql_cpu_usage
	,	CAST((MAX(CASE	WHEN parent.counter_nm = 'CPU effective %' and parent.instance_nm = 'default' and pbase.Instance_perf_value is not null
						THEN pbase.Instance_perf_value
						ELSE -1
						END) 
		/
			MAX(CASE WHEN base.counter_nm = 'CPU effective % base' and base.instance_nm = 'default' and sbase.Instance_perf_value is not null and sbase.Instance_perf_value <>0
					THEN sbase.Instance_perf_value
					ELSE -1
					END)  *100 )  AS NUMERIC(5,2) ) 
		AS sql_cpu_effective
	,	CAST((MAX(CASE WHEN parent.counter_nm = 'Buffer cache hit ratio' and parent.instance_nm = '' and pbase.Instance_perf_value is not null
						THEN pbase.Instance_perf_value
						ELSE -1
					END) 
		/
			MAX(CASE WHEN base.counter_nm = 'Buffer cache hit ratio base' and base.instance_nm = '' and sbase.Instance_perf_value is not null and sbase.Instance_perf_value <>0
				THEN sbase.Instance_perf_value
				ELSE -1
				END)  *100 )  AS NUMERIC(5,2) ) 
		AS buffer_cache_hit_ratio


	--SELECT sbase.snapshot_date,base.*,parent.*,sbase.instance_perf_value,pbase.instance_perf_value
	FROM [XAdminDB].[dbperf].[dba_Instance_perf_param] base
	JOIN [XAdminDB].[dbperf].[dba_Instance_perf_param] parent
	ON base.parent_param_id = parent.Inst_perf_param_id
	JOIN [dbperf].[dba_Instance_perf_snap] sbase
	ON sbase.inst_perf_param_id = base.Inst_perf_param_id
	JOIN [dbperf].[dba_Instance_perf_snap] pbase
	ON pbase.inst_perf_param_id=parent.Inst_perf_param_id
	AND sbase.snapshot_date =pbase.snapshot_date
	AND BASE.log_ind =1
	AND parent.log_ind =1
	AND (	sbase.instance_perf_value IS NOT NULL 
		OR	sbase.instance_perf_value <> 0
		OR pbase.instance_perf_value IS NOT NULL
		OR pbase.instance_perf_value <>0
		)
	GROUP BY sbase.snapshot_date
	--ORDER BY sbase.snapshot_date DESC
