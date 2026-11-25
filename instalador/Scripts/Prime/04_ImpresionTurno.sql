/* ============================================================================
   04 - Recibo de turno guardado por id de turno (idempotente)
   Base: "14. Tabla Impresion Turno.sql" + "Scripts ReciboTurno BD\1_ReciboTurnoPorTurno.sql" de NSX2.
   Lo usa T2 (MixedReciboTurnoService.GuardarReciboTurno) al cerrar el turno de un islero.
   ============================================================================ */
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

IF OBJECT_ID('dbo.ImpresionTurno', 'U') IS NULL
    CREATE TABLE [dbo].[ImpresionTurno] (
        [Pk_IdImpresionTurno] INT           IDENTITY (1, 1) NOT NULL,
        [CedulaIslero]        NVARCHAR (20) NOT NULL,
        [Fk_IdPosicion]       INT           NOT NULL,
        [DatosImpresion]      NVARCHAR (MAX) NOT NULL,
        CONSTRAINT [PK_ImpresionTurno] PRIMARY KEY CLUSTERED ([Pk_IdImpresionTurno] ASC)
    );
GO

IF COL_LENGTH('dbo.ImpresionTurno', 'Fk_IdTurno') IS NULL
    ALTER TABLE [dbo].[ImpresionTurno] ADD [Fk_IdTurno] INT NULL;
GO
IF COL_LENGTH('dbo.ImpresionTurno', 'Impresion') IS NULL
    ALTER TABLE [dbo].[ImpresionTurno] ADD [Impresion] NVARCHAR(MAX) NULL;   -- recibo completo (XML de lineas con formato)
GO
IF COL_LENGTH('dbo.ImpresionTurno', 'FechaImpresion') IS NULL
    ALTER TABLE [dbo].[ImpresionTurno] ADD [FechaImpresion] DATETIME NULL;
GO

-- Recibos anteriores: el numero de turno viene dentro del texto ("Turno#:3704|").
UPDATE t
SET t.[Fk_IdTurno] = CONVERT(INT, x.Numero)
FROM [dbo].[ImpresionTurno] t
CROSS APPLY (SELECT SUBSTRING(t.[DatosImpresion] + '|', CHARINDEX('Turno#:', t.[DatosImpresion]) + 7,
        CHARINDEX('|', t.[DatosImpresion] + '|', CHARINDEX('Turno#:', t.[DatosImpresion])) - (CHARINDEX('Turno#:', t.[DatosImpresion]) + 7)) AS Numero) x
WHERE t.[Fk_IdTurno] IS NULL AND CHARINDEX('Turno#:', t.[DatosImpresion]) > 0
  AND LEN(x.Numero) BETWEEN 1 AND 9 AND PATINDEX('%[^0-9]%', x.Numero) = 0;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_ImpresionTurno_Turno' AND object_id = OBJECT_ID('dbo.ImpresionTurno'))
    CREATE INDEX [IX_ImpresionTurno_Turno] ON [dbo].[ImpresionTurno] ([Fk_IdTurno]);
GO
