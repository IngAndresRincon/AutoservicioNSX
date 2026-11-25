/* ============================================================================
   07 - Formas de pago habilitadas para el vendedor (idempotente)
   Una fila por forma de pago de NSX; Activo = 1 la ofrece el vendedor al anclar pagos a su venta.
   Es independiente de Autoservice.FormaPago, que son las casillas de la pantalla del cliente.
   Solo se llena si esta vacia: todas las formas activas de NSX quedan habilitadas, menos la
   redencion de Commodo (solo ancla el pago, no redime puntos). Se administra desde la pagina de administracion.
   Requiere 01_Esquema_Autoservice.sql.
   ============================================================================ */
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID('Autoservice.FormaPagoVendedor', 'U') IS NULL
    CREATE TABLE [Autoservice].[FormaPagoVendedor] (
        [Fk_IdFormaPago] INT      NOT NULL,
        [Activo]         BIT      CONSTRAINT [DF_FormaPagoVendedor_Activo] DEFAULT ((0)) NOT NULL,
        [FechaRegistro]  DATETIME CONSTRAINT [DF_FormaPagoVendedor_FechaRegistro] DEFAULT (getdate()) NOT NULL,
        CONSTRAINT [PK_FormaPagoVendedor] PRIMARY KEY CLUSTERED ([Fk_IdFormaPago] ASC),
        CONSTRAINT [FK_FormaPagoVendedor_FormaPago] FOREIGN KEY ([Fk_IdFormaPago]) REFERENCES [FormaPago].[FormaPago] ([Pk_IdFormaPago])
    );
GO

IF NOT EXISTS (SELECT 1 FROM [Autoservice].[FormaPagoVendedor])
    INSERT INTO [Autoservice].[FormaPagoVendedor] ([Fk_IdFormaPago], [Activo])
    SELECT [Pk_IdFormaPago], CASE WHEN [NombreFormaPago] = 'COMMODO' THEN 0 ELSE 1 END
    FROM [FormaPago].[FormaPago]
    WHERE [Activo] = 1;
GO
