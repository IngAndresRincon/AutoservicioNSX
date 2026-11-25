/* ============================================================================
   12 - Fidelidad.VentaFidelizada.Fk_IdFidelidad (idempotente)
   El API del autoservicio lee de que programa de fidelidad es la acumulacion de una venta (1 PuntosColombia, 2 ViveTerpel,
   3 Commodo, 4 Local, 5 Leal). La base de Prime no trae la columna y sin ella falla la consulta del estado/venta.
   NULL = programa desconocido. Prime no la escribe.
   ============================================================================ */
IF COL_LENGTH('Fidelidad.VentaFidelizada', 'Fk_IdFidelidad') IS NULL
    ALTER TABLE [Fidelidad].[VentaFidelizada] ADD [Fk_IdFidelidad] INT NULL;
GO
