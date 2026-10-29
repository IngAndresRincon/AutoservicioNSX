-- Preset del cliente con identificador (iButton, teclado o placa), solo o atendido por un vendedor.
-- sincronizado usa los codigos de public.estado: 0 Registrado, 2 Confirmado, 3 Rechazado, 4 Reportado, 5 Anulado, 6 Venta Zero, 8 Despachando.
-- La clave del teclado no se guarda. Idempotente. Ejecutar sobre Autoservicio_nsx2.

CREATE TABLE IF NOT EXISTS public.preset_cliente (
    id                  integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_posicion         integer       NOT NULL,
    numero_manguera     integer       NOT NULL,
    tipo_programacion   integer       NOT NULL,
    valor               numeric(12,2) NOT NULL DEFAULT 0,
    km                  integer,
    tipo_identificador  integer       NOT NULL,
    serial              varchar(60)   NOT NULL,
    documento           varchar(40),
    id_turno_vendedor   integer REFERENCES public.turno_vendedor (id),
    id_presetnsx        integer,
    id_venta            integer,
    sincronizado        integer       NOT NULL DEFAULT 0,
    mensaje             text,
    fecha_registro      timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS ix_preset_cliente_sync ON public.preset_cliente (sincronizado) WHERE id_venta IS NULL;

CREATE OR REPLACE FUNCTION public.notify_event_preset_cliente() RETURNS trigger
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
      c.id as clientpresetid,
      c.id_posicion as positionid,
      c.numero_manguera as hosenumber,
      c.tipo_programacion as programmingtypeid,
      c.valor as value,
      c.tipo_identificador as identifiertypeid,
      c.documento as sellerdocument,
      c.id_presetnsx,
      c.id_venta as saleid,
      c.sincronizado as sync,
      c.mensaje as message
    FROM public.preset_cliente as c
    LEFT JOIN public.pantalla_posicion as pp ON pp.id_posicion = c.id_posicion
    LEFT JOIN public.pantalla as pt ON pt.id = pp.id_pantalla
    WHERE c.id = NEW.id
  ) t;

  PERFORM pg_notify('notify_event_preset_cliente', payload::text);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notify_event_preset_cliente ON public.preset_cliente;
CREATE TRIGGER notify_event_preset_cliente
    AFTER UPDATE ON public.preset_cliente
    FOR EACH ROW
    WHEN (OLD.sincronizado IS DISTINCT FROM NEW.sincronizado)
    EXECUTE FUNCTION public.notify_event_preset_cliente();
