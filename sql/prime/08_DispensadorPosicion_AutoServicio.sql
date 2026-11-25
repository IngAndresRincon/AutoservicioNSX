/* ============================================================================
   08 - dbo.DispensadorPosicion.AutoServicio (idempotente)
   El modelo EDMX de Prime (EstacionModel.edmx) mapea esta columna BIT NULL; sin ella falla la lectura de posiciones.
   NULL o 0 = posicion normal; 1 = posicion dedicada a autoservicio (Poll no la consulta al surtidor).
   ============================================================================ */
IF COL_LENGTH('dbo.DispensadorPosicion', 'AutoServicio') IS NULL
    ALTER TABLE [dbo].[DispensadorPosicion] ADD [AutoServicio] BIT NULL;
GO
