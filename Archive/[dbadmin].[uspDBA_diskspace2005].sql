USE [XAdminDB]
GO

/****** Object:  StoredProcedure [dbadmin].[uspDBA_diskspace2005]    Script Date: 6/19/2023 1:25:39 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER OFF
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbadmin].[uspDBA_diskspace2005]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbadmin].[uspDBA_diskspace2005] AS' 
END
GO

ALTER PROCEDURE [dbadmin].[uspDBA_diskspace2005] 
	(	@snapshot_date datetime = null          /* INPUT:snapshot date of the point in time metric was taken: pass in if part of on overall script */
	,	@log_flag bit = 1
	,	@disk_freepct_threshold INT = NULL
	,	@results_flag  bit = 1                  
	)
AS



/****************************************************************
 *
 * 
 * NAME: dbadmin.uspDBA_diskspace2005 @disk_freepct_threshold = 60
 *
 * PURPOSE:     Displays  and optionally records the free space,free space percentage 
                plus total drive size for a server used by the instance(s).
                THis is a derivative of the common ole procedure that is found comonly in the community.
                
 *
 * DESCRIPTION: This procedure calculates free space and if required logs data into dba_diskusage
 *					
                            if the threshold is reached it raises a 900000 error. Use the 2005 alert mechanism for email.
 *  						A null threshold is interpreted as that alerting is not required
 *							
 *			NOTE: This only alerts  on disks that are being used by at least one database!
 *
 * USAGE:	EXEC dbadmin.uspDBA_diskspace2005 @snapshot_date = NULL,@log_flag =0,@disk_freepct_threshold=15.00,@results_flag =1
 * AUTHOR: <Author,sysname,' '>	LAST MODIFIED BY: $Author:  $
 * CREATED: <date,datetime,''>	LAST MODIFIED ON: $Modtime: $
 *
 * CURRENT REVISION: $Revision:  $
 * HISTORY (Most recent first): $History:  $
 * 
 * Updated in $
 *
 * 
 *****************************************************************/
	DECLARE			
            @errno int,                                         /* used to return a number on error              */
            @errmsg varchar(50),                               /* used for custom on the fly errror messages   */
            @err_param1 varchar(50),                             /* the first error paramaeter passed that interpolates based on the sysmessages entry */
            @err_param2 varchar(50),                            /* the second error paramaeter passed that interpolates based on the sysmessages entry */
            @syserror varchar(6)                               /*  a system error code checked via  system error function @@error to determine is an error occured  */
 

	SET NOCOUNT ON

	DECLARE @hr int
	DECLARE @fso int
	DECLARE @drive char(1)
	DECLARE @odrive int
	DECLARE @TotalSize varchar(20)
	DECLARE @MB bigint ; SET @MB = 1048576
	DECLARE @server_name sysname 
	DECLARE @message  VARCHAR(8000)
	DECLARE @Subj VARCHAR(60)
	DECLARE @counter tinyint
	DECLARE @maxcounter tinyint
	         
/*----------------basic error ---------------------------
error       severity dlevel description  
100100      12       128    Insert failed on %s. Called by %s.                                                                                                                                                                                                                              1033
100120      12       128    Update failed on %s. Called by %s.                                                                                                                                                                                                                              1033
100140      12       128    Delete failed on %s. Called by %s.                                                                                                                                                                                                                              1033
300000      12       0      General Validation error: %s. Called by %s.    

*/ 
      IF (@@error <>0)
			  BEGIN
    		  SELECT @errno = 300000,@err_param1='error',@err_param2 ='spDBA_diskspace'
				  GOTO error
			   END


  SELECT @server_name = @@SERVERNAME
  IF @snapshot_date is null
	  begin
	  	SELECT @snapshot_date = CURRENT_TIMESTAMP
	  end

  CREATE TABLE #drives (id  int identity(1,1),drive char(1) PRIMARY KEY,
                      FreeSpace int NULL,
                      TotalSize int NULL)


INSERT #drives(drive,FreeSpace) 
EXEC master.dbo.xp_fixeddrives

EXEC @hr=sp_OACreate 'Scripting.FileSystemObject',@fso OUT
IF @hr <> 0 EXEC sp_OAGeterrorInfo @fso

DECLARE dcur CURSOR LOCAL FAST_FORWARD
FOR SELECT drive from #drives
ORDER by drive

OPEN dcur

FETCH NEXT FROM dcur INTO @drive

