IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbperf].[vw_summary_ratio]'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE VIEW [dbperf].[vw_summary_ratio]
as
SeleCT 1 AS col1'
END
GO
ALTER VIEW dbperf.vw_summary_ratio
AS
/*****************************************************************************************
 *
 * NAME: dbperf.vw_AG_Delay
 *
 * PURPOSE:			 
 *					
 * DESCRIPTION:		Calculates the tran delay.
 * INSTALLATION:	Install on a seperated schema in Azure SQL database.
 *
 * USAGE: 
 		select * 
 		from dbperf.vw_summary_ratio
 		where snapshot_date >= dateadd(hour, -1,getdate())
		order by snapshot_date desc
 *
 *
 *	Latest Version: 1/11/2024 
 *  Created By: James Nafpliotis
 *
 *****************************************************************************************/
	