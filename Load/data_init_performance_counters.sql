/* Inititial load of most performance counters into a user table.
*  Most of the individual database specific counters have been filtered out.
*  Feel free to just remove the where clause  to load them all, but You will have to remember to  add the new database specific parameters.
*  DEPENDENCIES: [dbperf].[dba_Instance_perf_param]
*  --trim required 
*				SQL Sever 2014+
*  Original Author: James Nafpliotis
************************************************/
Declare @EngineEdition INT
DECLARE @perf_obj_string varchar(100);

SELECT @EngineEdition = CAST(SERVERPROPERTY('EngineEdition') AS INT);
-- Object_name column has  different values  between PAAS services  and IAAS/On-Prem.
BEGIN TRY
IF ((@EngineEdition <= 4 )
and  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbperf].[dba_Instance_perf_param]') AND type in (N'U'))
)
BEGIN
SELECT @perf_obj_string ='SQL Server'
END
IF ((@EngineEdition = 5 )
and  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbperf].[dba_Instance_perf_param]') AND type in (N'U'))
)
BEGIN
select @perf_obj_string = (select distinct  SUBSTRING([OBJECT_NAME],1, CHARINDEX ( ':', [OBJECT_NAME])-1) 
from sys.dm_os_performance_counters
where object_name like 'MSSQL$%');
END
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
WHERE  object_name <> @perf_obj_string+':Databases' 
AND	object_name <>@perf_obj_string+':Catalog Metadata'   
AND object_name <> @perf_obj_string+':Deprecated Features' 
AND object_name <> @perf_obj_string+':Query Store'
AND object_name <> @perf_obj_string+':Columnstore'                                                                                                           
AND	object_name <> @perf_obj_string+':Advanced Analytics'
AND object_name <> @perf_obj_string+'::Broker Activation' 
UNION
SELECT 
	CHECKSUM	(object_name,counter_name,instance_name) AS [Inst_perf_param_id]
,			trim(object_name),trim(counter_name),trim(instance_name),cntr_type,0,0 AS [Log_ind]

FROM sys.dm_os_performance_counters
WHERE	( object_name = @perf_obj_string+':Databases'			and instance_name in ('_Total','tempdb') )
OR		(object_name =@perf_obj_string+':Catalog Metadata'		and instance_name in ('_Total','tempdb') )   
OR		(object_name = @perf_obj_string+':Deprecated Features'	and instance_name in ('_Total','tempdb') ) 
OR		(object_name = @perf_obj_string+':Query Store'			and instance_name in ('_Total','tempdb') )
OR		(object_name = @perf_obj_string+':Columnstore'			and instance_name in ('_Total','tempdb') )                                                                                                           
OR		(object_name = @perf_obj_string+':Advanced Analytics'	and instance_name in ('_Total','tempdb') )
OR		(object_name = @perf_obj_string+':Broker Activation'	and instance_name in ('_Total','tempdb') )
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

IF (@EngineEdition <= 4 OR  @EngineEdition =8) -- Azure SQL Managed Instance
BEGIN
INSERT INTO [dbperf].[dba_Instance_perf_param]
           ([Inst_perf_param_id]
           ,[object_nm]
           ,[counter_nm]
           ,[instance_nm]
           ,[Log_ind]
           ,[counter_type]
           ,[parent_param_id]

           )
SELECT checksum('Custom:IO',	'Physical Reads',	'Total'),'Custom:IO','Physical Reads',	'Total'
,0 -- log all 
,-1 AS cntr_type
,null
UNION

SELECT checksum('Custom:Network',	'Total Packets Sent',	'Total'),'Custom:IO',	'Total Packets Sent',	'Total'
,0 -- log all 
,-1 AS cntr_type
,null
UNION

SELECT checksum('Custom:IO',	'SQL IO Util',	'Total'),'Custom:IO',	'SQL IO Util',	'Total'
,0 -- log all 
,-1 AS cntr_type
,null
UNION

SELECT checksum('Custom:IO',	'Physical Writes',	'Total'),'Custom:IO',	'Physical Writes',	'Total'
,0 -- log all 
,-1 AS cntr_type
,null
UNION

SELECT checksum('Custom:Processor',	'SQL CPU Idle',	'Total'),'Custom:Processor',	'SQL CPU Idle',	'Total'
,0 -- log all 
,-1 AS cntr_type
,null
UNION

SELECT checksum('Custom:Processor',	'SQL CPU Util',	'Total'),'Custom:Processor',	'SQL CPU Util',	'Total'
,0 -- log all 
,-1 AS cntr_type
,null
UNION

SELECT checksum('Custom:Network',	'Total Packet Errors',	'Total'),'Custom:Network',	'Total Packet Errors',	'Total'
,0 -- log all 
,-1 AS cntr_type
,null
UNION

SELECT checksum('Custom:Network',	'Total Packets Received',	'Total'),'Custom:Network',	'Total Packets Received',	'Total'
,0 -- log all 
,-1 AS cntr_type
,null
UNION

SELECT checksum('Custom:Memory'	,'Buffer Cache Quality',	'Total'),'Custom:Memory',	'Buffer Cache Quality',	'Total'
,0 -- log all 
,-1 AS cntr_type
,null
UNION

SELECT checksum('Custom:Processor',	'Total System CPU',	'Total'),'Custom:Processor',	'Total System CPU',	'Total'
,0 -- log all 
,-1 AS cntr_type
,null

END
END TRY
BEGIN CATCH  
    SELECT   
        ERROR_NUMBER() AS ErrorNumber  
       ,ERROR_MESSAGE() AS ErrorMessage;  
END CATCH  







