# Instalador del autoservicio en el servidor de la EDS: IIS, API, pagina de configuracion y scripts de BD.
# Se abre con Instalar.bat (como administrador). Funciona sin internet.
param(
    [ValidateSet('NSX2', 'Prime')][string]$Sistema,
    [string]$ServidorSql = '127.0.0.1',
    [string]$Base = 'EstacionNSX',
    [string]$UsuarioSql = 'sa',
    [string]$ClaveSql,
    [string]$IpNsx = '127.0.0.1',
    [int]$PuertoApi = 0,
    [int]$PuertoPagina = 0,
    [string]$Destino,
    [string]$SitioApi = 'NSXAutoservicioAPI',
    [string]$SitioPagina = 'NSXAutoserviceAdmin',
    [string]$IpPagina,
    [switch]$SinRespaldo
)

$ErrorActionPreference = 'Stop'
$aqui = Split-Path -Parent $MyInvocation.MyCommand.Path
$log = Join-Path $aqui ("logs\instalacion_{0:yyyyMMdd_HHmmss}.log" -f (Get-Date))
New-Item -ItemType Directory -Force (Split-Path $log) | Out-Null
$ConfirmPreference = 'None'
$ProgressPreference = 'SilentlyContinue'
function Log($t) { Add-Content -Path $log -Value $t -Encoding UTF8 }

function Paso($n, $texto) { Write-Host ""; Write-Host "[$n] $texto" -ForegroundColor Cyan; Log "[$n] $texto" }
function Ok($texto) { Write-Host "    OK  $texto" -ForegroundColor Green; Log "    OK  $texto" }
function Aviso($texto) { Write-Host "    !!  $texto" -ForegroundColor Yellow; Log "    !!  $texto" }
function Falla($texto) { Write-Host "    XX  $texto" -ForegroundColor Red; Log "    XX  $texto" }
$script:Silencioso = $false
$cfgArchivo = Join-Path $aqui 'Instalar.config'
if (Test-Path $cfgArchivo) {
    foreach ($l in Get-Content $cfgArchivo -Encoding UTF8) {
        if ($l -match '^\s*([A-Za-z]+)\s*=\s*(.*?)\s*$' -and $l -notmatch '^\s*#') {
            $k = $Matches[1]; $v = $Matches[2]
            if ($PSBoundParameters.ContainsKey($k) -or [string]::IsNullOrEmpty($v)) { continue }
            if ($k -eq 'Sistema' -and $v -notin 'NSX2', 'Prime') { continue }
            if ($k -in 'PuertoApi', 'PuertoPagina') { Set-Variable $k ([int]$v) } else { Set-Variable $k $v }
        }
    }
    $script:Silencioso = $true
}
function Pregunta($texto, $defecto) {
    if ($script:Silencioso) { return $defecto }
    $r = Read-Host "$texto [$defecto]"
    if ([string]::IsNullOrWhiteSpace($r)) { return $defecto } else { return $r.Trim() }
}

function Abrir-Sql($master) {
    $cs = "Server=$ServidorSql;Database=$(if ($master) { 'master' } else { $Base });User Id=$UsuarioSql;Password=$ClaveSql;TrustServerCertificate=True;Connect Timeout=15"
    $c = New-Object System.Data.SqlClient.SqlConnection $cs
    $c.Open()
    return $c
}

function Ejecutar-Sql($conn, $texto, $timeout = 600) {
    $cmd = $conn.CreateCommand(); $cmd.CommandText = $texto; $cmd.CommandTimeout = $timeout
    [void]$cmd.ExecuteNonQuery()
}

function Ejecutar-Script($conn, $archivo) {
    $texto = [System.IO.File]::ReadAllText($archivo, [System.Text.Encoding]::UTF8)
    $lotes = [regex]::Split($texto, '(?im)^\s*GO\s*$') | Where-Object { $_.Trim() -ne '' }
    foreach ($lote in $lotes) { Ejecutar-Sql $conn $lote }
}

function Puerto-Libre($p) {
    if (Get-NetTCPConnection -State Listen -LocalPort $p -ErrorAction SilentlyContinue) { return $false }
    if (Get-Module WebAdministration) {
        foreach ($s in Get-Website) { foreach ($b in $s.Bindings.Collection) { if ($b.bindingInformation -match ":$p`:") { return $false } } }
    }
    return $true
}

