/* ============================================================================
   01 - Esquema Autoservice para NSX Prime (idempotente: se puede correr varias veces)
   Base: "124. Modulo Autoservicio NSX2.sql" (NSX2 V 3.0.3), con estas diferencias:
     - Todo con guardas (IF NOT EXISTS), sin errores si ya existe.
     - NO inserta TipoTransaccion 22/23: en Prime Tankio = 19 y Autoservicio = 20.
     - NO inserta Nivel 'Tankio' ni TipoComunicacion 4 'Impresora56' (no los usa el autoservicio de Prime).
     - Defaults con nombre fijo (en 124 eran nombres generados).
   Ejecutar dentro de la BD de la estacion (ej: sqlcmd -d EstacionNSX -b -i este_archivo.sql).
   ============================================================================ */
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

IF SCHEMA_ID('Autoservice') IS NULL
    EXEC('CREATE SCHEMA [Autoservice]');
GO

-- Configuracion ---------------------------------------------------------------
IF OBJECT_ID('Autoservice.Configuracion', 'U') IS NULL
    CREATE TABLE [Autoservice].[Configuracion] (
        [Pk_IdConfiguracion] INT            IDENTITY (1, 1) NOT NULL,
        [Nombre]             NVARCHAR (50)  NOT NULL,
        [Descripcion]        NVARCHAR (200) NOT NULL,
        [Valor]              NVARCHAR (500) NULL,
        CONSTRAINT [PK_Configuracion] PRIMARY KEY CLUSTERED ([Pk_IdConfiguracion] ASC) WITH (FILLFACTOR = 90)
    );
GO

IF NOT EXISTS (SELECT 1 FROM [Autoservice].[Configuracion] WHERE [Nombre] = N'Bandera')
    INSERT [Autoservice].[Configuracion] ([Nombre], [Descripcion], [Valor]) VALUES (N'Bandera', N'Bandera Mayorista', N'1');
IF NOT EXISTS (SELECT 1 FROM [Autoservice].[Configuracion] WHERE [Nombre] = N'Sistema')
    INSERT [Autoservice].[Configuracion] ([Nombre], [Descripcion], [Valor]) VALUES (N'Sistema', N'Sistema de Trabajo', N'NSX');
IF NOT EXISTS (SELECT 1 FROM [Autoservice].[Configuracion] WHERE [Nombre] = N'MaxVueltos')
    INSERT [Autoservice].[Configuracion] ([Nombre], [Descripcion], [Valor]) VALUES (N'MaxVueltos', N'Valor tope Vueltos en Efectivo', N'0');
GO

-- Dispositivo (la columna ModoHibrido se agrega en 02) -------------------------
IF OBJECT_ID('Autoservice.Dispositivo', 'U') IS NULL
    CREATE TABLE [Autoservice].[Dispositivo] (
        [IdDispositivo] INT           IDENTITY (1, 1) NOT NULL,
        [Identificador] VARCHAR (100) NOT NULL,
        [IdDispensador] INT           NOT NULL,
        [Ip]            VARCHAR (50)  NULL,
        [Activo]        BIT           CONSTRAINT [DF_Dispositivo_Activo] DEFAULT ((1)) NOT NULL,
        [FechaRegistro] DATETIME      CONSTRAINT [DF_Dispositivo_FechaRegistro] DEFAULT (getdate()) NOT NULL,
        CONSTRAINT [PK_Dispositivo] PRIMARY KEY CLUSTERED ([IdDispositivo] ASC) WITH (FILLFACTOR = 90)
    );
GO

-- EstadoVueltos ---------------------------------------------------------------
IF OBJECT_ID('Autoservice.EstadoVueltos', 'U') IS NULL
    CREATE TABLE [Autoservice].[EstadoVueltos] (
        [IdEstado]    INT            IDENTITY (1, 1) NOT NULL,
        [Descripcion] NVARCHAR (200) NOT NULL,
        CONSTRAINT [PK_EstadoVuelto] PRIMARY KEY CLUSTERED ([IdEstado] ASC) WITH (FILLFACTOR = 90)
    );
GO

