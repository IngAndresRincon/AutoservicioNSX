/* 14 - Opciones de pantalla: identificadores de cliente y tiempo real (idempotente). Requiere 01. */
SET QUOTED_IDENTIFIER ON
GO

-- Identificadores de cliente que ofrece la pantalla: iButton|Teclado|Placa
IF OBJECT_ID('[Autoservice].[Dispositivo]', 'U') IS NOT NULL AND COL_LENGTH('Autoservice.Dispositivo', 'IdentificadoresCliente') IS NULL
    ALTER TABLE [Autoservice].[Dispositivo]
        ADD [IdentificadoresCliente] VARCHAR(20) NOT NULL CONSTRAINT [DF_Dispositivo_IdentificadoresCliente] DEFAULT ('1|1|1')
GO

-- Tiempo real mientras surte y cada cuanto consulta la pantalla (ms)
IF OBJECT_ID('[Autoservice].[Dispositivo]', 'U') IS NOT NULL AND COL_LENGTH('Autoservice.Dispositivo', 'TiempoReal') IS NULL
    ALTER TABLE [Autoservice].[Dispositivo]
        ADD [TiempoReal] BIT NOT NULL CONSTRAINT [DF_Dispositivo_TiempoReal] DEFAULT ((0))
GO
IF OBJECT_ID('[Autoservice].[Dispositivo]', 'U') IS NOT NULL AND COL_LENGTH('Autoservice.Dispositivo', 'IntervaloTiempoReal') IS NULL
    ALTER TABLE [Autoservice].[Dispositivo]
        ADD [IntervaloTiempoReal] INT NOT NULL CONSTRAINT [DF_Dispositivo_IntervaloTiempoReal] DEFAULT ((500))
GO

