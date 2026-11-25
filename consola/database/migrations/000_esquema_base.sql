-- Esquema base de la Orange (incluye Hospitality). Idempotente: solo agrega lo que falte.

CREATE TABLE IF NOT EXISTS public.aprobacion_pago (
    id serial,
    id_autorizacion integer NOT NULL,
    id_terminal integer NOT NULL,
    monto double precision NOT NULL,
    id_recibo integer NOT NULL,
    solicitud_payload jsonb,
    respuesta_payload jsonb,
    error boolean DEFAULT false,
    estado character varying(20),
    sincronizado integer DEFAULT 0,
    fecha_registro timestamp without time zone DEFAULT now(),
    fecha_respuesta timestamp without time zone,
    PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.auditoria (
    id serial,
    accion character varying(100) NOT NULL,
    entidad character varying(50),
    id_entidad integer,
    id_usuario integer,
    usuario character varying(150),
    detalle text,
    fecha_registro timestamp without time zone DEFAULT now() NOT NULL,
    PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.autorizacion (
    id integer GENERATED ALWAYS AS IDENTITY,
    id_programacion integer NOT NULL,
    id_posicion integer NOT NULL,
    id_manguera integer NOT NULL,
    id_producto integer NOT NULL,
    precio numeric(12,2),
    preset numeric(12,2) DEFAULT 0 NOT NULL,
    tipo_programacion integer NOT NULL,
    valor_dinero numeric(12,2) NOT NULL,
    id_presetnsx integer,
    id_venta integer,
    sincronizado integer DEFAULT 0 NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    mensaje text,
    PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.bandera_color (
    id serial,
    id_estacion integer NOT NULL,
    color character varying(10) NOT NULL,
    activo boolean DEFAULT true,
    PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.cliente (
    id serial,
    identificador character varying(20),
    nombre character varying(150),
    tipo_documento character varying(50),
    correo character varying(50),
    placa character varying(6),
    km integer,
    activo boolean DEFAULT true,
    fecha_registro timestamp without time zone DEFAULT now(),
    PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.devolucion_saldo (
    id serial,
    id_autorizacion integer,
    id_forma_pago integer,
    monto double precision,
    contacto character varying(10),
    enviado boolean DEFAULT false,
    estado integer,
    respuesta text,
    fecharegistro timestamp without time zone DEFAULT now(),
    PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.dispensador (
    id integer GENERATED ALWAYS AS IDENTITY,
    id_nsx_dispensador integer NOT NULL,
    marca character varying(50),
    tipo integer,
    activo boolean DEFAULT true NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    PRIMARY KEY (id),
    UNIQUE (id_nsx_dispensador)
);

CREATE TABLE IF NOT EXISTS public.estacion (
    id serial,
    nombre character varying(50),
    id_bandera integer NOT NULL,
    bandera character varying(15) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT now(),
    valor_max_vueltos integer DEFAULT 0 NOT NULL,
    PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.estado (
    id serial,
    codigo integer NOT NULL,
    nombre character varying(20) NOT NULL,
    PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.factura (
    id serial,
    venta_id integer NOT NULL,
    documento character varying(15),
    tipo_documento integer,
    razon_social character varying(50),
    correo character varying(50),
    sincronizado boolean DEFAULT false,
    fecha_registro timestamp without time zone DEFAULT now(),
    PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.fidelidad (
    id serial,
    id_fidelidad_nsx integer NOT NULL,
    fidelidad character varying(15) NOT NULL,
    fecha_registro timestamp without time zone DEFAULT now(),
    PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.forma_pago (
    id serial,
    id_nsx_forma_pago integer NOT NULL,
    nombre character varying(50) NOT NULL,
    logo character varying(30) NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.historico_turno (
    id serial,
    id_turno integer NOT NULL,
    fecha_inicial timestamp without time zone,
    fecha_final timestamp without time zone,
    activo boolean DEFAULT true,
    fecha_registro timestamp without time zone DEFAULT now(),
    PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.impresora_posicion (
    id serial,
    id_posicion integer NOT NULL,
    ip character varying(30) NOT NULL,
    puerto character varying(6) NOT NULL,
    activo boolean DEFAULT true,
    fecha_registro timestamp without time zone DEFAULT now(),
    PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.manguera (
    id integer GENERATED ALWAYS AS IDENTITY,
    id_posicion integer NOT NULL,
    numero_manguera integer NOT NULL,
    id_nsx_producto integer,
    lado character varying(10),
    unidad_medida character varying(10),
    color character varying(20),
    activo boolean DEFAULT true NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    max_valor integer DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE (id_posicion, numero_manguera)
);

CREATE TABLE IF NOT EXISTS public.marcacion (
    id serial,
    valordinero integer NOT NULL,
    valorvolumen double precision NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    fecharegistro timestamp without time zone DEFAULT now(),
    PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.modulo (
    id serial,
    identificador character varying(20),
    sincronizar boolean DEFAULT false,
    activo boolean DEFAULT true,
    fecha_sincronizacion timestamp without time zone DEFAULT now(),
    PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.pantalla (
    id serial,
    serial character varying(20),
    ip character varying(20) NOT NULL,
    activo boolean DEFAULT true,
    PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.pantalla_posicion (
    id serial,
    id_pantalla integer NOT NULL,
    id_posicion integer NOT NULL,
    activo boolean DEFAULT true,
    PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.posicion (
    id integer GENERATED ALWAYS AS IDENTITY,
    id_dispensador integer NOT NULL,
    cara integer NOT NULL,
    id_nsx_posicion integer,
    mangueras integer DEFAULT 0 NOT NULL,
    formato_dinero integer DEFAULT 0 NOT NULL,
    formato_precio integer DEFAULT 0 NOT NULL,
    formato_volumen integer DEFAULT 0 NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    codigo_tankio character varying(30),
    PRIMARY KEY (id),
    UNIQUE (id_nsx_posicion)
);

CREATE TABLE IF NOT EXISTS public.producto (
    id integer GENERATED ALWAYS AS IDENTITY,
    id_nsx_producto integer NOT NULL,
    nombre character varying(50) NOT NULL,
    precio numeric(12,2) NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    PRIMARY KEY (id),
    UNIQUE (id_nsx_producto)
);

CREATE TABLE IF NOT EXISTS public.programacion (
    id integer GENERATED ALWAYS AS IDENTITY,
    posicion_id integer NOT NULL,
    manguera_id integer NOT NULL,
    tipo_programacion integer NOT NULL,
    valor_programado numeric(12,2) NOT NULL,
    valor_dinero numeric(12,2) NOT NULL,
    precio numeric(12,2),
    sincronizado boolean DEFAULT false NOT NULL,
    valor_abonado numeric(12,2) DEFAULT 0,
    valor_pendiente numeric(12,2),
    id_producto integer,
    id_cliente integer,
    fecha_registro timestamp without time zone DEFAULT now(),
    PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.telemetria_nequi (
    id serial,
    transaction_payment_id integer,
    raw_json text,
    description character varying(50),
    created_at timestamp without time zone DEFAULT now(),
    PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.terminal (
    id serial,
    serial character varying(20) NOT NULL,
    ip character varying(20) NOT NULL,
    activo boolean DEFAULT true,
    num_terminal integer DEFAULT 0 NOT NULL,
    breb boolean DEFAULT false NOT NULL,
    aprobacion boolean DEFAULT false NOT NULL,
    fecha_registro timestamp without time zone DEFAULT now(),
    PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.terminal_posicion (
    id serial,
    id_terminal integer NOT NULL,
    id_posicion integer NOT NULL,
    activo boolean DEFAULT true,
    PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.transaccion_pago (
    id integer GENERATED ALWAYS AS IDENTITY,
    id_programacion integer NOT NULL,
    valor numeric(12,2) NOT NULL,
    respuesta_pago text,
    id_forma_pago integer NOT NULL,
    id_estado_transaccion integer DEFAULT 0 NOT NULL,
    fecha_transaccion timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    recibo integer DEFAULT 0 NOT NULL,
    franquicia character varying,
    tarjeta character varying,
    PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.turno (
    id serial,
    hora_inicial time without time zone,
    hora_final time without time zone,
    activo boolean DEFAULT false,
    disponible boolean DEFAULT true,
    fecha_registro timestamp without time zone DEFAULT now(),
    id_turno_nsx integer DEFAULT 0 NOT NULL,
    fecha_turno_inicial timestamp without time zone,
    fecha_turno_final timestamp without time zone,
    PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS public.venta (
    id serial,
    id_venta_nsx integer,
    id_preset_nsx integer NOT NULL,
    id_posicion integer NOT NULL,
    id_manguera integer NOT NULL,
    dinero double precision NOT NULL,
    volumen double precision NOT NULL,
    precio double precision NOT NULL,
    saldo integer DEFAULT 0,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    id_turno integer DEFAULT 0,
    PRIMARY KEY (id)
);

-- Columnas
ALTER TABLE public.aprobacion_pago ADD COLUMN IF NOT EXISTS id_autorizacion integer;
ALTER TABLE public.aprobacion_pago ADD COLUMN IF NOT EXISTS id_terminal integer;
ALTER TABLE public.aprobacion_pago ADD COLUMN IF NOT EXISTS monto double precision;
ALTER TABLE public.aprobacion_pago ADD COLUMN IF NOT EXISTS id_recibo integer;
ALTER TABLE public.aprobacion_pago ADD COLUMN IF NOT EXISTS solicitud_payload jsonb;
ALTER TABLE public.aprobacion_pago ADD COLUMN IF NOT EXISTS respuesta_payload jsonb;
ALTER TABLE public.aprobacion_pago ADD COLUMN IF NOT EXISTS error boolean DEFAULT false;
ALTER TABLE public.aprobacion_pago ADD COLUMN IF NOT EXISTS estado character varying(20);
ALTER TABLE public.aprobacion_pago ADD COLUMN IF NOT EXISTS sincronizado integer DEFAULT 0;
ALTER TABLE public.aprobacion_pago ADD COLUMN IF NOT EXISTS fecha_registro timestamp without time zone DEFAULT now();
ALTER TABLE public.aprobacion_pago ADD COLUMN IF NOT EXISTS fecha_respuesta timestamp without time zone;
ALTER TABLE public.auditoria ADD COLUMN IF NOT EXISTS accion character varying(100);
ALTER TABLE public.auditoria ADD COLUMN IF NOT EXISTS entidad character varying(50);
ALTER TABLE public.auditoria ADD COLUMN IF NOT EXISTS id_entidad integer;
ALTER TABLE public.auditoria ADD COLUMN IF NOT EXISTS id_usuario integer;
ALTER TABLE public.auditoria ADD COLUMN IF NOT EXISTS usuario character varying(150);
ALTER TABLE public.auditoria ADD COLUMN IF NOT EXISTS detalle text;
ALTER TABLE public.auditoria ADD COLUMN IF NOT EXISTS fecha_registro timestamp without time zone DEFAULT now() NOT NULL;
ALTER TABLE public.autorizacion ADD COLUMN IF NOT EXISTS id_programacion integer;
ALTER TABLE public.autorizacion ADD COLUMN IF NOT EXISTS id_posicion integer;
ALTER TABLE public.autorizacion ADD COLUMN IF NOT EXISTS id_manguera integer;
ALTER TABLE public.autorizacion ADD COLUMN IF NOT EXISTS id_producto integer;
ALTER TABLE public.autorizacion ADD COLUMN IF NOT EXISTS precio numeric(12,2);
ALTER TABLE public.autorizacion ADD COLUMN IF NOT EXISTS preset numeric(12,2) DEFAULT 0 NOT NULL;
ALTER TABLE public.autorizacion ADD COLUMN IF NOT EXISTS tipo_programacion integer;
ALTER TABLE public.autorizacion ADD COLUMN IF NOT EXISTS valor_dinero numeric(12,2);
ALTER TABLE public.autorizacion ADD COLUMN IF NOT EXISTS id_presetnsx integer;
ALTER TABLE public.autorizacion ADD COLUMN IF NOT EXISTS id_venta integer;
ALTER TABLE public.autorizacion ADD COLUMN IF NOT EXISTS sincronizado integer DEFAULT 0 NOT NULL;
ALTER TABLE public.autorizacion ADD COLUMN IF NOT EXISTS fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL;
ALTER TABLE public.autorizacion ADD COLUMN IF NOT EXISTS mensaje text;
ALTER TABLE public.bandera_color ADD COLUMN IF NOT EXISTS id_estacion integer;
ALTER TABLE public.bandera_color ADD COLUMN IF NOT EXISTS color character varying(10);
ALTER TABLE public.bandera_color ADD COLUMN IF NOT EXISTS activo boolean DEFAULT true;
ALTER TABLE public.cliente ADD COLUMN IF NOT EXISTS identificador character varying(20);
ALTER TABLE public.cliente ADD COLUMN IF NOT EXISTS nombre character varying(150);
ALTER TABLE public.cliente ADD COLUMN IF NOT EXISTS tipo_documento character varying(50);
ALTER TABLE public.cliente ADD COLUMN IF NOT EXISTS correo character varying(50);
ALTER TABLE public.cliente ADD COLUMN IF NOT EXISTS placa character varying(6);
ALTER TABLE public.cliente ADD COLUMN IF NOT EXISTS km integer;
ALTER TABLE public.cliente ADD COLUMN IF NOT EXISTS activo boolean DEFAULT true;
ALTER TABLE public.cliente ADD COLUMN IF NOT EXISTS fecha_registro timestamp without time zone DEFAULT now();
ALTER TABLE public.devolucion_saldo ADD COLUMN IF NOT EXISTS id_autorizacion integer;
ALTER TABLE public.devolucion_saldo ADD COLUMN IF NOT EXISTS id_forma_pago integer;
ALTER TABLE public.devolucion_saldo ADD COLUMN IF NOT EXISTS monto double precision;
ALTER TABLE public.devolucion_saldo ADD COLUMN IF NOT EXISTS contacto character varying(10);
ALTER TABLE public.devolucion_saldo ADD COLUMN IF NOT EXISTS enviado boolean DEFAULT false;
ALTER TABLE public.devolucion_saldo ADD COLUMN IF NOT EXISTS estado integer;
ALTER TABLE public.devolucion_saldo ADD COLUMN IF NOT EXISTS respuesta text;
ALTER TABLE public.devolucion_saldo ADD COLUMN IF NOT EXISTS fecharegistro timestamp without time zone DEFAULT now();
ALTER TABLE public.dispensador ADD COLUMN IF NOT EXISTS id_nsx_dispensador integer;
ALTER TABLE public.dispensador ADD COLUMN IF NOT EXISTS marca character varying(50);
ALTER TABLE public.dispensador ADD COLUMN IF NOT EXISTS tipo integer;
ALTER TABLE public.dispensador ADD COLUMN IF NOT EXISTS activo boolean DEFAULT true NOT NULL;
ALTER TABLE public.dispensador ADD COLUMN IF NOT EXISTS fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL;
ALTER TABLE public.estacion ADD COLUMN IF NOT EXISTS nombre character varying(50);
ALTER TABLE public.estacion ADD COLUMN IF NOT EXISTS id_bandera integer;
ALTER TABLE public.estacion ADD COLUMN IF NOT EXISTS bandera character varying(15);
ALTER TABLE public.estacion ADD COLUMN IF NOT EXISTS fecha_registro timestamp without time zone DEFAULT now();
ALTER TABLE public.estacion ADD COLUMN IF NOT EXISTS valor_max_vueltos integer DEFAULT 0 NOT NULL;
ALTER TABLE public.estado ADD COLUMN IF NOT EXISTS codigo integer;
ALTER TABLE public.estado ADD COLUMN IF NOT EXISTS nombre character varying(20);
ALTER TABLE public.factura ADD COLUMN IF NOT EXISTS venta_id integer;
ALTER TABLE public.factura ADD COLUMN IF NOT EXISTS documento character varying(15);
ALTER TABLE public.factura ADD COLUMN IF NOT EXISTS tipo_documento integer;
ALTER TABLE public.factura ADD COLUMN IF NOT EXISTS razon_social character varying(50);
ALTER TABLE public.factura ADD COLUMN IF NOT EXISTS correo character varying(50);
ALTER TABLE public.factura ADD COLUMN IF NOT EXISTS sincronizado boolean DEFAULT false;
ALTER TABLE public.factura ADD COLUMN IF NOT EXISTS fecha_registro timestamp without time zone DEFAULT now();
ALTER TABLE public.fidelidad ADD COLUMN IF NOT EXISTS id_fidelidad_nsx integer;
ALTER TABLE public.fidelidad ADD COLUMN IF NOT EXISTS fidelidad character varying(15);
ALTER TABLE public.fidelidad ADD COLUMN IF NOT EXISTS fecha_registro timestamp without time zone DEFAULT now();
ALTER TABLE public.forma_pago ADD COLUMN IF NOT EXISTS id_nsx_forma_pago integer;
ALTER TABLE public.forma_pago ADD COLUMN IF NOT EXISTS nombre character varying(50);
ALTER TABLE public.forma_pago ADD COLUMN IF NOT EXISTS logo character varying(30);
ALTER TABLE public.forma_pago ADD COLUMN IF NOT EXISTS activo boolean DEFAULT true NOT NULL;
ALTER TABLE public.forma_pago ADD COLUMN IF NOT EXISTS fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL;
ALTER TABLE public.historico_turno ADD COLUMN IF NOT EXISTS id_turno integer;
ALTER TABLE public.historico_turno ADD COLUMN IF NOT EXISTS fecha_inicial timestamp without time zone;
ALTER TABLE public.historico_turno ADD COLUMN IF NOT EXISTS fecha_final timestamp without time zone;
ALTER TABLE public.historico_turno ADD COLUMN IF NOT EXISTS activo boolean DEFAULT true;
ALTER TABLE public.historico_turno ADD COLUMN IF NOT EXISTS fecha_registro timestamp without time zone DEFAULT now();
ALTER TABLE public.impresora_posicion ADD COLUMN IF NOT EXISTS id_posicion integer;
ALTER TABLE public.impresora_posicion ADD COLUMN IF NOT EXISTS ip character varying(30);
ALTER TABLE public.impresora_posicion ADD COLUMN IF NOT EXISTS puerto character varying(6);
ALTER TABLE public.impresora_posicion ADD COLUMN IF NOT EXISTS activo boolean DEFAULT true;
ALTER TABLE public.impresora_posicion ADD COLUMN IF NOT EXISTS fecha_registro timestamp without time zone DEFAULT now();
ALTER TABLE public.manguera ADD COLUMN IF NOT EXISTS id_posicion integer;
ALTER TABLE public.manguera ADD COLUMN IF NOT EXISTS numero_manguera integer;
ALTER TABLE public.manguera ADD COLUMN IF NOT EXISTS id_nsx_producto integer;
ALTER TABLE public.manguera ADD COLUMN IF NOT EXISTS lado character varying(10);
ALTER TABLE public.manguera ADD COLUMN IF NOT EXISTS unidad_medida character varying(10);
ALTER TABLE public.manguera ADD COLUMN IF NOT EXISTS color character varying(20);
ALTER TABLE public.manguera ADD COLUMN IF NOT EXISTS activo boolean DEFAULT true NOT NULL;
ALTER TABLE public.manguera ADD COLUMN IF NOT EXISTS fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL;
ALTER TABLE public.manguera ADD COLUMN IF NOT EXISTS max_valor integer DEFAULT 0;
ALTER TABLE public.marcacion ADD COLUMN IF NOT EXISTS valordinero integer;
ALTER TABLE public.marcacion ADD COLUMN IF NOT EXISTS valorvolumen double precision;
ALTER TABLE public.marcacion ADD COLUMN IF NOT EXISTS activo boolean DEFAULT true NOT NULL;
ALTER TABLE public.marcacion ADD COLUMN IF NOT EXISTS fecharegistro timestamp without time zone DEFAULT now();
ALTER TABLE public.modulo ADD COLUMN IF NOT EXISTS identificador character varying(20);
ALTER TABLE public.modulo ADD COLUMN IF NOT EXISTS sincronizar boolean DEFAULT false;
ALTER TABLE public.modulo ADD COLUMN IF NOT EXISTS activo boolean DEFAULT true;
ALTER TABLE public.modulo ADD COLUMN IF NOT EXISTS fecha_sincronizacion timestamp without time zone DEFAULT now();
ALTER TABLE public.pantalla ADD COLUMN IF NOT EXISTS serial character varying(20);
ALTER TABLE public.pantalla ADD COLUMN IF NOT EXISTS ip character varying(20);
ALTER TABLE public.pantalla ADD COLUMN IF NOT EXISTS activo boolean DEFAULT true;
ALTER TABLE public.pantalla_posicion ADD COLUMN IF NOT EXISTS id_pantalla integer;
ALTER TABLE public.pantalla_posicion ADD COLUMN IF NOT EXISTS id_posicion integer;
ALTER TABLE public.pantalla_posicion ADD COLUMN IF NOT EXISTS activo boolean DEFAULT true;
ALTER TABLE public.posicion ADD COLUMN IF NOT EXISTS id_dispensador integer;
ALTER TABLE public.posicion ADD COLUMN IF NOT EXISTS cara integer;
ALTER TABLE public.posicion ADD COLUMN IF NOT EXISTS id_nsx_posicion integer;
ALTER TABLE public.posicion ADD COLUMN IF NOT EXISTS mangueras integer DEFAULT 0 NOT NULL;
ALTER TABLE public.posicion ADD COLUMN IF NOT EXISTS formato_dinero integer DEFAULT 0 NOT NULL;
ALTER TABLE public.posicion ADD COLUMN IF NOT EXISTS formato_precio integer DEFAULT 0 NOT NULL;
ALTER TABLE public.posicion ADD COLUMN IF NOT EXISTS formato_volumen integer DEFAULT 0 NOT NULL;
ALTER TABLE public.posicion ADD COLUMN IF NOT EXISTS activo boolean DEFAULT true NOT NULL;
ALTER TABLE public.posicion ADD COLUMN IF NOT EXISTS fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL;
ALTER TABLE public.posicion ADD COLUMN IF NOT EXISTS codigo_tankio character varying(30);
ALTER TABLE public.producto ADD COLUMN IF NOT EXISTS id_nsx_producto integer;
ALTER TABLE public.producto ADD COLUMN IF NOT EXISTS nombre character varying(50);
ALTER TABLE public.producto ADD COLUMN IF NOT EXISTS precio numeric(12,2);
ALTER TABLE public.producto ADD COLUMN IF NOT EXISTS activo boolean DEFAULT true NOT NULL;
ALTER TABLE public.producto ADD COLUMN IF NOT EXISTS fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL;
ALTER TABLE public.programacion ADD COLUMN IF NOT EXISTS posicion_id integer;
ALTER TABLE public.programacion ADD COLUMN IF NOT EXISTS manguera_id integer;
ALTER TABLE public.programacion ADD COLUMN IF NOT EXISTS tipo_programacion integer;
ALTER TABLE public.programacion ADD COLUMN IF NOT EXISTS valor_programado numeric(12,2);
ALTER TABLE public.programacion ADD COLUMN IF NOT EXISTS valor_dinero numeric(12,2);
ALTER TABLE public.programacion ADD COLUMN IF NOT EXISTS precio numeric(12,2);
ALTER TABLE public.programacion ADD COLUMN IF NOT EXISTS sincronizado boolean DEFAULT false NOT NULL;
ALTER TABLE public.programacion ADD COLUMN IF NOT EXISTS valor_abonado numeric(12,2) DEFAULT 0;
ALTER TABLE public.programacion ADD COLUMN IF NOT EXISTS valor_pendiente numeric(12,2);
ALTER TABLE public.programacion ADD COLUMN IF NOT EXISTS id_producto integer;
ALTER TABLE public.programacion ADD COLUMN IF NOT EXISTS id_cliente integer;
ALTER TABLE public.programacion ADD COLUMN IF NOT EXISTS fecha_registro timestamp without time zone DEFAULT now();
ALTER TABLE public.telemetria_nequi ADD COLUMN IF NOT EXISTS transaction_payment_id integer;
ALTER TABLE public.telemetria_nequi ADD COLUMN IF NOT EXISTS raw_json text;
ALTER TABLE public.telemetria_nequi ADD COLUMN IF NOT EXISTS description character varying(50);
ALTER TABLE public.telemetria_nequi ADD COLUMN IF NOT EXISTS created_at timestamp without time zone DEFAULT now();
ALTER TABLE public.terminal ADD COLUMN IF NOT EXISTS serial character varying(20);
ALTER TABLE public.terminal ADD COLUMN IF NOT EXISTS ip character varying(20);
ALTER TABLE public.terminal ADD COLUMN IF NOT EXISTS activo boolean DEFAULT true;
ALTER TABLE public.terminal ADD COLUMN IF NOT EXISTS num_terminal integer DEFAULT 0 NOT NULL;
ALTER TABLE public.terminal ADD COLUMN IF NOT EXISTS breb boolean DEFAULT false NOT NULL;
ALTER TABLE public.terminal ADD COLUMN IF NOT EXISTS aprobacion boolean DEFAULT false NOT NULL;
ALTER TABLE public.terminal ADD COLUMN IF NOT EXISTS fecha_registro timestamp without time zone DEFAULT now();
ALTER TABLE public.terminal_posicion ADD COLUMN IF NOT EXISTS id_terminal integer;
ALTER TABLE public.terminal_posicion ADD COLUMN IF NOT EXISTS id_posicion integer;
ALTER TABLE public.terminal_posicion ADD COLUMN IF NOT EXISTS activo boolean DEFAULT true;
ALTER TABLE public.transaccion_pago ADD COLUMN IF NOT EXISTS id_programacion integer;
ALTER TABLE public.transaccion_pago ADD COLUMN IF NOT EXISTS valor numeric(12,2);
ALTER TABLE public.transaccion_pago ADD COLUMN IF NOT EXISTS respuesta_pago text;
ALTER TABLE public.transaccion_pago ADD COLUMN IF NOT EXISTS id_forma_pago integer;
ALTER TABLE public.transaccion_pago ADD COLUMN IF NOT EXISTS id_estado_transaccion integer DEFAULT 0 NOT NULL;
ALTER TABLE public.transaccion_pago ADD COLUMN IF NOT EXISTS fecha_transaccion timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL;
ALTER TABLE public.transaccion_pago ADD COLUMN IF NOT EXISTS recibo integer DEFAULT 0 NOT NULL;
ALTER TABLE public.transaccion_pago ADD COLUMN IF NOT EXISTS franquicia character varying;
ALTER TABLE public.transaccion_pago ADD COLUMN IF NOT EXISTS tarjeta character varying;
ALTER TABLE public.turno ADD COLUMN IF NOT EXISTS hora_inicial time without time zone;
ALTER TABLE public.turno ADD COLUMN IF NOT EXISTS hora_final time without time zone;
ALTER TABLE public.turno ADD COLUMN IF NOT EXISTS activo boolean DEFAULT false;
ALTER TABLE public.turno ADD COLUMN IF NOT EXISTS disponible boolean DEFAULT true;
ALTER TABLE public.turno ADD COLUMN IF NOT EXISTS fecha_registro timestamp without time zone DEFAULT now();
ALTER TABLE public.turno ADD COLUMN IF NOT EXISTS id_turno_nsx integer DEFAULT 0 NOT NULL;
ALTER TABLE public.turno ADD COLUMN IF NOT EXISTS fecha_turno_inicial timestamp without time zone;
ALTER TABLE public.turno ADD COLUMN IF NOT EXISTS fecha_turno_final timestamp without time zone;
ALTER TABLE public.venta ADD COLUMN IF NOT EXISTS id_venta_nsx integer;
ALTER TABLE public.venta ADD COLUMN IF NOT EXISTS id_preset_nsx integer;
ALTER TABLE public.venta ADD COLUMN IF NOT EXISTS id_posicion integer;
ALTER TABLE public.venta ADD COLUMN IF NOT EXISTS id_manguera integer;
ALTER TABLE public.venta ADD COLUMN IF NOT EXISTS dinero double precision;
ALTER TABLE public.venta ADD COLUMN IF NOT EXISTS volumen double precision;
ALTER TABLE public.venta ADD COLUMN IF NOT EXISTS precio double precision;
ALTER TABLE public.venta ADD COLUMN IF NOT EXISTS saldo integer DEFAULT 0;
ALTER TABLE public.venta ADD COLUMN IF NOT EXISTS fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL;
ALTER TABLE public.venta ADD COLUMN IF NOT EXISTS id_turno integer DEFAULT 0;

-- Funciones
CREATE OR REPLACE FUNCTION public.notify_event_authorization()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
  payload JSON;
BEGIN
--V1
	-- Obtenemos datos combinados usando JOIN
  SELECT row_to_json(t)
  INTO payload
  FROM (
	    SELECT 
			pt.serial,
			a.id as authorizationid,
			a.id_posicion as positionid,
			a.id_manguera as hoseid,
			a.id_producto as productid,
			a.preset,
			a.tipo_programacion as programmingtypeid,
			a.valor_dinero as valueamountmoney,
			a.id_presetnsx,
			a.id_venta as saleid,
			a.sincronizado as sync
			FROM public.autorizacion as a		
		INNER JOIN public.programacion as p
		ON a.id_programacion  = p.id
		INNER JOIN public.pantalla_posicion as pp
		ON pp.id_posicion = p.posicion_id
		INNER JOIN public.pantalla as pt
		ON pt.id = pp.id_pantalla
		WHERE a.id = NEW.id
  ) t;

  -- Notificamos el canal con el JSON
  PERFORM pg_notify('notify_event_authorization', payload::text);

  
  RETURN NEW;
END;
$function$
;
CREATE OR REPLACE FUNCTION public.notify_event_transaction_payment()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
  payload JSON;
BEGIN
--V1
	-- Obtenemos datos combinados usando JOIN
  SELECT row_to_json(t)
  INTO payload
  FROM (
	    SELECT pt.serial,
			tp.id as paymentId,
			p.id as programmingId,
			tp.valor as amount,
			tp.respuesta_pago as responsePayment,
			tp.id_forma_pago as methodpaymentId,
			tp.id_estado_transaccion as statusPaymentId,
			p.valor_programado as programmingAmount,
			p.valor_abonado as amountPaid,
			p.valor_pendiente as pendingAmount,
			tp.fecha_transaccion as transactionDate
			FROM transaccion_pago as tp
			INNER JOIN public.programacion as p
			ON p.id = tp.id_programacion
			INNER JOIN public.pantalla_posicion as pp
			ON pp.id_posicion = p.posicion_id
			INNER JOIN public.pantalla as pt
			ON pt.id = pp.id_pantalla
		WHERE tp.id = NEW.id
  ) t;

  -- Notificamos el canal con el JSON
  PERFORM pg_notify('notify_event_transaction_payment', payload::text);

  
  RETURN NEW;
END;
$function$
;
CREATE OR REPLACE FUNCTION public.trg_estado_transaccion_pago()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE    
	existTransaction BOOLEAN;
BEGIN
--V1
     IF TG_OP = 'UPDATE' THEN
      

		IF(OLD.id_estado_transaccion = 4 AND NEW.id_estado_transaccion = 2) THEN						

				UPDATE public.programacion 
				SET 
				valor_abonado = CASE WHEN valor_dinero > valor_abonado 
				THEN valor_abonado+ NEW.valor ELSE valor_dinero END,
				valor_pendiente =CASE WHEN valor_dinero <= valor_pendiente
				THEN valor_pendiente - NEW.valor ELSE 0 END
				WHERE id = OLD.id_programacion;
			
		END IF;
		
	

    END IF;
    RETURN NEW;
END;
$function$
;
CREATE OR REPLACE FUNCTION public.trg_insert_autorizacion()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
--V1
    IF (NEW.valor_abonado IS DISTINCT FROM OLD.valor_abonado AND NEW.valor_abonado = OLD.valor_dinero AND NEW.sincronizado = false) OR
	   (NEW.valor_programado IS DISTINCT FROM OLD.valor_programado AND NEW.valor_abonado = NEW.valor_dinero AND NEW.sincronizado = false)
	THEN

		--Tipo programacion 1. Full 2.Dinero 3.Volumen
		  INSERT INTO public.autorizacion(
				id_programacion,
				id_posicion,
				id_manguera,
				id_producto,
				preset,
				precio,
				tipo_programacion,
				valor_dinero
				)
				VALUES (
					NEW.id,
					NEW.posicion_id,
					NEW.manguera_id,
					NEW.id_producto,
					NEW.valor_programado,
					NEW.precio,				
					NEW.tipo_programacion,
					NEW.valor_dinero			
				);

			UPDATE public.programacion SET sincronizado = true WHERE id = NEW.id;

	      
    END IF;

    RETURN NEW; -- Permitir que la operación de actualización continúe
END;
$function$
;

-- Triggers
DO $do$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'notify_event_authorization' AND tgrelid = 'public.autorizacion'::regclass) THEN
    CREATE TRIGGER notify_event_authorization AFTER UPDATE ON public.autorizacion FOR EACH ROW WHEN ((old.sincronizado IS DISTINCT FROM new.sincronizado)) EXECUTE FUNCTION notify_event_authorization();
  END IF;
END $do$;
DO $do$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'notify_event_transaction_payment' AND tgrelid = 'public.transaccion_pago'::regclass) THEN
    CREATE TRIGGER notify_event_transaction_payment AFTER UPDATE ON public.transaccion_pago FOR EACH ROW WHEN ((old.id_estado_transaccion IS DISTINCT FROM new.id_estado_transaccion)) EXECUTE FUNCTION notify_event_transaction_payment();
  END IF;
END $do$;
DO $do$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_estado_transaccion_pago' AND tgrelid = 'public.transaccion_pago'::regclass) THEN
    CREATE TRIGGER trg_estado_transaccion_pago AFTER UPDATE ON public.transaccion_pago FOR EACH ROW WHEN ((old.id_estado_transaccion IS DISTINCT FROM new.id_estado_transaccion)) EXECUTE FUNCTION trg_estado_transaccion_pago();
  END IF;
END $do$;
DO $do$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'trg_insert_autorizacion' AND tgrelid = 'public.programacion'::regclass) THEN
    CREATE TRIGGER trg_insert_autorizacion AFTER UPDATE ON public.programacion FOR EACH ROW EXECUTE FUNCTION trg_insert_autorizacion();
  END IF;
END $do$;