try {
    Write-Host "=== Instalador Autoservicio INSEPET ===" -ForegroundColor White
    $admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $admin) { throw 'Ejecute este instalador como administrador (use Instalar.bat).' }

    # ---- Datos ----
    Paso 1 'Datos de la instalacion (Enter acepta el valor entre corchetes)'
    if (-not $Sistema) {
        $r = Pregunta 'Sistema de la estacion (1 = NSX2, 2 = Prime)' '1'
        $Sistema = if ($r -eq '2' -or $r -eq 'Prime') { 'Prime' } else { 'NSX2' }
    }
    if (-not $PSBoundParameters.ContainsKey('ServidorSql')) { $ServidorSql = Pregunta 'Servidor SQL' $ServidorSql }
    if (-not $PSBoundParameters.ContainsKey('Base')) { $Base = Pregunta 'Base de datos' $Base }
    if (-not $PSBoundParameters.ContainsKey('UsuarioSql')) { $UsuarioSql = Pregunta 'Usuario SQL' $UsuarioSql }
    if (-not $ClaveSql) {
        $sec = Read-Host "Clave de $UsuarioSql" -AsSecureString
        $ClaveSql = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
    }
    if (-not $PSBoundParameters.ContainsKey('IpNsx')) { $IpNsx = Pregunta 'IP del equipo donde corre NSX (comandos, puerto 8010)' $IpNsx }
    if (-not $Destino) {
        $unidad = if (Test-Path 'D:\') { 'D:' } else { 'C:' }
        $Destino = Pregunta 'Carpeta de instalacion' "$unidad\Insepet\NSXAutoservice"
    }

    # ---- Prerrequisitos ----
    Paso 2 'IIS y .NET 8 Hosting Bundle'
    $feats = 'IIS-WebServerRole', 'IIS-WebServer', 'IIS-CommonHttpFeatures', 'IIS-StaticContent', 'IIS-DefaultDocument',
             'IIS-HttpErrors', 'IIS-ApplicationDevelopment', 'IIS-HealthAndDiagnostics', 'IIS-HttpLogging', 'IIS-Security',
             'IIS-RequestFiltering', 'IIS-Performance', 'IIS-WebServerManagementTools', 'IIS-ManagementConsole', 'IIS-ManagementScriptingTools'
    $falta = $feats | Where-Object { (Get-WindowsOptionalFeature -Online -FeatureName $_).State -ne 'Enabled' }
    if ($falta) {
        Write-Host '    Activando IIS (puede tardar unos minutos)...'
        Enable-WindowsOptionalFeature -Online -FeatureName $falta -All -NoRestart | Out-Null
    }
    Ok 'IIS activo'
    Import-Module WebAdministration

    $modulo = Test-Path "$env:ProgramFiles\IIS\Asp.Net Core Module\V2\aspnetcorev2.dll"
    $runtime = $false
    try { $runtime = (& dotnet --list-runtimes 2>$null) -match 'Microsoft.AspNetCore.App 8\.' } catch { }
    if (-not ($modulo -and $runtime)) {
        $bundle = Get-ChildItem (Join-Path $aqui 'Prerrequisitos') -Filter 'dotnet-hosting-8*.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $bundle) { throw "Falta el .NET 8 Hosting Bundle. Copie dotnet-hosting-8.x-win.exe en la carpeta 'Prerrequisitos' y vuelva a ejecutar." }
        Write-Host "    Instalando $($bundle.Name)..."
        $p = Start-Process $bundle.FullName -ArgumentList '/install', '/quiet', '/norestart' -Wait -PassThru
        if ($p.ExitCode -notin 0, 3010) { throw "El Hosting Bundle termino con codigo $($p.ExitCode)." }
        & iisreset /restart | Out-Null
    }
    Ok '.NET 8 Hosting Bundle presente'

    # ---- Base de datos ----
    Paso 3 "Base de datos ($Sistema)"
    $conn = Abrir-Sql $false
    Ok "Conectado a $ServidorSql / $Base"
    if (-not $SinRespaldo) {
        try {
            $arch = "{0}_antes_autoservicio_{1:yyyyMMdd_HHmmss}.bak" -f $Base, (Get-Date)
            $cm = Abrir-Sql $true
            $dirBak = (New-Object System.Data.SqlClient.SqlCommand "SELECT CAST(SERVERPROPERTY('InstanceDefaultBackupPath') AS NVARCHAR(500))", $cm).ExecuteScalar()
            $ruta = Join-Path $dirBak $arch
            Ejecutar-Sql $cm "BACKUP DATABASE [$Base] TO DISK = N'$ruta' WITH INIT, COPY_ONLY" 1800
            $cm.Close()
            Ok "Respaldo: $ruta"
        } catch { Aviso "No se pudo respaldar la base ($($_.Exception.Message)). Continua." }
    }
    $lista = @()
    if ($Sistema -eq 'Prime') { $lista += Get-ChildItem (Join-Path $aqui 'Scripts\Prime') -Filter '*.sql' | Sort-Object Name }
    $lista += Get-Item (Join-Path $aqui 'Scripts\Comun_148_Compatibilidad.sql')
    # En Prime el 13 (MUX) va despues del esquema; el comun al final
    foreach ($s in $lista) {
        try { Ejecutar-Script $conn $s.FullName; Ok $s.Name }
        catch { throw "Fallo $($s.Name): $($_.Exception.Message)" }
    }
    $ipValor = "$IpNsx|8010"
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = "UPDATE dbo.Configuracion SET Valor = @v WHERE Nombre = 'IPNsxAPI'"
    [void]$cmd.Parameters.AddWithValue('@v', $ipValor); [void]$cmd.ExecuteNonQuery()
    Ok "IPNsxAPI = $ipValor"
    $conn.Close()

    # ---- Puertos ----
    Paso 4 'Puertos'
    $actual = $null
    if (Test-Path "IIS:\Sites\$SitioApi") { $actual = (Get-WebBinding -Name $SitioApi).bindingInformation -replace '.*:(\d+):.*', '$1' }
    $actualPag = $null
    if (Test-Path "IIS:\Sites\$SitioPagina") { $actualPag = (Get-WebBinding -Name $SitioPagina).bindingInformation -replace '.*:(\d+):.*', '$1' }
    if ($PuertoApi -eq 0) {
        if ($actual) { $PuertoApi = [int]$actual } else { $PuertoApi = 8070; while (-not (Puerto-Libre $PuertoApi) -or -not (Puerto-Libre ($PuertoApi + 1))) { $PuertoApi++ } }
    }
    if ($PuertoPagina -eq 0) { $PuertoPagina = if ($actualPag) { [int]$actualPag } else { $PuertoApi + 1 } }
    Ok "API en el $PuertoApi, pagina en el $PuertoPagina"

    # ---- API ----
    Paso 5 'API'
    $dirApi = Join-Path $Destino 'API'
    $dirPag = Join-Path $Destino 'Admin'
    $poolApi = "${SitioApi}Pool"; $poolPag = "${SitioPagina}Pool"
    New-Item -ItemType Directory -Force $dirApi, $dirPag | Out-Null

    if (Test-Path "IIS:\Sites\$SitioApi") {
        Stop-Website $SitioApi
        if (Test-Path "IIS:\AppPools\$poolApi") { Stop-WebAppPool $poolApi; for ($i = 0; $i -lt 20 -and (Get-WebAppPoolState $poolApi).Value -ne 'Stopped'; $i++) { Start-Sleep 1 } }
        Start-Sleep 2
    }
    $cfgPrevio = Join-Path $dirApi 'appsettings.json'
    $guardado = $null
    if (Test-Path $cfgPrevio) { $guardado = Get-Content $cfgPrevio -Raw -Encoding UTF8; Aviso 'Actualizacion: se conserva el appsettings.json existente.' }
    if (Test-Path $dirApi -PathType Container) {
        $ant = Join-Path $Destino ("API_anterior_{0:yyyyMMdd_HHmmss}" -f (Get-Date))
        if (Get-ChildItem $dirApi -ErrorAction SilentlyContinue) { Copy-Item $dirApi $ant -Recurse; Ok "Copia de la version anterior: $ant" }
    }
    Copy-Item (Join-Path $aqui 'Paquetes\API\*') $dirApi -Recurse -Force
    if ($guardado) { Set-Content $cfgPrevio $guardado -Encoding UTF8 }
    else {
        $cs = "Server=$ServidorSql;Database=$Base;User Id=$UsuarioSql;Password=$ClaveSql;TrustServerCertificate=True"
        $json = @{ Logging = @{ LogLevel = @{ Default = 'Information'; 'Microsoft.AspNetCore' = 'Warning' } }; AllowedHosts = '*'; ConnectionStrings = @{ DefaultConnection = $cs } } | ConvertTo-Json -Depth 5
        Set-Content $cfgPrevio $json -Encoding UTF8
        Ok 'appsettings.json escrito'
    }

    foreach ($pool in $poolApi, $poolPag) {
        if (-not (Test-Path "IIS:\AppPools\$pool")) { New-WebAppPool $pool | Out-Null }
        Set-ItemProperty "IIS:\AppPools\$pool" managedRuntimeVersion ''
    }
    if (-not (Test-Path "IIS:\Sites\$SitioApi")) {
        New-Website -Name $SitioApi -Port $PuertoApi -PhysicalPath $dirApi -ApplicationPool $poolApi | Out-Null
    } else {
        Set-ItemProperty "IIS:\Sites\$SitioApi" physicalPath $dirApi
        Set-ItemProperty "IIS:\Sites\$SitioApi" applicationPool $poolApi
    }
    & icacls $dirApi /grant "IIS AppPool\${poolApi}:(OI)(CI)M" /T /Q | Out-Null
    if ((Get-WebAppPoolState $poolApi).Value -ne 'Started') { Start-WebAppPool $poolApi }
    Start-Website $SitioApi
    Ok "Sitio $SitioApi"

    # ---- Pagina ----
    Paso 6 'Pagina de configuracion'
    if (Test-Path "IIS:\Sites\$SitioPagina") { Stop-Website $SitioPagina; Start-Sleep 1 }
    Copy-Item (Join-Path $aqui 'Paquetes\Admin\*') $dirPag -Recurse -Force
    # La pagina corre en el navegador de quien la abre: necesita la IP del servidor, no localhost
    $ipLan = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notmatch '^(127|169\.254)' -and $_.PrefixOrigin -ne 'WellKnown' } | Select-Object -First 1).IPAddress
    if (-not $ipLan) { $ipLan = 'localhost' }
    $ipPagina = if ($IpPagina) { $IpPagina } else { Pregunta 'IP o nombre con el que se abrira el API desde otros equipos' $ipLan }
    [System.IO.File]::WriteAllText((Join-Path $dirPag 'config.json'), ('{{ "apiUrl": "http://{0}:{1}/api" }}' -f $ipPagina, $PuertoApi), (New-Object System.Text.UTF8Encoding $false))
    $wc = '<?xml version="1.0" encoding="UTF-8"?><configuration><system.webServer><staticContent><remove fileExtension=".json" /><mimeMap fileExtension=".json" mimeType="application/json" /></staticContent></system.webServer></configuration>'
    Set-Content (Join-Path $dirPag 'web.config') $wc -Encoding UTF8
    if (-not (Test-Path "IIS:\Sites\$SitioPagina")) {
        New-Website -Name $SitioPagina -Port $PuertoPagina -PhysicalPath $dirPag -ApplicationPool $poolPag | Out-Null
    } else { Set-ItemProperty "IIS:\Sites\$SitioPagina" physicalPath $dirPag }
    & icacls $dirPag /grant "IIS AppPool\${poolPag}:(OI)(CI)RX" /T /Q | Out-Null
    Start-Website $SitioPagina
    Ok "Sitio $SitioPagina"

    # ---- Firewall ----
    Paso 7 'Firewall'
    foreach ($par in @(@("$SitioApi", $PuertoApi), @("$SitioPagina", $PuertoPagina))) {
        Get-NetFirewallRule -DisplayName $par[0] -ErrorAction SilentlyContinue | Remove-NetFirewallRule
        New-NetFirewallRule -DisplayName $par[0] -Direction Inbound -Protocol TCP -LocalPort $par[1] -Action Allow | Out-Null
        Ok "Puerto $($par[1]) abierto"
    }

    # ---- Verificacion ----
    Paso 8 'Verificacion'
    Start-Sleep 3
    $resultado = @()
    foreach ($u in @(@('API', "http://localhost:$PuertoApi/swagger/index.html"), @('Pagina', "http://localhost:$PuertoPagina/"))) {
        $code = 0
        try { $code = (Invoke-WebRequest $u[1] -UseBasicParsing -TimeoutSec 20).StatusCode } catch { if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode } }
        if ($code -gt 0 -and $code -lt 500) { Ok "$($u[0]) responde ($code)"; $resultado += $true } else { Falla "$($u[0]) no responde correctamente ($code)"; $resultado += $false }
    }
    $t = Test-NetConnection $IpNsx -Port 8010 -WarningAction SilentlyContinue
    if ($t.TcpTestSucceeded) { Ok "NSX escucha en $IpNsx`:8010" } else { Aviso "NSX no responde en $IpNsx`:8010 (abra NSX en ese equipo; el API da 'Error Envio Comando' hasta entonces)" }

    Write-Host ''
    Write-Host '=== RESUMEN ===' -ForegroundColor White
    Write-Host "API:     http://${ipPagina}:$PuertoApi/api"
    Write-Host "Pagina:  http://${ipPagina}:$PuertoPagina/"
    Write-Host "Carpeta: $Destino"
    Write-Host "Registro: $log"
    if ($resultado -contains $false) { Write-Host 'Terminado con errores: revise el registro.' -ForegroundColor Red } else { Write-Host 'Instalacion terminada.' -ForegroundColor Green }
}
catch {
    Falla $_.Exception.Message
    Write-Host "Registro: $log"
}
finally { }
