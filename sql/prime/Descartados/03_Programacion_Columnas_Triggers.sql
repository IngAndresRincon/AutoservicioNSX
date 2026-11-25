/* ============================================================================
   03 - Columnas de la programacion de autoservicio y sus triggers de historico (idempotente)
   Base: scripts 15 (MacTerminal), 16 (TelefonoCliente) y 96 (IdIsleroAux) de NSX2.
   - AutorizarAutoservicio (PAS) escribe MacTerminal y TelefonoCliente en la programacion.
   - Los triggers copian estas columnas al historico. Se reescriben a partir de la definicion actual de Prime.
   Nota: Turnos.Turno.MacTerminal ya existe en Prime.
   ============================================================================ */
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

IF COL_LENGTH('dbo.DispensadorPosicionProgramacion', 'MacTerminal') IS NULL
    ALTER TABLE [dbo].[DispensadorPosicionProgramacion] ADD [MacTerminal] VARCHAR(500) NULL;
IF COL_LENGTH('dbo.DispensadorPosicionProgramacion', 'TelefonoCliente') IS NULL
    ALTER TABLE [dbo].[DispensadorPosicionProgramacion] ADD [TelefonoCliente] VARCHAR(20) NULL;
IF COL_LENGTH('dbo.DispensadorPosicionProgramacion', 'IdIsleroAux') IS NULL
    ALTER TABLE [dbo].[DispensadorPosicionProgramacion] ADD [IdIsleroAux] INT NULL;
GO

IF COL_LENGTH('Historico.HistoricoDispensadorPosicionProgramacion', 'MacTerminal') IS NULL
    ALTER TABLE [Historico].[HistoricoDispensadorPosicionProgramacion] ADD [MacTerminal] VARCHAR(500) NULL;
IF COL_LENGTH('Historico.HistoricoDispensadorPosicionProgramacion', 'TelefonoCliente') IS NULL
    ALTER TABLE [Historico].[HistoricoDispensadorPosicionProgramacion] ADD [TelefonoCliente] VARCHAR(20) NULL;
IF COL_LENGTH('Historico.HistoricoDispensadorPosicionProgramacion', 'IdIsleroAux') IS NULL
    ALTER TABLE [Historico].[HistoricoDispensadorPosicionProgramacion] ADD [IdIsleroAux] INT NULL;
GO

