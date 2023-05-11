/**************************************
* NAME:	iteration script for the monitor procedures
* DESCRIPTION:	To be used as a  one off run or a demo. Should be run as a job
*
*
*
**************************************/

--begin batch
	DECLARE @iteration_num SMALLINT =1
	DECLARE @iteration_count SMALLINT =400
	DECLARE @delay	char(8)= '00:05:00'
	DECLARE @snapshot_date datetime
	DECLARE @EngineEdition INT
WHILE @iteration_num <=@iteration_count
BEGIN
	select @snapshot_date =CURRENT_TIMESTAMP
	exec dbperf.uspDBA_AZURE_Monitor_Performance  @snapshot_date = @snapshot_date,@debug =0;
	exec dbperf.uspDBA_AZURE_Monitor_Wait_Statistics  @snapshot_date = @snapshot_date ;
	IF (@EngineEdition = 5 )
	BEGIN
		exec [dbperf].[uspdba_AZURE_archive_db_resource_stats]
	END
	SELECT @iteration_num = @iteration_num + 1;
	WAITFOR DELAY @delay;	
END