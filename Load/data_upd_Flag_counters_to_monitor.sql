/*  Set the flag counters to perform logging.
*  
* 
*  DEPENDENCIES: [dbperf].[dba_Instance_perf_param]
*  Original Author: James Nafpliotis
************************************************/
UPDATE [dbperf].[dba_Instance_perf_param]
SET		[Log_ind] = 1
WHERE  object_nm like '%general statistics'
  AND	(
			counter_nm  ='Logins/sec'
		OR	counter_nm  ='Logouts/sec'
		OR	counter_nm  ='Connection Reset/sec'
		OR	counter_nm  ='Temp Tables Creation Rate'
		OR	counter_nm  ='Processes blocked' 
		OR  counter_nm  ='User Connections'
		)   ;

UPDATE [dbperf].[dba_Instance_perf_param]
SET		[Log_ind] = 1
WHERE  object_nm like '%buffer manager'
  AND	(
			counter_nm  ='Page reads/sec'                                                                                                                  
		OR	counter_nm  ='Page writes/sec'                                                                                                                 
		OR	counter_nm  ='Lazy writes/sec'                                                                                                                 
		OR	counter_nm  ='Checkpoint pages/sec'                                                                                                            
		OR	counter_nm  ='Buffer cache hit ratio'                                                                                                     
		OR  counter_nm  ='Page lookups/sec'
		OR  counter_nm  ='Readahead pages/sec'
		OR  counter_nm  ='Page life expectancy'                                                                                                            
		);

UPDATE [dbperf].[dba_Instance_perf_param]
SET		[Log_ind] = 1
WHERE  object_nm like '%Access Methods'
  AND	(
			counter_nm  ='Forwarded Records/sec'                                                                                                                  
		OR	counter_nm  ='Page Splits/sec'                                                                                                                 
		OR	counter_nm  ='Full Scans/sec'                                                                                                                 
                                                                                                   
		);

UPDATE [dbperf].[dba_Instance_perf_param]
SET		[Log_ind] = 1
WHERE  object_nm like '%Locks'

  AND	(	counter_nm  = 'Lock Timeouts/sec'
		OR	counter_nm  ='Number of Deadlocks/sec'                                                                                                                  
		OR	counter_nm  ='Lock Wait Time (ms)'                                                                                                                 
	--	OR	counter_nm  ='Lock Timeouts (timeout > 0)/sec'                                                                                                                 
                                                                                                   
		)
  AND instance_nm ='_Total';

UPDATE [dbperf].[dba_Instance_perf_param]
SET		[Log_ind] = 1
WHERE  object_nm like '%SQL Errors'
  AND	(	counter_nm  = 'Errors/sec'
                                                                                       
		)
  AND instance_nm ='_Total';

UPDATE [dbperf].[dba_Instance_perf_param]
SET		[Log_ind] = 1
WHERE  object_nm like '%SQL Statistics'

  AND	(	counter_nm  = 'Batch Requests/sec'
		OR	counter_nm  ='SQL Compilations/sec'                                                                                                                  
		OR	counter_nm  ='SQL Re-Compilations/sec'                                                                                                                 
		OR	counter_nm  ='SQL Attention rate'                                                                                                                 
                                                                                                   
		);

UPDATE [dbperf].[dba_Instance_perf_param]
SET		[Log_ind] = 1
WHERE  object_nm like '%Memory Manager'
  AND	(	counter_nm  = 'Connection Memory (KB)'
		OR	counter_nm  = 'Database Cache Memory (KB)'                                                                                                                  
		OR	counter_nm  = 'Free Memory (KB)'                                                                                                                 
		OR	counter_nm  = 'Granted Workspace Memory (KB)' 
       	OR	counter_nm  = 'Lock Memory (KB)'                                                                                                                  
		OR	counter_nm  = 'Free Memory (KB)'                                                                                                                 
		OR	counter_nm  = 'Maximum Workspace Memory (KB)'  
		OR	counter_nm  = 'Optimizer Memory (KB)'                                                                                                                  
		OR	counter_nm  = 'SQL Cache Memory (KB)'                                                                                                                 
		OR	counter_nm  = 'Stolen Server Memory (KB)'  
		OR	counter_nm  = 'Log Pool Memory (KB)'  
		OR	counter_nm  = 'Target Server Memory (KB)'                                                                                                                  
		OR	counter_nm  = 'SQL Cache Memory (KB)'                                                                                                                 
		OR	counter_nm  = 'Total Server Memory (KB)' 

		);

UPDATE [dbperf].[dba_Instance_perf_param]
SET		[Log_ind] = 1
WHERE  object_nm like '%Wait Statistics'
  AND	(	counter_nm  = 'Lock waits'
		OR	counter_nm  = 'Memory grant queue waits'                                                                                                                  
	--	OR	counter_nm  = 'Thread-safe memory objects waits'                                                                                                                 
		OR	counter_nm  = 'Log write waits' 
       	OR	counter_nm  = 'Log buffer waits'                                                                                                                  
		OR	counter_nm  = 'Network IO waits'                                                                                                                 
		OR	counter_nm  = 'Page IO latch waits'  
		OR	counter_nm  = 'Page latch waits'                                                                                                                  
		OR	counter_nm  = 'Non-Page latch waits'                                                                                                                 
		OR	counter_nm  = 'Wait for the worker'  
		OR	counter_nm  = 'Workspace synchronization waits'  
	--	OR	counter_nm  = 'Transaction ownership waits'                                                                                                                  
		)
  AND instance_nm = 'Average wait time (ms)';	

UPDATE [dbperf].[dba_Instance_perf_param]
SET		[Log_ind] = 1		
WHERE  object_nm like '%Databases'

  AND	(	counter_nm  = 'Transactions/sec'
		OR	counter_nm  = 'Bulk Copy Rows/sec'                                                                                                                  
		OR	counter_nm  = 'Log Flush Waits/sec' 
       	OR	counter_nm  = 'Log Flush Write Time (ms)'                                                                                                                  
		OR	counter_nm  = 'Backup/Restore Throughput/sec'                                                                                                                 
		)
  AND instance_nm = '_Total';
