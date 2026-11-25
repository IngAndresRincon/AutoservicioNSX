-- Tabla de auditoría del panel de autoservicio.
-- No pertenece al esquema sincronizado con NSX: es de uso exclusivo de esta
-- aplicación (registra quién hizo qué acción, sobre qué registro y cuándo).
--
-- Uso:
--   psql -h HOST -U USUARIO -d BASE_DE_DATOS -f deploy/create-auditoria-table.sql

CREATE TABLE IF NOT EXISTS auditoria (
  id SERIAL PRIMARY KEY,
  accion VARCHAR(100) NOT NULL,
  entidad VARCHAR(50),
  id_entidad INTEGER,
  id_usuario INTEGER,
  usuario VARCHAR(150),
  detalle TEXT,
  fecha_registro TIMESTAMP NOT NULL DEFAULT now()
);
