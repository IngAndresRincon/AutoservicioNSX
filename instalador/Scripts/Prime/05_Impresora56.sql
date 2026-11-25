/* ============================================================================
   05 - Tipo de comunicacion "Impresora56" (impresoras de red de 56 mm) (idempotente)
   Base: "125. Impresora 56mm Configuracion Poll Conexion.sql" de NSX2 (solo la parte del tipo de comunicacion).
   Al crear el lazo de comunicacion de una impresora de red de 56 mm se escoge este tipo (id 4):
   NSX imprime con la fuente B y la tabla de caracteres CP437, y el QR a 352 puntos.
   NO incluye la config PollImpresora (id 68): el chequeo de conexion de impresoras de NSX2 no esta portado.
   ============================================================================ */
IF NOT EXISTS (SELECT 1 FROM [dbo].[TipoComunicacion] WHERE [Pk_IdTipoComunicacion] = 4)
    INSERT INTO [dbo].[TipoComunicacion] ([Pk_IdTipoComunicacion], [Descripcion]) VALUES (4, 'Impresora56');
GO
