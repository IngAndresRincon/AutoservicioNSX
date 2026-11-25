-- Catalogo de estados que usan consola y service (solo agrega los que falten)
INSERT INTO public.estado (codigo, nombre)
SELECT v.codigo, v.nombre
FROM (VALUES (0,'Registrado'), (1,'Leido'), (2,'Confirmado'), (3,'Rechazado'), (4,'Reportado'),
             (5,'Anulado'), (6,'Venta Zero'), (7,'Factura'), (8,'Despachando')) AS v(codigo, nombre)
WHERE NOT EXISTS (SELECT 1 FROM public.estado e WHERE e.codigo = v.codigo);
