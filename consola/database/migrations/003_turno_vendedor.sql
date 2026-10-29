-- Turno del vendedor de paso: el que NSX abre al vendedor (idTurno), para marcar sus presets y ventas.
-- Las ventas del autoservicio siguen usando venta.id_turno (historico_turno); las del vendedor usan venta.id_turno_vendedor.
-- Idempotente. Ejecutar sobre Autoservicio_nsx2.

CREATE TABLE IF NOT EXISTS public.turno_vendedor (
    id              integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    documento       varchar(40) NOT NULL,
    id_turno_nsx    integer     NOT NULL,
    id_posicion     integer     NOT NULL,
    activo          boolean     NOT NULL DEFAULT true,
    fecha_apertura  timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_cierre    timestamp without time zone
);

CREATE INDEX IF NOT EXISTS ix_turno_vendedor_activo ON public.turno_vendedor (documento, id DESC) WHERE activo;

ALTER TABLE public.preset_vendedor
    ADD COLUMN IF NOT EXISTS id_turno_vendedor integer REFERENCES public.turno_vendedor (id);

ALTER TABLE public.venta
    ADD COLUMN IF NOT EXISTS id_turno_vendedor integer REFERENCES public.turno_vendedor (id);
