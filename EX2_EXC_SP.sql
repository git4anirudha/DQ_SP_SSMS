USE [QACOP]
GO

DECLARE	@return_value int

EXEC	@return_value = [dbo].[SP_Utility_DQ_TEST]

SELECT	'Return Value' = @return_value

GO
