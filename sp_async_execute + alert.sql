-- =============================================
-- Author:		Eduardo Cuomo
-- Create date: 19/12/2014
-- Update date: 19/12/2014 ECuomo & FRobles: se obtiene dinámicamente el nombre de la base de datos
-- Update date:	04/05/2015 ECuomo: Auto-Elimina Job en caso de error también
-- Update date:	04/05/2015 ECuomo: Aviso en caso de error
-- URL:			http://www.motobit.com/tips/detpg_async-execute-sql/
--				https://msdn.microsoft.com/es-AR/library/ms182079.aspx
--				https://msdn.microsoft.com/en-us/library/ms187358.aspx
--				Configurar e-Mial:
--					http://www.mssqltips.com/sqlservertip/1100/setting-up-database-mail-for-sql-2005/
--					http://www.mssqltips.com/sqlservertip/1438/sql-server-2005-database-mail-setup-and-configuration-scripts/
-- Description:	sp_async_execute - asynchronous execution of T-SQL command or stored prodecure
-- Note:		Requerido que esté corriendo el servicio SQLSERVERAGENT (SQL Server Agent) y esté configurado Database Mail
-- =============================================
ALTER PROCEDURE [dbo].[sp_async_execute]
	  @sql		NVARCHAR(MAX)
	, @jobname	VARCHAR(MAX) = NULL
AS

SET NOCOUNT ON

-- ----------------------------------------------------------------------------
-- Variables

DECLARE @id			UNIQUEIDENTIFIER
DECLARE @dbname		NVARCHAR(128) = DB_NAME()
DECLARE @ReturnCode	INT = 0

DECLARE @SpName			NVARCHAR(MAX) = N'sp_async_execute'
DECLARE @CategiryName	NVARCHAR(MAX) = N'async'
DECLARE @Operator		NVARCHAR(MAX) = N'Sistemas'
DECLARE @LoginName		NVARCHAR(MAX) = N'sa'

-- ----------------------------------------------------------------------------
-- Job Name

-- Create unique job name if the name is not specified
IF (@jobname IS NULL)
	SET @jobname = N'async'

SET @jobname = @jobname + N'_' + CONVERT(NVARCHAR(64), NEWID())

-- ----------------------------------------------------------------------------
-- Query

--/*
DECLARE @jobnameVar VARCHAR(MAX) = REPLACE(@jobname, N'''', N'''''')

SET @sql = N'
BEGIN TRANSACTION

BEGIN TRY
	' + @sql + N'
	
	COMMIT
END TRY
BEGIN CATCH
	ROLLBACK
	DECLARE @BR			NVARCHAR(2)		= CHAR(13) + CHAR(10)
	DECLARE @ES			NVARCHAR(MAX)	= CONVERT(NVARCHAR(MAX), ERROR_STATE())
	DECLARE @subject	NVARCHAR(MAX)
	DECLARE @body		NVARCHAR(MAX)
	
	SELECT
		  @subject	= N''[' + @SpName + N'] Error "' + @jobnameVar + N'" ('' + @ES + N'')''
		, @body		= N''Job Name: ' + @jobnameVar + N'''
						+ @BR + N''ErrorSeverity: '' + CONVERT(NVARCHAR(MAX), ERROR_SEVERITY())
						+ @BR + N''ErrorState: '' + @ES
						+ @BR + N''ErrorMessage: '' + ERROR_MESSAGE()
						+ @BR + N''DB Name: ' + @dbname + N'''
						+ @BR + N''Login Name: ' + @LoginName + N'''
						+ @BR
						+ @BR + N''Query:'' + @BR + N''' + REPLACE(@sql, '''', '''''') + N'''
	
	EXEC msdb.dbo.sp_send_dbmail
		  @profile_name	= N''SQLAlerts''
		, @recipients	= N''eduardo.cuomo@patagonian.it''
		, @subject		= @subject
		, @body			= @body
END CATCH
'
--*/

-- ----------------------------------------------------------------------------
-- Category

IF NOT EXISTS ( SELECT name FROM msdb.dbo.syscategories WHERE name = @CategiryName AND category_class = 1 )
	EXEC msdb.dbo.sp_add_category
		  @class	= 'JOB'
		, @type		= 'LOCAL'
		, @name		= @CategiryName

-- ----------------------------------------------------------------------------
-- Job

DECLARE @description NVARCHAR(MAX)
SELECT @description = 'Creado dinámicamente desde SP [' + @SpName + N']'

-- Create a new job, get job ID
EXECUTE msdb.dbo.sp_add_job
	  @jobname
	, @job_id						= @id OUTPUT
	, @delete_level					= 3 -- 3: Eliminar cuando termine | https://msdn.microsoft.com/es-AR/library/ms182079.aspx
	, @owner_login_name				= @LoginName
	, @notify_email_operator_name	= @Operator
	, @notify_level_email			= 2 -- 2: En caso de error | https://msdn.microsoft.com/es-AR/library/ms182079.aspx
	, @description					= @description
	, @category_name				= @CategiryName

-- Specify a job server for the job
EXECUTE msdb.dbo.sp_add_jobserver
	@job_id = @id

-- Specify a first step of the job - the SQL command
EXECUTE msdb.dbo.sp_add_jobstep
	  @job_id				= @id
	, @step_name			= 'Step 1: Run Query'
	, @command				= @sql
	, @database_name		= @dbname
	, @on_success_action	= 3 -- En caso de error, siguiente paso | https://msdn.microsoft.com/en-us/library/ms187358.aspx


-- ----------------------------------------------------------------------------
-- Start the job

execute msdb.dbo.sp_start_job
	@job_id = @id
