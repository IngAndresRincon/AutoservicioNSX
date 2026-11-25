/* ============================================================================
   13 - dbo.MUXConfiguracion (idempotente)
   Configuracion del MUX que se envia por trama (comando D2) desde Administrador > Opciones > Config MUX.
   Igual a NSX2 de Teams: 17 filas. El orden de Pk_IdConfiguracion es el orden en que la ventana y la trama las leen,
   no cambiarlo. Las filas 1-3 son tiempos de 3 digitos ("000"-"999"): Tiempo Preset, Tiempo inicio Contingencia y
   Tiempo lectura identificador (en NSX2 viejo se llamaban Umbral / CopiasEfectivo / CopiasCredito).
   Fila 17 = Contingencia (1 activa / 0 inactiva). El Id de estacion no va aqui: se toma de ConfiguracionEstacion.
   ============================================================================ */
IF OBJECT_ID('dbo.MUXConfiguracion', 'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[MUXConfiguracion](
        [Pk_IdConfiguracion] [int] NOT NULL,
        [Nombre] [nvarchar](50) NOT NULL,
        [Valor] [nvarchar](50) NOT NULL,
        CONSTRAINT [PK_MUXConfiguracion] PRIMARY KEY CLUSTERED ([Pk_IdConfiguracion] ASC)
    );
END
GO

INSERT INTO [dbo].[MUXConfiguracion] ([Pk_IdConfiguracion], [Nombre], [Valor])
SELECT v.Id, v.Nombre, v.Valor
FROM (VALUES
    (1,  N'Umbral',              N'000'),
    (2,  N'CopiasEfectivo',      N'000'),
    (3,  N'CopiasCredito',       N'000'),
    (4,  N'ModoTrabajo',         N'0'),
    (5,  N'PuertoImpresora1',    N'1'),
    (6,  N'PuertoImpresora2',    N'1'),
    (7,  N'PuertoTag1',          N'1'),
    (8,  N'PuertoTag2',          N'1'),
    (9,  N'BandaMagnetica1',     N'1'),
    (10, N'BandaMagnetica2',     N'1'),
    (11, N'LectorCodigoBarras1', N'1'),
    (12, N'LectorCodigoBarras2', N'1'),
    (13, N'RFID1',               N'1'),
    (14, N'RFID2',               N'2'),
    (15, N'PuertoIbutton1',      N'1'),
    (16, N'PuertoIbutton2',      N'2'),
    (17, N'Contingencia',        N'0')
) AS v(Id, Nombre, Valor)
WHERE NOT EXISTS (SELECT 1 FROM [dbo].[MUXConfiguracion] m WHERE m.[Pk_IdConfiguracion] = v.Id);
GO

/* Si la tabla ya existia con los valores de NSX2 viejo (1 digito), la trama necesita 3 digitos en las filas 1-3. */
UPDATE [dbo].[MUXConfiguracion]
SET [Valor] = RIGHT(N'000' + [Valor], 3)
WHERE [Pk_IdConfiguracion] IN (1, 2, 3) AND LEN([Valor]) < 3 AND [Valor] NOT LIKE N'%[^0-9]%';
GO
