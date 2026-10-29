-- Precio del nivel configurado en la manguera (el de la venta del vendedor); el de autoservicio sigue en producto.precio
ALTER TABLE public.manguera ADD COLUMN IF NOT EXISTS precio_publico numeric(14,2);
