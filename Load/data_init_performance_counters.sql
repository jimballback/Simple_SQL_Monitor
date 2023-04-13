/* Inititial load of most performance counters into a user table.
*  Most of the individual database specific counters have been filtered out.
*  Feel free to just remove the where clause  to load them all, but You will have to remember to  add the new database specific parameters.
*  DEPENDENCIES: [dbperf].[dba_Instance_perf_param]
*  --trim required 
*				SQL Sever 2014+
*  Original Author: James Nafpliotis
************************************************/
Declare @EngineEdition INT
SELECT @EngineEdition = CAST(SERVERPROPERTY('EngineEdition') AS INT);
-- Object_name column has  different values  between PAAS services  and IAAS/On-Prem.
BEGIN TRY
IF ((@EngineEdition <= 4 )
and  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbperf].[dba_Instance_perf_param]') AND type in (N'U'))
)
BEGIN
--https://learn.microsoft.com/en-us/sql/t-sql/functions/serverproperty-transact-sql?view=sql-server-ver16
INSERT INTO [dbperf].[dba_Instance_perf_param]
           ([Inst_perf_param_id]
           ,[object_nm]
           ,[counter_nm]
           ,[instance_nm]
           ,[counter_type]
           ,[parent_param_id]
           ,[Log_ind])
SELECT 
	CHECKSUM	(object_name,counter_name,instance_name) AS [Inst_perf_param_id]
,				trim(object_name),trim(counter_name),trim(instance_name),cntr_type,0,0 AS [Log_ind]

FROM sys.dm_os_performance_counters
WHERE  object_name <> 'SQLServer:Databases' 
AND	object_name <>'SQLServer:Catalog Metadata'   
AND object_name <> 'SQLServer:Deprecated Features' 
AND object_name <> 'SQLServer:Query Store'
AND object_name <> 'SQLServer:Columnstore'                                                                                                           
AND	object_name <> 'SQLServer:Advanced Analytics'
AND object_name <> 'SQLServer:Broker Activation' 
UNION
SELECT 
	CHECKSUM	(object_name,counter_name,instance_name) AS [Inst_perf_param_id]
,			trim(object_name),trim(counter_name),trim(instance_name),cntr_type,0,0 AS [Log_ind]

FROM sys.dm_os_performance_counters
WHERE	( object_name = 'SQLServer:Databases'			and instance_name in ('_Total','tempdb') )
OR		(object_name ='SQLServer:Catalog Metadata'		and instance_name in ('_Total','tempdb') )   
OR		(object_name = 'SQLServer:Deprecated Features'	and instance_name in ('_Total','tempdb') ) 
OR		(object_name = 'SQLServer:Query Store'			and instance_name in ('_Total','tempdb') )
OR		(object_name = 'SQLServer:Columnstore'			and instance_name in ('_Total','tempdb') )                                                                                                           
OR		(object_name = 'SQLServer:Advanced Analytics'	and instance_name in ('_Total','tempdb') )
OR		(object_name = 'SQLServer:Broker Activation'	and instance_name in ('_Total','tempdb') )
ORDER BY 1 DESC ,2 DESC,3 DESC;


---  Update Parent record, The Base Counters.

WITH parent ([Inst_perf_param_id],object_nm,counter_nm,instance_nm,counter_type)
AS (
	SELECT [Inst_perf_param_id],object_nm,concat(trim(REPLACE(counter_nm,' (ms)','')),' base') as counter_nm,instance_nm,counter_type
	FROM[dbperf].[dba_Instance_perf_param]
	WHERE counter_type ='537003264'
	)
UPDATE [dbperf].[dba_Instance_perf_param] set parent_param_id =parent.Inst_perf_param_id
from parent 
join  [dbperf].[dba_Instance_perf_param] 

ON dbperf.dba_Instance_perf_param.object_nm = parent.object_nm
AND dbperf.dba_Instance_perf_param.instance_nm = parent.instance_nm
AND dbperf.dba_Instance_perf_param.counter_nm=parent.counter_nm
WHERE dbperf.dba_Instance_perf_param.counter_type in ( 1073939712 );
END;

END TRY
BEGIN CATCH  
    SELECT   
        ERROR_NUMBER() AS ErrorNumber  
       ,ERROR_MESSAGE() AS ErrorMessage;  
END CATCH  







