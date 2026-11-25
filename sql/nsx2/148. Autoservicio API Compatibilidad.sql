/* Compatibilidad del API de autoservicio con NSX2 (re-ejecutable). Equivale a los scripts 02, 07, 09, 10, 11 y 12 de Prime */
SET QUOTED_IDENTIFIER ON
GO

-- Modo hibrido por dispositivo: 1 = ademas del autoservicio deja entrar a un islero
IF OBJECT_ID('[Autoservice].[Dispositivo]', 'U') IS NOT NULL AND COL_LENGTH('Autoservice.Dispositivo', 'ModoHibrido') IS NULL
    ALTER TABLE [Autoservice].[Dispositivo]
        ADD [ModoHibrido] BIT NOT NULL CONSTRAINT [DF_Dispositivo_ModoHibrido] DEFAULT ((0))
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

-- Formas de pago habilitadas para el vendedor (independiente de Autoservice.FormaPago)
IF OBJECT_ID('[Autoservice].[FormaPagoVendedor]', 'U') IS NULL
    CREATE TABLE [Autoservice].[FormaPagoVendedor] (
        [Fk_IdFormaPago] INT      NOT NULL,
        [Activo]         BIT      CONSTRAINT [DF_FormaPagoVendedor_Activo] DEFAULT ((0)) NOT NULL,
        [FechaRegistro]  DATETIME CONSTRAINT [DF_FormaPagoVendedor_FechaRegistro] DEFAULT (getdate()) NOT NULL,
        CONSTRAINT [PK_FormaPagoVendedor] PRIMARY KEY CLUSTERED ([Fk_IdFormaPago] ASC),
        CONSTRAINT [FK_FormaPagoVendedor_FormaPago] FOREIGN KEY ([Fk_IdFormaPago]) REFERENCES [FormaPago].[FormaPago] ([Pk_IdFormaPago])
    )
GO

-- Formas de pago por defecto del autoservicio: Datafono, Nequi y QRVueltos (el API reconoce QRVueltos por nombre)
IF NOT EXISTS (SELECT 1 FROM [FormaPago].[FormaPago] WHERE [NombreFormaPago] = 'Datafono')
    INSERT INTO [FormaPago].[FormaPago] ([NombreFormaPago], [Descripcion], [Activo]) VALUES ('Datafono', 'DATAFONO', 1)
IF NOT EXISTS (SELECT 1 FROM [FormaPago].[FormaPago] WHERE [NombreFormaPago] = 'Nequi')
    INSERT INTO [FormaPago].[FormaPago] ([NombreFormaPago], [Descripcion], [Activo]) VALUES ('Nequi', 'Nequi', 1)
IF NOT EXISTS (SELECT 1 FROM [FormaPago].[FormaPago] WHERE [NombreFormaPago] = 'QRVueltos')
    INSERT INTO [FormaPago].[FormaPago] ([NombreFormaPago], [Descripcion], [Activo]) VALUES ('QRVueltos', 'QRVueltos', 1)
GO

DECLARE @slots TABLE ([Slot] INT, [Nombre] VARCHAR(50), [Descripcion] NVARCHAR(100))
INSERT INTO @slots VALUES (1, 'Datafono', N'DATAFONO'), (2, 'Nequi', N'Nequi'), (3, 'QRVueltos', N'QRVueltos')

INSERT INTO [Autoservice].[FormaPago] ([IdFormaPagoAuto], [Fk_IdFormaPago], [Activo], [Descripcion])
SELECT s.[Slot], fp.[Pk_IdFormaPago], 1, s.[Descripcion]
FROM @slots s
CROSS APPLY (SELECT TOP 1 [Pk_IdFormaPago] FROM [FormaPago].[FormaPago] WHERE [NombreFormaPago] = s.[Nombre] ORDER BY [Pk_IdFormaPago]) fp
WHERE NOT EXISTS (SELECT 1 FROM [Autoservice].[FormaPago] a WHERE a.[IdFormaPagoAuto] = s.[Slot])
GO