IF NOT EXISTS (SELECT 1 FROM [Autoservice].[EstadoVueltos])
BEGIN
    SET IDENTITY_INSERT [Autoservice].[EstadoVueltos] ON;
    INSERT [Autoservice].[EstadoVueltos] ([IdEstado], [Descripcion]) VALUES (1, N'Creado');
    INSERT [Autoservice].[EstadoVueltos] ([IdEstado], [Descripcion]) VALUES (2, N'Reservado');
    INSERT [Autoservice].[EstadoVueltos] ([IdEstado], [Descripcion]) VALUES (3, N'Usado');
    INSERT [Autoservice].[EstadoVueltos] ([IdEstado], [Descripcion]) VALUES (4, N'Vencido');
    SET IDENTITY_INSERT [Autoservice].[EstadoVueltos] OFF;
END
GO

-- Fidelidad -------------------------------------------------------------------
IF OBJECT_ID('Autoservice.Fidelidad', 'U') IS NULL
    CREATE TABLE [Autoservice].[Fidelidad] (
        [IdFidelidadAuto] INT           NOT NULL,
        [Descripcion]     NVARCHAR (50) NULL,
        [Activo]          BIT           NOT NULL,
        [FechaRegistro]   DATETIME      NOT NULL,
        CONSTRAINT [PK_FidelidadAuto] PRIMARY KEY CLUSTERED ([IdFidelidadAuto] ASC) WITH (FILLFACTOR = 90)
    );
GO

-- FormaPago (formas de pago habilitadas en el autoservicio) ---------------------
IF OBJECT_ID('Autoservice.FormaPago', 'U') IS NULL
    CREATE TABLE [Autoservice].[FormaPago] (
        [IdFormaPagoAuto] INT           NOT NULL,
        [Fk_IdFormaPago]  INT           NOT NULL,
        [Activo]          BIT           CONSTRAINT [DF_FormaPago_Activo] DEFAULT ((1)) NOT NULL,
        [Descripcion]     NVARCHAR (50) NULL,
        [FechaRegistro]   DATETIME      CONSTRAINT [DF_FormaPago_FechaRegistro] DEFAULT (getdate()) NOT NULL,
        CONSTRAINT [PK_FormaPagoAuto] PRIMARY KEY CLUSTERED ([IdFormaPagoAuto] ASC) WITH (FILLFACTOR = 90)
    );
GO

-- Recursos (videos, imagenes, colores por entidad) ------------------------------
IF OBJECT_ID('Autoservice.Recursos', 'U') IS NULL
    CREATE TABLE [Autoservice].[Recursos] (
        [IdRecurso]     INT           IDENTITY (1, 1) NOT NULL,
        [Nombre]        VARCHAR (50)  NOT NULL,
        [Tipo]          VARCHAR (50)  NOT NULL,
        [Entidad]       VARCHAR (50)  NULL,
        [IdEntidad]     INT           NULL,
        [Valor]         VARCHAR (250) NOT NULL,
        [Activo]        BIT           CONSTRAINT [DF_Recursos_Activo] DEFAULT ((1)) NOT NULL,
        [FechaRegistro] DATETIME      CONSTRAINT [DF_Recursos_FechaRegistro] DEFAULT (getdate()) NOT NULL,
        CONSTRAINT [PK_Recursos] PRIMARY KEY CLUSTERED ([IdRecurso] ASC) WITH (FILLFACTOR = 80)
    );
GO

-- Vueltos (fuera de la fase 1, se crea vacia para que el API no falle) -------------
IF OBJECT_ID('Autoservice.Vueltos', 'U') IS NULL
    CREATE TABLE [Autoservice].[Vueltos] (
        [IdVueltos]            INT           IDENTITY (1, 1) NOT NULL,
        [Codigo]               VARCHAR (100) NOT NULL,
        [Valor]                FLOAT (53)    NOT NULL,
        [IdDisPosProgramacion] INT           NOT NULL,
        [IdEstadoVuelto]       INT           NOT NULL,
        [FechaCreacion]        DATETIME      CONSTRAINT [DF_Vueltos_FechaCreacion] DEFAULT (getdate()) NOT NULL,
        [FechaUso]             DATETIME      NULL,
        [IdTurno]              INT           NULL,
        [IdDetalleFormaPago]   INT           NULL,
        [IdFormaPago]          INT           NULL,
        CONSTRAINT [PK_Vueltos] PRIMARY KEY CLUSTERED ([IdVueltos] ASC) WITH (FILLFACTOR = 80)
    );
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Vueltos_Codigo' AND object_id = OBJECT_ID('Autoservice.Vueltos'))
    CREATE UNIQUE NONCLUSTERED INDEX [IX_Vueltos_Codigo] ON [Autoservice].[Vueltos]([Codigo] ASC);
