USE [QACOP]
GO
/****** Object:  StoredProcedure [dbo].[SP_Utility_DQ]    Script Date: 4/27/2020 6:52:54 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Batch submitted through debugger: SQLQuery1.sql|7|0|C:\Users\aniruddhar\AppData\Local\Temp\~vs1B11.sql
-- Batch submitted through debugger: SQLQuery1.sql|7|0|C:\Users\aniruddhar\AppData\Local\Temp\~vs759A.sql
-- Batch submitted through debugger: SQLQuery1.sql|7|0|C:\Users\aniruddhar\AppData\Local\Temp\~vsA76E.sql
--DROP PROCEDURE SP_Utility_DQ

CREATE OR ALTER PROCEDURE [dbo].[SP_Utility_DQ_TEST]

AS
/* Declare all required variables and updated list of columns for @list */
DECLARE @ScenarioCount int, @SOURCE_CNT int, @TARGET_CNT int, @FINAL_STATUS nvarchar(50) , @STATUS_DESCRIPTION nvarchar (500), @DQ_REMARKS nvarchar (500),
@id INT = 1, @i INT = 1, @s INT = 1, @COL_COUNT INT ,@COLUMN_NAME nvarchar(50) , @sqlText nvarchar(max) , @VAR nvarchar(50),
@PlanName nvarchar(max), @FileNM nvarchar(max), @DQCheck nvarchar(max), @DQFormat nvarchar(max)  , @SourceColumns nvarchar(max) = NULL
, @SourceTable nvarchar(max) = NULL , @TargetTable nvarchar(max) = NULL , @TargetColumns nvarchar(max) = NULL,
@TestScenarioDetails nvarchar(max) , @Dateformatvalue nvarchar(max), @SRCTableName nvarchar(max), @TRGTableName nvarchar(max),
@SourceColumnsReplaced nvarchar(max) = NULL, @TargetColumnsReplaced nvarchar(max) = NULL

/* Creating table variable to store the column Names */
DECLARE @column_table TABLE (
	id INT NOT NULL,
    value VARCHAR(MAX) NOT NULL )  

/* Creating table variable to store test sceanrio list */
DECLARE @testscenario TABLE(
	row_num INT NOT NULL,
    PlanName VARCHAR(MAX) NOT NULL, 
	FileNM VARCHAR(MAX) NOT NULL,
	ExecuteTest VARCHAR(MAX) NOT NULL,
	SourceTable VARCHAR(MAX) NOT NULL,
	DQCheck VARCHAR(MAX) NOT NULL,
	DQFormat VARCHAR(MAX),
	SourceColumns VARCHAR(MAX),
	TargetTable VARCHAR(MAX),
	TargetColumns VARCHAR(MAX)
	)
		
DECLARE	@TempCount TABLE (
	CNT INT NOT NULL );

BEGIN
	SET NOCOUNT ON;

/* DROP Output Result table before start of testing */
TRUNCATE TABLE SP_Utility_DQ_OUTPUT;


/* ----------------------------- Start of reading Scenario File---------------------------------  */

/* Read Information from Test Scenario document */
INSERT INTO @TestScenario  
SELECT ROW_NUMBER() OVER ( ORDER BY PlanName, FileNM ,SourceTable, DQcheck, DQFormat) row_num, * FROM SP_Utility_DQ_TestScenario where ExecuteTest = 'Y';

SET @ScenarioCount = (SELECT COUNT (*) from @TestScenario );

/* Store Information for each row */
WHILE @s <= @ScenarioCount
BEGIN

/* Extract Test scenario information */
SET @PlanName = (SELECT PlanName from @testscenario where row_num = @s );
SET @FileNM = (SELECT FileNM from @testscenario where row_num = @s );
SET @DQCheck = (SELECT DQCheck from @testscenario where row_num = @s );
SET @DQFormat = (SELECT DQFormat from @testscenario where row_num = @s );
SET @SourceTable = (SELECT SourceTable from @testscenario where row_num = @s );
SET @SourceColumns = (SELECT SourceColumns from @testscenario where row_num = @s );
SET @TargetTable = (SELECT TargetTable from @testscenario where row_num = @s );
SET @TargetColumns = (SELECT TargetColumns from @testscenario where row_num = @s );