WHILE @@FETCH_STATUS=0
BEGIN

        EXEC @hr = sp_OAMethod @fso,'GetDrive', @odrive OUT, @drive
        IF @hr <> 0 EXEC sp_OAGeterrorInfo @fso
        
        EXEC @hr = sp_OAGetProperty @odrive,'TotalSize', @TotalSize OUT
        IF @hr <> 0 EXEC sp_OAGeterrorInfo @odrive
                        
        UPDATE #drives
        SET TotalSize=@TotalSize/@MB
        WHERE drive=@drive
        
        FETCH NEXT FROM dcur INTO @drive

END

CLOSE dcur
DEALLOCATE dcur

EXEC @hr=sp_OADestroy @fso
IF @hr <> 0 EXEC sp_OAGeterrorInfo @fso
-- if you are not logging the data and wish to just display results
IF @log_flag = 0  AND @results_flag = 1
	BEGIN
		SELECT 
			@server_name AS  SERVER
		,	[drive]
		,	[TotalSize]
		,	[FreeSpace]
		,	[TotalSize] - [FreeSpace] AS space_used
		,	CAST((FreeSpace/(TotalSize*1.0))*100.0 as NUMERIC(18,2)) AS [Free_pct] 
		, @snapshot_date as snapshot_date
		FROM #drives	

	END
	ELSE
		BEGIN
			INSERT 
			INTO [xadmindb].[dbadmin].[DBA_DriveUsage]
			(	[server_name]
			, [server_drive_partition]
			, [server_drive_partition_size_in_mb]
			, [server_drive_partition_free_in_mb]
			, [server_drive_partition_used_in_mb]
			, [server_drive_partition_free_percentage]
			, [snapshot_date]
			)
			SELECT 
				@server_name
			,	[drive]
			,	[TotalSize]
			,	[FreeSpace]
			,	[TotalSize] - [FreeSpace]
			,	CAST((FreeSpace/(TotalSize*1.0))*100.0 as NUMERIC(18,2)) AS [Free_pct] 
			, @snapshot_date
			FROM #drives

		END

------ If you have specified a threshold, raiseerror if space exceeds the specified threshold.
	IF @disk_freepct_threshold IS NOT NULL
		BEGIN
	
				IF  (	select count(*)
						from #drives d
						WHERE EXISTS (  select *
									    from  master.dbo.sysaltfiles  f with (nolock)
									    where  D.drive = substring(filename,1,1)
                	                    )           
								
						 AND CAST((FreeSpace/(TotalSize*1.0))*100.0 as NUMERIC(18,2)) < @disk_freepct_threshold
					    )>0
            -- format a nice message and print, its up to the alerting job mechanism to send the actual message 
				BEGIN
					Select @counter = 1
					SELECT @maxcounter = MAX(ID)
					FROM #drives
					SELECT @message = ''
					WHILE @counter <= @maxcounter
						BEGIN
							SELECT @message =	@message+ 
															+ ' Drive: '	+	drive
															+ ' Free (%): '	+	CAST (
                                                      cast( 
                                                          [FreeSpace]/([TotalSize]*1.0) -- parentheseis requierd to convert to decimal prior to div
                                                          *100.0 
                                                          as numeric(18,2)
                                                           )
                                                           as VARCHAR
                                                      )
															+	'	Space Free (MB): '+	cast(
                                                        cast(
                                                             [FreeSpace]                                                        
                                                            as numeric(18,2)
                                                             )
                                                           as varchar
                                                          )
															+	' Total Space (MB): '+ cast(              
                                                         cast(  [TotalSize]	 
                                                              as numeric(18,2)
                                                             )
                                                           as varchar
                                                          )
															+	CHAR(13)
							FROM #drives 
							WHERE id = @counter
							SELECT @counter=@counter+1
						END

                -- will auto create  a message entry
                    if (select count(*)
                         from sys.messages
                        where message_id = 900000) <1
                    begin
						exec master.dbo.sp_addmessage 
                            @msgnum = 900000
                        ,   @severity = 16 
                        ,   @msgtext = 'Disk space is lower than %d percent.
%s'
                        ,   @lang = 'us_english'
                        ,   @with_log = 'TRUE'
                    end

							
						

						 
                    PRINT @message  
                    RAISerror (900000,16,1,@disk_freepct_threshold,@message)
				END
		END
			DROP TABLE #drives

RETURN

error:
	IF @@TRANCOUNT <>0 ROLLBACK TRAN -- ROLLBACK EVERYTHING IF ANYTHING FAILS
  
	RAISerror (@errno,11,1,@err_param1,@err_param2)  -- WILL GIVE THE error BACK TO CLIENT
	RETURN @errno



GO

ALTER AUTHORIZATION ON [dbadmin].[uspDBA_diskspace2005] TO  SCHEMA OWNER 
GO

ALTER AUTHORIZATION ON [dbadmin].[uspDBA_diskspace2005] TO  SCHEMA OWNER 
GO


