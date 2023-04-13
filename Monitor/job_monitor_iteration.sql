/**************************************
* NAME:	iteration script for the monitor procedures.
* DESCRIPTION:	To be used as a  one off run or a demo. Otherwise you should use a job scheduler.
*
*
*
**************************************/

--begin batch
	DECLARE @iteration_num SMALLINT =1
	DECLARE @iteration_count SMALLINT =400
	DECLARE @delay	char(8)= '00:02:00'

WHILE @iteration_num <=@iteration_count
BEGIN

	exec dbperf.uspDBA_AZURE_Monitor_Performance  @debug =0;

	SELECT @iteration_num = @iteration_num + 1;
	WAITFOR DELAY @delay;	
END