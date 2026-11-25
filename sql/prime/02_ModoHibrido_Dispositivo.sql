/* ============================================================================
   02 - Modo hibrido por dispositivo (idempotente)
   ModoHibrido = 1: la pantalla deja entrar a un islero (vende por P1 con su turno) ademas del autoservicio.
   ModoHibrido = 0: autoservicio puro.
   Requiere 01_Esquema_Autoservice.sql.
   ============================================================================ */
SET QUOTED_IDENTIFIER ON;
GO

IF COL_LENGTH('Autoservice.Dispositivo', 'ModoHibrido') IS NULL
    ALTER TABLE [Autoservice].[Dispositivo]
        ADD [ModoHibrido] BIT NOT NULL CONSTRAINT [DF_Dispositivo_ModoHibrido] DEFAULT ((0));
GO
