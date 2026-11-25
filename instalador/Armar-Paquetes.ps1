# Compila el API y la pagina de configuracion en instalador\Paquetes (correr antes de llevar el instalador)
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$api = Join-Path $PSScriptRoot 'Paquetes\API'
$admin = Join-Path $PSScriptRoot 'Paquetes\Admin'
foreach ($d in $api, $admin) { if (Test-Path $d) { Remove-Item -LiteralPath $d -Recurse -Force }; New-Item -ItemType Directory -Force $d | Out-Null }

dotnet publish (Join-Path $raiz 'servidor\api\NSXAutoServiceAPI\NSXAutoServiceAPI.csproj') -c Release -o $api --nologo
if ($LASTEXITCODE -ne 0) { throw 'Fallo la compilacion del API' }
# El instalador escribe su propio appsettings.json
Get-ChildItem -LiteralPath $api -Filter 'appsettings*.json' | Remove-Item -Force

Push-Location (Join-Path $raiz 'servidor\admin')
try {
    npm ci; if ($LASTEXITCODE -ne 0) { throw 'Fallo npm ci' }
    npm run build; if ($LASTEXITCODE -ne 0) { throw 'Fallo la compilacion de la pagina' }
    Copy-Item 'dist\*' $admin -Recurse -Force
} finally { Pop-Location }
Write-Host 'Listo. Falta el Hosting Bundle (dotnet-hosting-8.x-win.exe) en Prerrequisitos si el equipo no lo tiene.'