/* ----------------------------- Start of NULL column scenario---------------------------------  */

if @DQCheck = 'Null' 
BEGIN

/* Store Column Count in @COL_COUNT variable  */
DELETE FROM @column_table

INSERT INTO @column_table  
SELECT 
ROW_NUMBER() OVER(ORDER BY value DESC) AS ID,value FROM STRING_SPLIT(@SourceColumns, ',')

SET @COL_COUNT = (SELECT count (ID)
						FROM
						@column_table );

/* Start of While Loop which adds a row per COLUMN in output Table  */

SET @i = 1    -- resetting the counter variable

WHILE @i <= @COL_COUNT
BEGIN

SET @COLUMN_NAME = (SELECT value
						FROM
						@column_table 
						 where ID = @i);

/*  ----  SQL for Source Table ----  */

DELETE from @TempCount                 -- Clear the TempCount table 
SET @SRCTableName = NULL               -- Clear the temp variable

/* Drop output table if already existing */
SET @SRCTableName = @SourceTable + '_'+ @DQCheck + '_'+ @COLUMN_NAME
SET @sqlText = N' DROP TABLE IF EXISTS '+@SRCTableName+''

EXEC (@sqlText);  

 SET @sqlText = N'
 SELECT * INTO '+ @SRCTableName + ' FROM
 (SELECT *
 FROM '+ @SourceTable + '
 Where ' + @COLUMN_NAME + ' is NULL) DQTest'

EXEC (@sqlText);

/* SQL to count the mismatched records */
SET @sqlText = N' SELECT count (*) FROM '+@SRCTableName+''

DELETE from @TempCount  
INSERT INTO @TempCount
EXEC (@sqlText);

SET @SOURCE_CNT=(SELECT * FROM @TempCount);

DELETE FROM @TempCount

/*  ----  SQL for Target Table ----  */
DELETE from @TempCount                 -- Clear the TempCount table 
SET @TRGTableName = NULL               -- Clear the temp variable

/* Drop output table if already existing */
SET @TRGTableName = @TargetTable + '_'+ @DQCheck + '_'+ @COLUMN_NAME
SET @sqlText = N' DROP TABLE IF EXISTS '+@TRGTableName+''

EXEC (@sqlText);  

 SET @sqlText = N'
 SELECT * INTO '+ @TRGTableName + ' FROM
 (SELECT *
 FROM '+ @TargetTable + '
 Where ' + @COLUMN_NAME + ' = ''NULL''  and DQ_STATUS = ''Invalid'' ) DQTest'

EXEC (@sqlText);

/* SQL to count the mismatched records */
SET @sqlText = N' SELECT count (*) FROM '+@TRGTableName+''

DELETE from @TempCount  


INSERT INTO @TempCount
EXEC (@sqlText);

SET @TARGET_CNT=(SELECT * FROM @TempCount);

DELETE FROM @TempCount

  /* Compare source and target counts and update the status accordingly */

  IF @SOURCE_CNT <> @TARGET_CNT
  SET @FINAL_STATUS = 'FAILED'
  ELSE 
  SET @FINAL_STATUS = 'PASSED'



  /* Status Description*/
