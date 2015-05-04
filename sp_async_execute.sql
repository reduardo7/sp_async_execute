-- =============================================
-- Author:		Eduardo Cuomo
-- Create date: 19/12/2014
-- Update date: 19/12/2014 ECuomo & FRobles: se obtiene dinámicamente el nombre de la base de datos
-- Update date:	04/05/2015 ECuomo: Auto-Elimina Job en caso de error también
-- URL:			http://www.motobit.com/tips/detpg_async-execute-sql/
--				https://msdn.microsoft.com/es-AR/library/ms182079.aspx
--				https://msdn.microsoft.com/en-us/library/ms187358.aspx
-- Description:
-- sp_async_execute - asynchronous execution of T-SQL command or stored prodecure
-- 2012 Antonin Foller, Motobit Software, www.motobit.com
-- Requerido que esté corriendo el servicio SQLSERVERAGENT (SQL Server Agent)
-- =============================================
ALTER PROCEDURE [dbo].[sp_async_execute]
	  @sql		NVARCHAR(MAX)
	, @jobname	VARCHAR(MAX) = NULL
AS

SET NOCOUNT ON

DECLARE @id		UNIQUEIDENTIFIER
DECLARE @dbname	NVARCHAR(128) = DB_NAME()

-- Create unique job name if the name is not specified
IF (@jobname IS NULL)
	SET @jobname = 'async'

set @jobname = @jobname + '_' + CONVERT(VARCHAR(64), NEWID())

-- Create a new job, get job ID
EXECUTE msdb.dbo.sp_add_job
	  @jobname
	, @delete_level		= 3 -- Eliminar cuando termine | https://msdn.microsoft.com/es-AR/library/ms182079.aspx
	, @owner_login_name	= 'sa'
	, @job_id			= @id OUTPUT

-- Specify a job server for the job
EXECUTE msdb.dbo.sp_add_jobserver
	@job_id = @id

-- Specify a first step of the job - the SQL command
EXECUTE msdb.dbo.sp_add_jobstep
	  @job_id				= @id
	, @step_name			= 'Step1'
	, @command				= @sql
	, @database_name		= @dbname
	, @on_success_action	= 3 -- En caso de error, siguiente paso | https://msdn.microsoft.com/en-us/library/ms187358.aspx

-- Start the job
execute msdb.dbo.sp_start_job
	@job_id = @id