GO

-- dbo.Bandera (el API la usa para nombre y colores) -------------------------------
IF OBJECT_ID('dbo.Bandera', 'U') IS NULL
    CREATE TABLE [dbo].[Bandera] (
        [Pk_IdBandera]  INT           IDENTITY (1, 1) NOT NULL,
        [Nombre]        VARCHAR (50)  NOT NULL,
        [Nit]           NVARCHAR (50) NULL,
        [Color1]        NVARCHAR (50) NOT NULL,
        [Color2]        NVARCHAR (50) NOT NULL,
        [Color3]        NVARCHAR (50) NOT NULL,
        [Activo]        BIT           CONSTRAINT [DF_Bandera_Activo] DEFAULT ((1)) NOT NULL,
        [FechaRegistro] DATETIME      CONSTRAINT [DF_Bandera_FechaRegistro] DEFAULT (getdate()) NULL,
        CONSTRAINT [PK_Bandera] PRIMARY KEY CLUSTERED ([Pk_IdBandera] ASC) WITH (FILLFACTOR = 80)
    );
GO

-- FormaPago.DetalleTransaccion (datos de tarjeta de un pago) ----------------------
IF OBJECT_ID('FormaPago.DetalleTransaccion', 'U') IS NULL
   AND OBJECT_ID('FormaPago.DetalleFormaPago', 'U') IS NOT NULL
   AND OBJECT_ID('FormaPago.DetalleFormaPagoAutoServicio', 'U') IS NOT NULL
    CREATE TABLE [FormaPago].[DetalleTransaccion] (
        [Pk_IdDetalleTransaccion]           INT          IDENTITY (1, 1) NOT NULL,
        [Fecha]                             DATETIME     CONSTRAINT [DF_DetalleTransaccion_Fecha] DEFAULT (getdate()) NULL,
        [Fk_IdDetalleFormaPago]             INT          NULL,
        [Fk_IdDetalleFormaPagoAutoServicio] INT          NULL,
        [Franchise]                         VARCHAR (25) NULL,
        [AccountType]                       VARCHAR (25) NULL,
        [LastFourDigitsCard]                VARCHAR (25) NULL,
        [operatorType]                      VARCHAR (25) NULL,
        [Descripcion]                       VARCHAR (50) NOT NULL,
        CONSTRAINT [PK_DetalleTransaccion] PRIMARY KEY CLUSTERED ([Pk_IdDetalleTransaccion] ASC) WITH (FILLFACTOR = 80),
        CONSTRAINT [FK_DetalleTransaccion_DetalleFormaPago] FOREIGN KEY ([Fk_IdDetalleFormaPago]) REFERENCES [FormaPago].[DetalleFormaPago] ([Pk_IdDetalleFormaPago]),
        CONSTRAINT [FK_DetalleTransaccion_DetalleFormaPagoAutoservicio] FOREIGN KEY ([Fk_IdDetalleFormaPagoAutoServicio]) REFERENCES [FormaPago].[DetalleFormaPagoAutoServicio] ([Pk_IdFormaPagoAuto])
    );
GO

-- Catalogos con los ids de Prime (en una BD de Prime ya existen; solo se completan si faltan) ---
IF NOT EXISTS (SELECT 1 FROM [dbo].[TipoTransaccion] WHERE [Pk_IdTipoTransaccion] = 20)
    INSERT INTO [dbo].[TipoTransaccion] ([Pk_IdTipoTransaccion], [Nombre], [Descripcion]) VALUES (20, 'Autoservicio', 'Transaccion Autoservicio');
GO

IF NOT EXISTS (SELECT 1 FROM [dbo].[Nivel] WHERE [Nombre] = 'Autoservicio')
    INSERT INTO [dbo].[Nivel] ([Nombre], [Descripcion]) VALUES ('Autoservicio', 'Autoservicio');
GO
