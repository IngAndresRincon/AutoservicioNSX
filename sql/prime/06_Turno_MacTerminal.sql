/* ============================================================================
   06 - Turnos.Turno.MacTerminal: ancho suficiente para una MAC (idempotente)
   Problema: en algunas BD la columna es nchar(10) (otras, nchar(20) o varchar(500)). Una MAC tiene 12 caracteres:
   abrir un turno desde un dispositivo de autoservicio (T1) falla al guardar con
   "Los datos de cadena o binarios se truncarian" (error 8152).
   Se deja en varchar(20) NULL (sin relleno de espacios, a diferencia de nchar).
   Solo se ensancha: si la columna ya admite 20 caracteres o mas (nchar(20), varchar(500), ...) no se toca.
   Si la columna no existe, se crea.
   Probado en EstacionNSX dentro de una transaccion revertida: el ALTER y el insert de una MAC de 12 caracteres funcionan.
   No hay indices, columnas calculadas ni objetos con schemabinding que dependan de la columna.
   ============================================================================ */
IF COL_LENGTH('Turnos.Turno', 'MacTerminal') IS NULL
    ALTER TABLE [Turnos].[Turno] ADD [MacTerminal] VARCHAR(20) NULL;
GO

IF EXISTS (SELECT 1
           FROM sys.columns c
           JOIN sys.types t ON t.user_type_id = c.user_type_id
           WHERE c.object_id = OBJECT_ID('Turnos.Turno') AND c.name = 'MacTerminal'
             AND CASE WHEN t.name LIKE 'n%' THEN c.max_length / 2 ELSE c.max_length END < 20)
    ALTER TABLE [Turnos].[Turno] ALTER COLUMN [MacTerminal] VARCHAR(20) NULL;
GO
