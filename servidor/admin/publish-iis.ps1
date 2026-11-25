# Publica el build de autoservice-admin en IIS, puerto 8092.
# Ejecutar en PowerShell "Como administrador".

$siteName   = "NSXAutoserviceAdmin"
$appPoolName = "NSXAutoserviceAdminPool"
$port       = 8092
$physicalPath = "D:\Autoservice\Repositorio\Autoservice\NSXAutoservicePage\autoservice-admin\dist"

Import-Module WebAdministration

if (-not (Test-Path $physicalPath)) {
    Write-Error "No existe la carpeta de build: $physicalPath. Corre 'npm run build' primero."
    exit 1
}

# App pool
if (-not (Test-Path "IIS:\AppPools\$appPoolName")) {
    New-WebAppPool -Name $appPoolName | Out-Null
}
Set-ItemProperty "IIS:\AppPools\$appPoolName" -Name managedRuntimeVersion -Value ""

# Sitio
if (Test-Path "IIS:\Sites\$siteName") {
    Write-Host "El sitio '$siteName' ya existe, actualizando ruta fisica y binding..."
    Set-ItemProperty "IIS:\Sites\$siteName" -Name physicalPath -Value $physicalPath
} else {
    New-Website -Name $siteName -Port $port -PhysicalPath $physicalPath -ApplicationPool $appPoolName | Out-Null
}

# web.config minimo (la app no usa react-router, no hace falta SPA fallback)
$webConfig = @"
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
  <system.webServer>
    <staticContent>
      <remove fileExtension=".json" />
      <mimeMap fileExtension=".json" mimeType="application/json" />
    </staticContent>
  </system.webServer>
</configuration>
"@
Set-Content -Path (Join-Path $physicalPath "web.config") -Value $webConfig -Encoding UTF8

Write-Host "Listo. Sitio '$siteName' publicado en http://localhost:$port"
