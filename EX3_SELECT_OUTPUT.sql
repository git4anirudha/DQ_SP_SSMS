USE [QACOP]

GO

SELECT [HEALTHPLAN]
      ,[TABLENAME]
      ,[TEST_SCENARIO]
      ,[COLUMNNAME]
      ,[SOURCE_COUNT]
      ,[TARGET_COUNT]
      ,[STATUS]
      ,[STATUS_DESC]
      ,[DQ_REMARKS]
 FROM [dbo].[SP_Utility_DQ_OUTPUT];

GO