-- Vendedor: todas las formas activas, menos COMMODO (solo ancla el pago); solo si la tabla esta vacia
IF NOT EXISTS (SELECT 1 FROM [Autoservice].[FormaPagoVendedor])
    INSERT INTO [Autoservice].[FormaPagoVendedor] ([Fk_IdFormaPago], [Activo])
    SELECT [Pk_IdFormaPago], CASE WHEN [NombreFormaPago] = 'COMMODO' THEN 0 ELSE 1 END
    FROM [FormaPago].[FormaPago]
    WHERE [Activo] = 1
GO

-- IPNsxAPI con formato 'ip|puerto' (puerto de comandos 8010). El valor de fabrica 192.168.1.1 es solo un marcador
IF EXISTS (SELECT 1 FROM [dbo].[Configuracion] WHERE [Nombre] = 'IPNsxAPI')
    UPDATE [dbo].[Configuracion]
    SET [Valor] = CASE WHEN LTRIM(RTRIM(ISNULL([Valor], ''))) IN ('', '192.168.1.1') THEN '127.0.0.1|8010'
                       ELSE LTRIM(RTRIM([Valor])) + '|8010' END,
        [Descripcion] = 'IP y puerto de NSX para el API del autoservicio (ip|puerto)'
    WHERE [Nombre] = 'IPNsxAPI' AND ISNULL([Valor], '') NOT LIKE '%|%'
ELSE
    INSERT INTO [dbo].[Configuracion] ([Pk_IdConfiguracion], [Nombre], [Descripcion], [Valor], [TipoDato])
    SELECT ISNULL(MAX([Pk_IdConfiguracion]), 0) + 1, 'IPNsxAPI', 'IP y puerto de NSX para el API del autoservicio (ip|puerto)', '127.0.0.1|8010', 'string'
    FROM [dbo].[Configuracion]
GO

-- Precios del nivel 'Autoservicio' tomados del 'Nivel 1' (una fila por insert: el trigger de precios no admite varias)
DECLARE @idAuto INT = (SELECT TOP 1 [Pk_IdNivel] FROM [dbo].[Nivel] WHERE [Nombre] = 'Autoservicio')
DECLARE @idBase INT = (SELECT TOP 1 [Pk_IdNivel] FROM [dbo].[Nivel] WHERE [Nombre] = 'Nivel 1')
DECLARE @producto INT, @precio NUMERIC(18, 3)
DECLARE precios CURSOR LOCAL FAST_FORWARD FOR
    SELECT b.[Fk_IdProducto], b.[Precio]
    FROM [dbo].[PrecioProducto] b
    WHERE @idAuto IS NOT NULL AND @idBase IS NOT NULL AND b.[Fk_IdNivel] = @idBase AND b.[Activo] = 1
      AND NOT EXISTS (SELECT 1 FROM [dbo].[PrecioProducto] a
                      WHERE a.[Fk_IdNivel] = @idAuto AND a.[Fk_IdProducto] = b.[Fk_IdProducto] AND a.[Activo] = 1)
OPEN precios
FETCH NEXT FROM precios INTO @producto, @precio
WHILE @@FETCH_STATUS = 0
BEGIN
    INSERT INTO [dbo].[PrecioProducto] ([FechaCreacion], [FechaModificacion], [Precio], [Activo], [Fk_IdProducto], [Fk_IdNivel])
    VALUES (GETDATE(), GETDATE(), @precio, 1, @producto, @idAuto)
    FETCH NEXT FROM precios INTO @producto, @precio
END
CLOSE precios
DEALLOCATE precios
GO

-- Programa de fidelidad de la venta acumulada (1 PuntosColombia, 2 ViveTerpel, 3 Commodo, 4 Local, 5 Leal); NULL = desconocido
IF OBJECT_ID('[Fidelidad].[VentaFidelizada]', 'U') IS NOT NULL AND COL_LENGTH('Fidelidad.VentaFidelizada', 'Fk_IdFidelidad') IS NULL
    ALTER TABLE [Fidelidad].[VentaFidelizada] ADD [Fk_IdFidelidad] INT NULL
GO
