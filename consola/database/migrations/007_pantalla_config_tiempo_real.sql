-- Configuracion por pantalla del tiempo real (valor y avance mientras surte). Va por serial: la tabla pantalla se recrea en cada sincronizacion
CREATE TABLE IF NOT EXISTS public.pantalla_config (
    serial       text PRIMARY KEY,
    tiempo_real  boolean NOT NULL DEFAULT false,
    intervalo_ms integer NOT NULL DEFAULT 500 CHECK (intervalo_ms BETWEEN 200 AND 5000),
    estilo       varchar(20) NOT NULL DEFAULT 'carrito'
);
