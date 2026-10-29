-- Mapeo nuevo del API: modo hibrido, identificadores de cliente y formas de pago del vendedor.
-- Idempotente. Ejecutar sobre Autoservicio_nsx2.

ALTER TABLE public.dispensador
    ADD COLUMN IF NOT EXISTS hibrido boolean NOT NULL DEFAULT false;

CREATE TABLE IF NOT EXISTS public.identificador_cliente (
    id                     integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_nsx_identificador   integer NOT NULL UNIQUE,
    nombre                 varchar(30) NOT NULL,
    fecha_registro         timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS public.forma_pago_vendedor (
    id                     integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_nsx_forma_pago      integer NOT NULL UNIQUE,
    nombre                 varchar(50) NOT NULL,
    fecha_registro         timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP
);
