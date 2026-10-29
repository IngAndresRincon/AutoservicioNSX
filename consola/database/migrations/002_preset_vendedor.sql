-- Preset del vendedor de paso (dispensadores hibridos): registro, formas de pago ancladas y aviso por Socket.IO.
-- sincronizado usa los codigos de public.estado: 0 Registrado, 2 Confirmado, 3 Rechazado, 4 Reportado, 5 Anulado, 6 Venta Zero, 8 Despachando.
-- Idempotente. Ejecutar sobre Autoservicio_nsx2.

CREATE TABLE IF NOT EXISTS public.preset_vendedor (
    id                  integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    documento           varchar(40)  NOT NULL,
    id_posicion         integer      NOT NULL,
    numero_manguera     integer      NOT NULL,
    tipo_programacion   integer      NOT NULL,
    valor               numeric(12,2) NOT NULL DEFAULT 0,
    placa               varchar(6),
    km                  integer,
    id_presetnsx        integer,
    id_venta            integer,
    sincronizado        integer      NOT NULL DEFAULT 0,
    mensaje             text,
    fecha_registro      timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS ix_preset_vendedor_sync ON public.preset_vendedor (sincronizado) WHERE id_venta IS NULL;
CREATE INDEX IF NOT EXISTS ix_preset_vendedor_documento ON public.preset_vendedor (documento, id DESC);

CREATE TABLE IF NOT EXISTS public.preset_vendedor_pago (
    id                  integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_preset_vendedor  integer      NOT NULL REFERENCES public.preset_vendedor (id),
    id_venta            integer      NOT NULL,
    id_nsx_forma_pago   integer      NOT NULL,
    valor               numeric(12,2) NOT NULL,
    identificador       varchar(60),
    fecha_registro      timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE OR REPLACE FUNCTION public.notify_event_preset_vendedor() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  payload JSON;
BEGIN
  SELECT row_to_json(t)
  INTO payload
  FROM (
    SELECT
      pt.serial,
      v.id as sellerpresetid,
      v.documento as document,
      v.id_posicion as positionid,
      v.numero_manguera as hosenumber,
      v.tipo_programacion as programmingtypeid,
      v.valor as value,
      v.id_presetnsx,
      v.id_venta as saleid,
      v.sincronizado as sync,
      v.mensaje as message
    FROM public.preset_vendedor as v
    LEFT JOIN public.pantalla_posicion as pp ON pp.id_posicion = v.id_posicion
    LEFT JOIN public.pantalla as pt ON pt.id = pp.id_pantalla
    WHERE v.id = NEW.id
  ) t;

  PERFORM pg_notify('notify_event_preset_vendedor', payload::text);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notify_event_preset_vendedor ON public.preset_vendedor;
CREATE TRIGGER notify_event_preset_vendedor
    AFTER UPDATE ON public.preset_vendedor
    FOR EACH ROW
    WHEN (OLD.sincronizado IS DISTINCT FROM NEW.sincronizado)
    EXECUTE FUNCTION public.notify_event_preset_vendedor();