/*
   IF @FINAL_STATUS = 'FAILED'
  SET @STATUS_DESCRIPTION = 'Count MISMATCH between source and target files for records with DQ_STATUS as INVALID'
  ELSE 
  SET @STATUS_DESCRIPTION = 'Count MATCH for Source and target files for records with DQ_STATUS as INVALID'
  */
  IF @SOURCE_CNT > 0 and @TARGET_CNT = 0
  SET @STATUS_DESCRIPTION = 'Table '''+@SRCTableName+''' will show mismatched records'
  ELSE IF 
  @TARGET_CNT > 0 and @SOURCE_CNT = 0
  SET @STATUS_DESCRIPTION = 'Table '''+@TRGTableName+''' will show mismatched records'
  ELSE IF 
  @TARGET_CNT > 0 and @SOURCE_CNT > 0
  SET @STATUS_DESCRIPTION = 'Table '''+@SRCTableName+''' and Table '''+@TRGTableName+''' will show mismatched records'
  ELSE
  SET @STATUS_DESCRIPTION = 'Source and target table are a complete match'

    /* DQ_REMARK Description*/

   IF @SOURCE_CNT > 0
  SET @DQ_REMARKS = 'The value of ' + @COLUMN_NAME + ' is missing'
  ELSE 
  SET @DQ_REMARKS = NULL

SET @TestScenarioDetails =  @DQCheck + coalesce('-' + @DQFormat, '')


  /* Write results into output table */
INSERT INTO SP_Utility_DQ_OUTPUT (
	[HEALTHPLAN],
    [TABLENAME] ,
	[COLUMNNAME] ,
	[TEST_SCENARIO] ,
	[SOURCE_COUNT] ,
	[TARGET_COUNT] ,
	[STATUS],
	[STATUS_DESC],
	[DQ_REMARKS]	
	)
 VALUES ( @PlanName , @FileNM, @COLUMN_NAME , @TestScenarioDetails, @SOURCE_CNT , @TARGET_CNT, @FINAL_STATUS, @STATUS_DESCRIPTION , @DQ_REMARKS )

 
SET @i = @i + 1;

END;     -- end of While Loop for 'Null check'

END;    -- end of IF for 'Null check'

/* ----------------------------- End of NULL column scenario---------------------------------  */


/* ----------------------------- Start of Integer Format check column scenario---------------------------------  */

if @DQCheck = 'IntegerFormatCheck' 
BEGIN

/* Store Column Count in @COL_COUNT variable  */
DELETE FROM @column_table

INSERT INTO @column_table  
SELECT 
ROW_NUMBER() OVER(ORDER BY value DESC) AS ID,value FROM STRING_SPLIT(@SourceColumns, ',')

SET @COL_COUNT = (SELECT count (ID)
						FROM
						@column_table );

/* Start of While Loop which adds a row per COLUMN in output Table  */

SET @i = 1    -- resetting the counter variable

WHILE @i <= @COL_COUNT
BEGIN

SET @COLUMN_NAME = (SELECT value
						FROM
						@column_table 
						 where ID = @i);

/*  ----  SQL for Source Table ----  */

DELETE from @TempCount                 -- Clear the TempCount table 
SET @SRCTableName = NULL               -- Clear the temp variable

/* Drop output table if already existing */
SET @SRCTableName = @SourceTable + '_'+ @DQCheck + '_'+ @COLUMN_NAME
SET @sqlText = N' DROP TABLE IF EXISTS '+@SRCTableName+''

EXEC (@sqlText);  

 SET @sqlText = N'
 SELECT * INTO '+ @SRCTableName + ' FROM
 (SELECT *
  FROM '+ @SourceTable + '
  Where ' + @COLUMN_NAME + ' like ''%[^0-9]%'' ) DQTest'

EXEC (@sqlText);

/* SQL to count the mismatched records */
SET @sqlText = N' SELECT count (*) FROM '+@SRCTableName+''

DELETE from @TempCount  
INSERT INTO @TempCount
EXEC (@sqlText);

SET @SOURCE_CNT=(SELECT * FROM @TempCount);

DELETE FROM @TempCount

/*  ----  SQL for Target Table ----  */
DELETE from @TempCount                 -- Clear the TempCount table 
SET @TRGTableName = NULL               -- Clear the temp variable

/* Drop output table if already existing */
SET @TRGTableName = @TargetTable + '_'+ @DQCheck + '_'+ @COLUMN_NAME
SET @sqlText = N' DROP TABLE IF EXISTS '+@TRGTableName+''

EXEC (@sqlText);  

 SET @sqlText = N'
 SELECT * INTO '+ @TRGTableName + ' FROM
 (SELECT *
  FROM '+ @TargetTable + '
  Where ' + @COLUMN_NAME + ' like ''%[^0-9]%'' and DQ_STATUS = ''Invalid'' ) DQTest'

EXEC (@sqlText);

/* SQL to count the mismatched records */
SET @sqlText = N' SELECT count (*) FROM '+@TRGTableName+''

DELETE from @TempCount  


INSERT INTO @TempCount
EXEC (@sqlText);

SET @TARGET_CNT=(SELECT * FROM @TempCount);

DELETE FROM @TempCount

  /* Compare source and target counts and update the status accordingly */

  IF @SOURCE_CNT <> @TARGET_CNT
  SET @FINAL_STATUS = 'FAILED'
  ELSE 
  SET @FINAL_STATUS = 'PASSED'



  /* Status Description*/

  IF @SOURCE_CNT > 0 and @TARGET_CNT = 0
  SET @STATUS_DESCRIPTION = 'Table '''+@SRCTableName+''' will show mismatched records'
  ELSE IF 
  @TARGET_CNT > 0 and @SOURCE_CNT = 0
  SET @STATUS_DESCRIPTION = 'Table '''+@TRGTableName+''' will show mismatched records'
  ELSE IF 
  @TARGET_CNT > 0 and @SOURCE_CNT > 0
  SET @STATUS_DESCRIPTION = 'Table '''+@SRCTableName+''' and Table '''+@TRGTableName+''' will show mismatched records'
  ELSE
  SET @STATUS_DESCRIPTION = 'Source and target table are a complete match'

    /* DQ_REMARK Description*/

   IF @SOURCE_CNT > 0
  SET @DQ_REMARKS = 'The value of ' + @COLUMN_NAME + ' is missing'
  ELSE 
  SET @DQ_REMARKS = NULL

SET @TestScenarioDetails =  @DQCheck + coalesce('-' + @DQFormat, '')


  /* Write results into output table */
INSERT INTO SP_Utility_DQ_OUTPUT (
	[HEALTHPLAN],
    [TABLENAME] ,
	[COLUMNNAME] ,
	[TEST_SCENARIO] ,
	[SOURCE_COUNT] ,
	[TARGET_COUNT] ,
	[STATUS],
	[STATUS_DESC],
	[DQ_REMARKS]	
	)
 VALUES ( @PlanName , @FileNM, @COLUMN_NAME , @TestScenarioDetails, @SOURCE_CNT , @TARGET_CNT, @FINAL_STATUS, @STATUS_DESCRIPTION , @DQ_REMARKS )

 
SET @i = @i + 1;

END;     -- end of While Loop for 'Null check'

END;    -- end of IF for 'Null check'

/* ----------------------------- End of Integer Format check column scenario---------------------------------  */



/* ----------------------------- Start of Date format (YYYYMMDD) scenario---------------------------------  */


/* Store Column Count in @COL_COUNT variable  */

if @DQCheck = 'DateFormat'
BEGIN

DELETE FROM @column_table

INSERT INTO @column_table  
SELECT 
ROW_NUMBER() OVER(ORDER BY value DESC) AS ID,value FROM STRING_SPLIT(@SourceColumns, ',')

SET @COL_COUNT = (SELECT count (ID)
						FROM
						@column_table );

/* Start of While Loop which adds a row per COLUMN in output Table  */

SET @i = 1    -- resetting the counter variable

WHILE @i <= @COL_COUNT
BEGIN

SET @COLUMN_NAME = (SELECT value
						FROM
						@column_table 
						 where ID = @i);

/*  ----  SQL for Source Table ----  */


DELETE from @TempCount                 -- Clear the TempCount table 
SET @SRCTableName = NULL               -- Clear the temp variable

/* Drop output table if already existing */
SET @SRCTableName = @SourceTable + '_'+ @DQCheck + '_'+ @COLUMN_NAME
SET @sqlText = N' DROP TABLE IF EXISTS '+@SRCTableName+''

EXEC (@sqlText);  

/*  Condition to check if date format is YYYYMMDD  */
if @DQFormat = 'YYYYMMDD'
BEGIN
 SET @sqlText = N'
 SELECT * INTO '+ @SRCTableName + ' FROM
 (SELECT *
FROM 
(
SELECT 
FORMAT( (TRY_CONVERT ( date,' + @COLUMN_NAME +' )), ''yyyyMMdd'' ) AS CONVERTED_COLUMN, *
FROM '+ @SourceTable + '
) A
where COALESCE (A.CONVERTED_COLUMN ,NULL) <> A.' +  @COLUMN_NAME+') DQTest'
END

/*  Condition to check if date format is MM/DD/YYYY  */
if @DQFormat = 'MM/DD/YYYY'
BEGIN
 SET @sqlText = N'
 SELECT * INTO '+ @SRCTableName + ' FROM
 (SELECT *
FROM 
(
SELECT 
FORMAT( (TRY_CONVERT ( date,' + @COLUMN_NAME +' )), ''MM/dd/yyyy'' ) AS CONVERTED_COLUMN, *
FROM '+ @SourceTable + '
) A
where COALESCE (A.CONVERTED_COLUMN ,''NULL'') <> A.' +  @COLUMN_NAME+') DQTest'
END

/*  Condition to check if date format is YYYY-MM-DD  */
if @DQFormat = 'YYYY-MM-DD'
BEGIN
 SET @sqlText = N'
 SELECT * INTO '+ @SRCTableName + ' FROM
 (SELECT *
FROM 
(
SELECT 
FORMAT( (TRY_CONVERT ( date,' + @COLUMN_NAME +' )), ''yyyy-MM-dd'' ) AS CONVERTED_COLUMN, *
FROM '+ @SourceTable + '
) A
where COALESCE (A.CONVERTED_COLUMN ,''NULL'') <> A.' +  @COLUMN_NAME+') DQTest'
END


/*  Condition to check if date format is YYYY  */
if @DQFormat = 'YYYY' 
BEGIN
 SET @sqlText = N'
 SELECT * INTO '+ @SRCTableName + ' FROM
 (SELECT *
FROM 
(
SELECT 
FORMAT( (TRY_CONVERT ( date,' + @COLUMN_NAME +' )), ''yyyy'' ) AS CONVERTED_COLUMN, *
FROM '+ @SourceTable + '
) A
where COALESCE (A.CONVERTED_COLUMN ,''NULL'') <> A.' +  @COLUMN_NAME+') DQTest'
END


/*  Condition to check if date format is DDMONYYYY  */
if @DQFormat = 'DDMONYYYY'  
BEGIN
SET @sqlText = N'
 SELECT * INTO '+ @SRCTableName + ' FROM
 (SELECT *
FROM 
(
SELECT 
FORMAT( (TRY_CONVERT ( date,' + @COLUMN_NAME +' )), ''ddMMMyyy'' ) AS CONVERTED_COLUMN, *
FROM '+ @SourceTable + '
) A
where COALESCE (A.CONVERTED_COLUMN ,''NULL'') <> A.' +  @COLUMN_NAME+') DQTest'
END


EXEC (@sqlText);

/* SQL to count the mismatched records */
SET @sqlText = N' SELECT count (*) FROM '+@SRCTableName+''

DELETE from @TempCount  
INSERT INTO @TempCount
EXEC (@sqlText);

SET @SOURCE_CNT=(SELECT * FROM @TempCount);

DELETE FROM @TempCount

/*  ----  SQL for Target Table ----  */

DELETE from @TempCount                 -- Clear the TempCount table 
SET @TRGTableName = NULL               -- Clear the temp variable

/* Drop output table if already existing */
SET @TRGTableName = @TargetTable + '_'+ @DQCheck + '_'+ @COLUMN_NAME
SET @sqlText = N' DROP TABLE IF EXISTS '+@TRGTableName+''

EXEC (@sqlText);  

/*  Condition to check if date format is YYYYMMDD  */
if @DQFormat = 'YYYYMMDD'
BEGIN
 SET @sqlText = N'
 SELECT * INTO '+ @TRGTableName + ' FROM
 (SELECT *
FROM 
(
SELECT 
FORMAT( (TRY_CONVERT ( date,' + @COLUMN_NAME +' )), ''yyyyMMdd'' ) AS CONVERTED_COLUMN, *
FROM '+ @TargetTable + '
) A
where COALESCE (A.CONVERTED_COLUMN ,''NULL'') <> A.' +  @COLUMN_NAME+' and DQ_STATUS = ''Invalid'' ) DQTest'
END

/*  Condition to check if date format is MM/DD/YYYY  */
if @DQFormat = 'MM/DD/YYYY'
BEGIN
 SET @sqlText = N'
 SELECT * INTO '+ @TRGTableName + ' FROM
 (SELECT *
FROM 
(
SELECT 
FORMAT( (TRY_CONVERT ( date,' + @COLUMN_NAME +' )), ''MM/dd/yyyy'' ) AS CONVERTED_COLUMN, *
FROM '+ @TargetTable + '
) A
where COALESCE (A.CONVERTED_COLUMN ,''NULL'') <> A.' +  @COLUMN_NAME+' and DQ_STATUS = ''Invalid'' ) DQTest'
END

/*  Condition to check if date format is YYYY-MM-DD  */
if @DQFormat = 'YYYY-MM-DD'
BEGIN
 SET @sqlText = N'
 SELECT * INTO '+ @TRGTableName + ' FROM
 (SELECT *
FROM 
(
SELECT 
FORMAT( (TRY_CONVERT ( date,' + @COLUMN_NAME +' )), ''yyyy-MM-dd'' ) AS CONVERTED_COLUMN, *
FROM '+ @TargetTable + '
) A
where COALESCE (A.CONVERTED_COLUMN ,''NULL'') <> A.' +  @COLUMN_NAME+' and DQ_STATUS = ''Invalid'' ) DQTest'
END


/*  Condition to check if date format is YYYY  */
if @DQFormat = 'YYYY' 
BEGIN
 SET @sqlText = N'
 SELECT * INTO '+ @TRGTableName + ' FROM
 (SELECT *
FROM 
(
SELECT 
FORMAT( (TRY_CONVERT ( date,' + @COLUMN_NAME +' )), ''yyyy'' ) AS CONVERTED_COLUMN, *
FROM '+ @TargetTable + '
) A
where COALESCE (A.CONVERTED_COLUMN ,''NULL'') <> A.' +  @COLUMN_NAME+' and DQ_STATUS = ''Invalid'' ) DQTest'
END


/*  Condition to check if date format is DDMONYYYY  */
if @DQFormat = 'DDMONYYYY'  
BEGIN
SET @sqlText = N'
 SELECT * INTO '+ @TRGTableName + ' FROM
 (SELECT *
FROM 
(
SELECT 
FORMAT( (TRY_CONVERT ( date,' + @COLUMN_NAME +' )), ''ddMMMyyy'' ) AS CONVERTED_COLUMN, *
FROM '+ @TargetTable + '
) A
where COALESCE (A.CONVERTED_COLUMN ,''NULL'') <> A.' +  @COLUMN_NAME+' and DQ_STATUS = ''Invalid'' ) DQTest'
END


EXEC (@sqlText);

/* SQL to count the mismatched records */
SET @sqlText = N' SELECT count (*) FROM '+@TRGTableName+''

DELETE from @TempCount  
INSERT INTO @TempCount
EXEC (@sqlText);

SET @TARGET_CNT=(SELECT * FROM @TempCount);

DELETE FROM @TempCount


  /* Compare source and target counts and update the status accordingly */

  IF @SOURCE_CNT <> @TARGET_CNT
  SET @FINAL_STATUS = 'FAILED'
  ELSE 
  SET @FINAL_STATUS = 'PASSED'

  /* Status Description*/

/* Status Description*/

  IF @SOURCE_CNT > 0 and @TARGET_CNT = 0
  SET @STATUS_DESCRIPTION = 'Table '''+@SRCTableName+''' will show mismatched records'
  ELSE IF 
  @TARGET_CNT > 0 and @SOURCE_CNT = 0
  SET @STATUS_DESCRIPTION = 'Table '''+@TRGTableName+''' will show mismatched records'
  ELSE IF 
  @TARGET_CNT > 0 and @SOURCE_CNT > 0
  SET @STATUS_DESCRIPTION = 'Table '''+@SRCTableName+''' and Table '''+@TRGTableName+''' will show mismatched records'
  ELSE
  SET @STATUS_DESCRIPTION = 'Source and target table are a complete match'

    /* DQ_REMARK Description*/

   IF @SOURCE_CNT > 0
  SET @DQ_REMARKS = 'The value of ' + @COLUMN_NAME + ' is in the format other than expected '''+@DQFormat+''' format '
  ELSE 
  SET @DQ_REMARKS = NULL

SET @TestScenarioDetails =  @DQCheck + coalesce('-' + @DQFormat, '')

  /* Write results into output table */
INSERT INTO SP_Utility_DQ_OUTPUT (
	[HEALTHPLAN],
    [TABLENAME] ,
	[COLUMNNAME] ,
	[TEST_SCENARIO] ,
	[SOURCE_COUNT] ,
	[TARGET_COUNT] ,
	[STATUS],
	[STATUS_DESC],
	[DQ_REMARKS]	
	)
 VALUES ( @PlanName , @FileNM, @COLUMN_NAME , @TestScenarioDetails, @SOURCE_CNT , @TARGET_CNT, @FINAL_STATUS, @STATUS_DESCRIPTION , @DQ_REMARKS )
  
SET @i = @i + 1;

END;     -- end of While Loop for 'DateFormat'

END;     -- end of IF for 'DateFormat'


/* ----------------------------- End of Date format (YYYYMMDD) scenario---------------------------------  */

/* ----------------------------- Start of Duplicate Record Count Check scenario---------------------------------  */

if @DQCheck = 'Duplicate' 
BEGIN

/*  ----  SQL for Source Table ----  */

DELETE from @TempCount                 -- Clear the TempCount table 
SET @SRCTableName = NULL               -- Clear the temp variable

SET @SourceColumnsReplaced = REPLACE(@SourceColumns, ',', '__');     -- Replacing delimiter ',' with '_' so that valid tablename can be created

/* Drop output table if already existing */
SET @SRCTableName = @SourceTable + '_'+ @DQCheck + '_'+ @SourceColumnsReplaced
SET @sqlText = N' DROP TABLE IF EXISTS '+@SRCTableName+''

EXEC (@sqlText);  

 SET @sqlText = N'
 SELECT * INTO '+ @SRCTableName + ' FROM
 ( SELECT ' + @SourceColumns + ' , count(*) as CNT
  FROM '+ @SourceTable + '
  Group by ' + @SourceColumns + ' 
  Having Count (*) > 1 ) DQTest'

EXEC (@sqlText);

/* SQL to count the mismatched records */
SET @sqlText = N' SELECT count (*) FROM '+@SRCTableName+''

DELETE from @TempCount  
INSERT INTO @TempCount
EXEC (@sqlText);

SET @SOURCE_CNT=(SELECT * FROM @TempCount);

DELETE FROM @TempCount

/*  ----  SQL for Target Table ----  */
DELETE from @TempCount                 -- Clear the TempCount table 
SET @TRGTableName = NULL               -- Clear the temp variable

SET @TargetColumnsReplaced = REPLACE(@TargetColumns, ',', '__');      -- Replacing delimiter ',' with '_' so that valid tablename can be created

/* Drop output table if already existing */
SET @TRGTableName = @TargetTable + '_'+ @DQCheck + '_'+ @TargetColumnsReplaced
SET @sqlText = N' DROP TABLE IF EXISTS '+@TRGTableName+''

EXEC (@sqlText);  

 SET @sqlText = N'
 SELECT * INTO '+ @TRGTableName + ' FROM
 (SELECT ' + @TargetColumns + ' , count(*) as CNT
  FROM '+ @TargetTable + '
  Group by ' + @TargetColumns + ' 
  Having Count (*) > 1 ) DQTest'

EXEC (@sqlText);

/* SQL to count the mismatched records */
SET @sqlText = N' SELECT count (*) FROM '+@TRGTableName+''

DELETE from @TempCount  


INSERT INTO @TempCount
EXEC (@sqlText);

SET @TARGET_CNT=(SELECT * FROM @TempCount);

DELETE FROM @TempCount

  /* Compare source and target counts and update the status accordingly */

  IF @SOURCE_CNT > 0 or @TARGET_CNT > 0
  SET @FINAL_STATUS = 'FAILED'
  ELSE 
  SET @FINAL_STATUS = 'PASSED'

  
  /* Status Description*/

  IF @SOURCE_CNT > 0 and @TARGET_CNT = 0
  SET @STATUS_DESCRIPTION = 'Table '''+@SRCTableName+''' will show duplicate records'
  ELSE IF 
  @TARGET_CNT > 0 and @SOURCE_CNT = 0
  SET @STATUS_DESCRIPTION = 'Table '''+@TRGTableName+''' will show duplicate records'
  ELSE IF 
  @TARGET_CNT > 0 and @SOURCE_CNT > 0
  SET @STATUS_DESCRIPTION = 'Table '''+@SRCTableName+''' and Table '''+@TRGTableName+''' will show duplicate records'
  ELSE
  SET @STATUS_DESCRIPTION = 'Source and target table do not have duplicate records'

    /* DQ_REMARK Description*/

   IF @TARGET_CNT > 0 or @SOURCE_CNT > 0
  SET @DQ_REMARKS = 'The ' + @TargetColumns + ' do not create unique record in table'
  ELSE 
  SET @DQ_REMARKS = NULL

SET @TestScenarioDetails =  @DQCheck + coalesce('-' + @DQFormat, '')


  /* Write results into output table */
INSERT INTO SP_Utility_DQ_OUTPUT (
	[HEALTHPLAN],
    [TABLENAME] ,
	[COLUMNNAME] ,
	[TEST_SCENARIO] ,
	[SOURCE_COUNT] ,
	[TARGET_COUNT] ,
	[STATUS],
	[STATUS_DESC],
	[DQ_REMARKS]	
	)
 VALUES ( @PlanName , @FileNM, @COLUMN_NAME , @TestScenarioDetails, @SOURCE_CNT , @TARGET_CNT, @FINAL_STATUS, @STATUS_DESCRIPTION , @DQ_REMARKS )


END;    -- end of IF for 'Duplicate check'

/* ----------------------------- End of Duplicate Record Count Check scenario---------------------------------  */




SET @s = @s + 1;

END;  -- end of While Loop for 'TestScenario' list

/* ----------------------------- End of Code---------------------------------  */

/*SELECT [HEALTHPLAN]
      ,[TABLENAME]
	  ,[TEST_SCENARIO]
      ,[COLUMNNAME]
      ,[SOURCE_COUNT]
      ,[TARGET_COUNT]
      ,[STATUS]
      ,[STATUS_DESC]
      ,[DQ_REMARKS]
 FROM [dbo].[SP_Utility_DQ_OUTPUT]; */

END
--Ending SP to test SCM
