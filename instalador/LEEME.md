# Instalador Autoservicio

## Servidor (API + pagina + BD)
1. Copiar esta carpeta al servidor. El Hosting Bundle ya viene en `Prerrequisitos\`.
2. Doble clic en `Instalar.bat`. Toma los datos de `Instalar.config` sin preguntar (borre una linea para que pregunte).
   `Instalar.config` tiene la clave de SQL en texto plano.
3. Puertos por defecto: API 8070, pagina 8071 (si estan ocupados sube al siguiente par libre). En una actualizacion conserva los que ya tiene.
4. Hace: IIS, respaldo de la BD, scripts (Prime: 01,04,05,06,08,13 + comun 148; NSX2: solo 148), sitios IIS, firewall y verificacion.
5. Es re-ejecutable: guarda copia de la API anterior y no pisa `appsettings.json`.

## Orange
Un solo archivo `.run`: ver `Orange\LEEME.md`. El APK de la tablet se instala a mano.

## Estado de pruebas
Instalacion nueva y actualizacion probadas en el PC de desarrollo (NSX2, sitios de prueba).
Falta: opcion Prime, un servidor limpio sin IIS y una Orange real.
