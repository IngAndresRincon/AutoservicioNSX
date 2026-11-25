/* ============================================================================
   10 - Precios del nivel 'Autoservicio' tomados del 'Nivel 1' (idempotente)
   Para cada producto con precio activo en 'Nivel 1' y sin precio activo en 'Autoservicio', crea el mismo precio.
   No toca precios existentes. Los productos nuevos o con otro precio se ajustan a mano en NSX.
   Requiere 01_Esquema_Autoservice.sql (crea el nivel).
   ============================================================================ */
DECLARE @idAuto INT = (SELECT TOP 1 [Pk_IdNivel] FROM [dbo].[Nivel] WHERE [Nombre] = 'Autoservicio');
DECLARE @idBase INT = (SELECT TOP 1 [Pk_IdNivel] FROM [dbo].[Nivel] WHERE [Nombre] = 'Nivel 1');

-- Una fila por insert: el trigger InsertarSicronizacionPrecioIns no admite varias filas a la vez
DECLARE @producto INT, @precio NUMERIC(18, 3);
DECLARE precios CURSOR LOCAL FAST_FORWARD FOR
    SELECT b.[Fk_IdProducto], b.[Precio]
    FROM [dbo].[PrecioProducto] b
    WHERE @idAuto IS NOT NULL AND @idBase IS NOT NULL AND b.[Fk_IdNivel] = @idBase AND b.[Activo] = 1
      AND NOT EXISTS (SELECT 1 FROM [dbo].[PrecioProducto] a
                      WHERE a.[Fk_IdNivel] = @idAuto AND a.[Fk_IdProducto] = b.[Fk_IdProducto] AND a.[Activo] = 1);
OPEN precios;
FETCH NEXT FROM precios INTO @producto, @precio;
WHILE @@FETCH_STATUS = 0
BEGIN
    INSERT INTO [dbo].[PrecioProducto] ([FechaCreacion], [FechaModificacion], [Precio], [Activo], [Fk_IdProducto], [Fk_IdNivel])
    VALUES (GETDATE(), GETDATE(), @precio, 1, @producto, @idAuto);
    FETCH NEXT FROM precios INTO @producto, @precio;
END
CLOSE precios;
DEALLOCATE precios;
GO