-- Trigger de insercion: ALTER dentro de EXEC para que solo corra si el trigger existe ------------------
IF OBJECT_ID('dbo.InsertarProgramacion', 'TR') IS NOT NULL
EXEC('
ALTER TRIGGER [dbo].[InsertarProgramacion]
   ON  [dbo].[DispensadorPosicionProgramacion]
   AFTER Insert
AS
BEGIN
	INSERT INTO [EstacionNSX].[Historico].[HistoricoDispensadorPosicionProgramacion]
           ([Pk_IdDispensadorPosicionEstado]
           ,[Guid]
           ,[FechaInicial]
           ,[DineroInicial]
           ,[VolumenInicial]
           ,[ValorProgramado]
           ,[ValorDispensado]
           ,[GradoVerificacion]
           ,[Placa]
           ,[Kilometraje]
           ,[IdentificadorWeb]
           ,[Fk_IdPosicion]
           ,[Fk_IdIsla]
           ,[Fk_IdProducto]
           ,[Fk_IdTipoTransaccion]
           ,[Fk_IdPosicionGrado]
           ,[Fk_IdIdentificador]
           ,[Fk_IdCuenta]
           ,[Fk_IdTipoProgramacion]
           ,[Fk_IdNivel]
           ,[Fk_IdVenta]
           ,[Fk_IdTurno]
           ,[Fk_IdPrecioProducto]
           ,[Fk_IdEstadoProgramacion]
           ,[Fk_IdCorte]
           ,[Fk_IdTipoSistema]
           ,[NombreCliente]
           ,[NombreEfectivo]
           ,[InfoExtra]
           ,[MacTerminal]
           ,[TelefonoCliente]
           ,[IdIsleroAux])
     VALUES
           ((select [Pk_IdDispensadorPosicionEstado] from inserted)
           ,(select [Guid] from inserted)
           ,(select [FechaInicial] from inserted)
           ,(select [DineroInicial] from inserted)
           ,(select [VolumenInicial] from inserted)
           ,(select [ValorProgramado] from inserted)
           ,(select [ValorDispensado] from inserted)
           ,(select [GradoVerificacion] from inserted)
           ,(select [Placa] from inserted)
           ,(select [Kilometraje] from inserted)
           ,(select [IdentificadorWeb] from inserted)
           ,(select [Fk_IdPosicion] from inserted)
           ,(select [Fk_IdIsla] from inserted)
           ,(select [Fk_IdProducto] from inserted)
           ,(select [Fk_IdTipoTransaccion] from inserted)
           ,(select [Fk_IdPosicionGrado] from inserted)
           ,(select [Fk_IdIdentificador] from inserted)
           ,(select [Fk_IdCuenta] from inserted)
           ,(select [Fk_IdTipoProgramacion] from inserted)
           ,(select [Fk_IdNivel] from inserted)
           ,(select [Fk_IdVenta] from inserted)
           ,(select [Fk_IdTurno] from inserted)
           ,(select [Fk_IdPrecioProducto] from inserted)
           ,(select [Fk_IdEstadoProgramacion] from inserted)
           ,(select [Fk_IdCorte] from inserted)
           ,(select [Fk_IdTipoSistema] from inserted)
           ,(select [NombreCliente] from inserted)
           ,(select [NombreEfectivo] from inserted)
           ,(select [InfoExtra] from inserted)
           ,(select [MacTerminal] from inserted)
           ,(select [TelefonoCliente] from inserted)
           ,(select [IdIsleroAux] from inserted))

	/*
		- Deja en la base de datos los ultimos 10000 registros de programaciones que fueron anuladas.
		- Las registros relacionados con las ventas se eliminan en el trigger de venta de forma CASCADA.
	*/
	delete from dbo.DispensadorPosicionProgramacion where Pk_IdDispensadorPosicionEstado <
	(select Max(Pk_IdDispensadorPosicionEstado) - 10000 from dbo.DispensadorPosicionProgramacion)
	and Fk_IdEstadoProgramacion = 3
END
');
GO

-- Trigger de actualizacion ------------------------------------------------------------------------------
IF OBJECT_ID('dbo.ActualizarProgramacion', 'TR') IS NOT NULL
EXEC('
ALTER TRIGGER [dbo].[ActualizarProgramacion]
   ON  [dbo].[DispensadorPosicionProgramacion]
   AFTER UPDATE
AS
BEGIN

	UPDATE [Historico].[HistoricoDispensadorPosicionProgramacion]
   SET [Guid]				= (select [Guid] from inserted)
      ,[FechaInicial]		= (select [FechaInicial] from inserted)
      ,[DineroInicial]		= (select [DineroInicial] from inserted)
      ,[VolumenInicial]		= (select [VolumenInicial] from inserted)
      ,[ValorProgramado]	= (select [ValorProgramado] from inserted)
      ,[ValorDispensado]	= (select [ValorDispensado] from inserted)
      ,[GradoVerificacion]	= (select [GradoVerificacion] from inserted)
      ,[Placa]				= (select [Placa] from inserted)
      ,[Kilometraje]		= (select [Kilometraje] from inserted)
      ,[IdentificadorWeb]  	= (select [IdentificadorWeb] from inserted)
      ,[Fk_IdPosicion]		= (select [Fk_IdPosicion] from inserted)
      ,[Fk_IdIsla]			= (select [Fk_IdIsla] from inserted)
      ,[Fk_IdProducto]			= (select [Fk_IdProducto] from inserted)
      ,[Fk_IdTipoTransaccion]	= (select [Fk_IdTipoTransaccion] from inserted)
      ,[Fk_IdPosicionGrado]		= (select [Fk_IdPosicionGrado] from inserted)
      ,[Fk_IdIdentificador]		= (select [Fk_IdIdentificador] from inserted)
      ,[Fk_IdCuenta]			= (select [Fk_IdCuenta] from inserted)
      ,[Fk_IdTipoProgramacion]	= (select [Fk_IdTipoProgramacion] from inserted)
      ,[Fk_IdNivel]				= (select [Fk_IdNivel] from inserted)
      ,[Fk_IdVenta]				= (select [Fk_IdVenta] from inserted)
      ,[Fk_IdTurno]				= (select [Fk_IdTurno] from inserted)
      ,[Fk_IdPrecioProducto]		= (select [Fk_IdPrecioProducto] from inserted)
      ,[Fk_IdEstadoProgramacion]	= (select [Fk_IdEstadoProgramacion] from inserted)
      ,[Fk_IdCorte]					= (select [Fk_IdCorte] from inserted)
      ,[Fk_IdTipoSistema]	    	= (select [Fk_IdTipoSistema] from inserted)
      ,[NombreCliente]	    	= (select [NombreCliente] from inserted)
      ,[NombreEfectivo]	    	= (select [NombreEfectivo] from inserted)
      ,[InfoExtra]	    	= (select [InfoExtra] from inserted)
      ,[MacTerminal]	    	= (select [MacTerminal] from inserted)
      ,[TelefonoCliente]	    	= (select [TelefonoCliente] from inserted)
      ,[IdIsleroAux]	    	= (select [IdIsleroAux] from inserted)
	WHERE [Pk_IdDispensadorPosicionEstado] = (select [Pk_IdDispensadorPosicionEstado] from inserted)

	/*
		- Deja en la base de datos los ultimos 10000 registros de programaciones que fueron anuladas.
		- Las registros relacionados con las ventas se eliminan en el trigger de venta de forma CASCADA.
	*/
	delete from dbo.DispensadorPosicionProgramacion where Pk_IdDispensadorPosicionEstado <
		(select Max(Pk_IdDispensadorPosicionEstado) - 10000 from dbo.DispensadorPosicionProgramacion)
		and Fk_IdEstadoProgramacion = 3
END
');
GO
