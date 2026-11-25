/* ============================================================================
   11 - Formas de pago por defecto del autoservicio: Datafono, Nequi y QRVueltos (idempotente)
   Crea las tres en FormaPago.FormaPago si no existen (QRVueltos debe llamarse exactamente asi: el API la reconoce por el nombre)
   y las habilita en Autoservice.FormaPago en los espacios fijos 1 = Datafono, 2 = Nequi, 3 = QRVueltos.
   Si el espacio ya existe no se toca (el admin puede cambiarlo). Requiere 01_Esquema_Autoservice.sql.
   ============================================================================ */
IF NOT EXISTS (SELECT 1 FROM [FormaPago].[FormaPago] WHERE [NombreFormaPago] = 'Datafono')
    INSERT INTO [FormaPago].[FormaPago] ([NombreFormaPago], [Descripcion], [Activo]) VALUES ('Datafono', 'DATAFONO', 1);
IF NOT EXISTS (SELECT 1 FROM [FormaPago].[FormaPago] WHERE [NombreFormaPago] = 'Nequi')
    INSERT INTO [FormaPago].[FormaPago] ([NombreFormaPago], [Descripcion], [Activo]) VALUES ('Nequi', 'Nequi', 1);
IF NOT EXISTS (SELECT 1 FROM [FormaPago].[FormaPago] WHERE [NombreFormaPago] = 'QRVueltos')
    INSERT INTO [FormaPago].[FormaPago] ([NombreFormaPago], [Descripcion], [Activo]) VALUES ('QRVueltos', 'QRVueltos', 1);
GO

DECLARE @slots TABLE ([Slot] INT, [Nombre] VARCHAR(50), [Descripcion] NVARCHAR(100));
INSERT INTO @slots VALUES (1, 'Datafono', N'DATAFONO'), (2, 'Nequi', N'Nequi'), (3, 'QRVueltos', N'QRVueltos');

INSERT INTO [Autoservice].[FormaPago] ([IdFormaPagoAuto], [Fk_IdFormaPago], [Activo], [Descripcion])
SELECT s.[Slot], fp.[Pk_IdFormaPago], 1, s.[Descripcion]
FROM @slots s
CROSS APPLY (SELECT TOP 1 [Pk_IdFormaPago] FROM [FormaPago].[FormaPago] WHERE [NombreFormaPago] = s.[Nombre] ORDER BY [Pk_IdFormaPago]) fp
WHERE NOT EXISTS (SELECT 1 FROM [Autoservice].[FormaPago] a WHERE a.[IdFormaPagoAuto] = s.[Slot]);
GO
