-- Mayor valor en dinero que acepta el surtidor de la posicion (6 o 7 digitos): lo entrega NSX en el mapeo
ALTER TABLE public.posicion ADD COLUMN IF NOT EXISTS maximo_dinero numeric(14,2);
