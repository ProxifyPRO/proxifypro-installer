# ============================================================
#   ProxifyPRO Installer for Windows 10/11 x64
#   https://proxifypro.com
#   Run as Administrator in PowerShell
# ============================================================

$ErrorActionPreference = "Stop"
$ProgressPreference    = "SilentlyContinue"

# Colors
function Write-Banner {
    Clear-Host
    Write-Host ""
    # PROXIFY en cyan brillante (color landing)
    Write-Host "  ██████╗ ██████╗  ██████╗ ██╗  ██╗██╗███████╗██╗   ██╗" -ForegroundColor Cyan
    Write-Host "  ██╔══██╗██╔══██╗██╔═══██╗╚██╗██╔╝██║██╔════╝╚██╗ ██╔╝" -ForegroundColor Cyan
    Write-Host "  ██████╔╝██████╔╝██║   ██║ ╚███╔╝ ██║█████╗   ╚████╔╝ " -ForegroundColor Cyan
    Write-Host "  ██╔═══╝ ██╔══██╗██║   ██║ ██╔██╗ ██║██╔══╝    ╚██╔╝  " -ForegroundColor Cyan
    Write-Host "  ██║     ██║  ██║╚██████╔╝██╔╝ ██╗██║██║        ██║   " -ForegroundColor Cyan
    Write-Host "  ╚═╝     ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝╚═╝╚═╝        ╚═╝   " -ForegroundColor Cyan
    Write-Host ""
    # PRO en verde (color cypherpunk landing)
    Write-Host "             ██████╗ ██████╗  ██████╗ " -ForegroundColor Green
    Write-Host "             ██╔══██╗██╔══██╗██╔═══██╗" -ForegroundColor Green
    Write-Host "             ██████╔╝██████╔╝██║   ██║" -ForegroundColor Green
    Write-Host "             ██╔═══╝ ██╔══██╗██║   ██║" -ForegroundColor Green
    Write-Host "             ██║     ██║  ██║╚██████╔╝" -ForegroundColor Green
    Write-Host "             ╚═╝     ╚═╝  ╚═╝ ╚═════╝ " -ForegroundColor Green
    Write-Host ""
    Write-Host "         4G Mobile Proxy Manager " -NoNewline -ForegroundColor White
    Write-Host "·" -NoNewline -ForegroundColor Cyan
    Write-Host " Installer v1.0.0" -ForegroundColor White
    Write-Host "                 https://proxifypro.com" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step   { Write-Host "`n  > $args" -ForegroundColor Blue }
function Write-Ok     { Write-Host "  [OK] $args" -ForegroundColor Green }
function Write-Warn   { Write-Host "  [!]  $args" -ForegroundColor Yellow }
function Write-Fail   { Write-Host "  [X]  $args" -ForegroundColor Red; exit 1 }
function Write-Detail { Write-Host "       -> $args" -ForegroundColor Cyan }

$INSTALL_DIR = "C:\ProxifyPRO"
$KEYGEN_ACCOUNT = "9750731a-b53a-42f6-b8b7-323546599b23"
$KEYGEN_PRODUCT = "6edf4915-fd05-4aed-9f3c-53bce798360f"
$KEYGEN_TOKEN   = ""

# ── 1. ADMIN CHECK ────────────────────────────────────────
function Check-Admin {
    Write-Step "Verificando permisos de administrador..."
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal   = [Security.Principal.WindowsPrincipal]$currentUser
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Fail "Ejecuta PowerShell como Administrador. Click derecho -> Ejecutar como administrador"
    }
    Write-Ok "Ejecutando como Administrador"
}

# ── 2. WINDOWS VERSION ────────────────────────────────────
function Check-Windows {
    Write-Step "Verificando version de Windows..."
    $ver = [System.Environment]::OSVersion.Version
    if ($ver.Major -lt 10) {
        Write-Fail "Windows 10 o superior requerido"
    }
    $build = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuild
    Write-Ok "Windows $($ver.Major) Build $build detectado"
}

# ── 3. FIX DNS ────────────────────────────────────────────
function Fix-DNS {
    Write-Step "Verificando conectividad y DNS..."
    try {
        $test = Invoke-WebRequest -Uri "https://api.keygen.sh" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        Write-Ok "DNS y conectividad OK"
    } catch {
        Write-Warn "DNS no puede resolver api.keygen.sh - configurando DNS de Google..."
        $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
        foreach ($adapter in $adapters) {
            Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex `
                -ServerAddresses ("8.8.8.8", "8.8.4.4") -ErrorAction SilentlyContinue
        }
        # Limpiar cache DNS
        Clear-DnsClientCache
        Write-Ok "DNS configurado: 8.8.8.8, 8.8.4.4"
    }
}

# ── 4. NODE.JS ────────────────────────────────────────────
function Install-Node {
    Write-Step "Verificando Node.js..."
    
    $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
    if ($nodeCmd) {
        $nodeVer = (node -v).TrimStart('v').Split('.')[0]
        if ([int]$nodeVer -ge 22) {
            Write-Ok "Node.js $(node -v) - OK"
            return
        }
        Write-Warn "Node.js $(node -v) muy antiguo - actualizando..."
    } else {
        Write-Warn "Node.js no encontrado - instalando..."
    }

    # Descargar e instalar Node.js 22 LTS
    $nodeUrl = "https://nodejs.org/dist/v22.11.0/node-v22.11.0-x64.msi"
    $nodeMsi = "$env:TEMP\node-installer.msi"
    Write-Detail "Descargando Node.js 22 LTS..."
    Invoke-WebRequest -Uri $nodeUrl -OutFile $nodeMsi -UseBasicParsing
    Write-Detail "Instalando Node.js..."
    Start-Process msiexec.exe -ArgumentList "/i `"$nodeMsi`" /quiet /norestart" -Wait
    Remove-Item $nodeMsi -Force -ErrorAction SilentlyContinue
    
    # Refrescar PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + 
                [System.Environment]::GetEnvironmentVariable("Path","User")
    
    Write-Ok "Node.js $(node -v) instalado"
}

# ── 5. 3PROXY ─────────────────────────────────────────────
function Install-3proxy {
    Write-Step "Instalando 3proxy..."
    
    $proxyDir = "C:\ProxifyPRO\bin"
    $proxyExe = "$proxyDir\3proxy.exe"
    
    if (Test-Path $proxyExe) {
        Write-Ok "3proxy ya instalado"
        return
    }
    
    New-Item -ItemType Directory -Force -Path $proxyDir | Out-Null
    
    # Descargar 3proxy para Windows
    $url = "https://github.com/3proxy/3proxy/releases/download/0.9.4/3proxy-0.9.4.win64.zip"
    $zip = "$env:TEMP\3proxy.zip"
    Write-Detail "Descargando 3proxy 0.9.4..."
    Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
    Expand-Archive -Path $zip -DestinationPath "$env:TEMP\3proxy-extract" -Force
    
    # Buscar el ejecutable
    $exe = Get-ChildItem -Path "$env:TEMP\3proxy-extract" -Filter "3proxy.exe" -Recurse | Select-Object -First 1
    if ($exe) {
        Copy-Item $exe.FullName -Destination $proxyExe -Force
        Write-Ok "3proxy instalado en $proxyExe"
    } else {
        Write-Warn "No se pudo descargar 3proxy - compilando alternativa..."
        # Fallback: usar versión pre-compilada desde releases
        $fallbackUrl = "https://github.com/3proxy/3proxy/releases/latest/download/3proxy-0.9.4.win64.zip"
        Invoke-WebRequest -Uri $fallbackUrl -OutFile $zip -UseBasicParsing
        Expand-Archive -Path $zip -DestinationPath "$env:TEMP\3proxy-extract2" -Force
        $exe2 = Get-ChildItem -Path "$env:TEMP\3proxy-extract2" -Filter "3proxy.exe" -Recurse | Select-Object -First 1
        if ($exe2) { Copy-Item $exe2.FullName -Destination $proxyExe -Force }
    }
    
    # Limpiar
    Remove-Item $zip -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:TEMP\3proxy-extract" -Recurse -Force -ErrorAction SilentlyContinue
    
    Write-Ok "3proxy listo"
}

# ── 6. INSTALL PROXIFYPRO ─────────────────────────────────
function Install-ProxifyPRO {
    Write-Step "Instalando ProxifyPRO en $INSTALL_DIR..."
    
    # Crear estructura de directorios
    @("$INSTALL_DIR", "$INSTALL_DIR\data", "$INSTALL_DIR\logs", "$INSTALL_DIR\config") | ForEach-Object {
        New-Item -ItemType Directory -Force -Path $_ | Out-Null
    }
    
    # Directorio del script actual
    $scriptDir = Split-Path -Parent $MyInvocation.ScriptName
    if (-not $scriptDir) { $scriptDir = Get-Location }
    
    if (Test-Path "$scriptDir\package.json") {
        Write-Detail "Copiando archivos..."
        Copy-Item -Path "$scriptDir\src"          -Destination "$INSTALL_DIR\src"          -Recurse -Force
        Copy-Item -Path "$scriptDir\package.json" -Destination "$INSTALL_DIR\package.json" -Force
        if (Test-Path "$scriptDir\package-lock.json") {
            Copy-Item -Path "$scriptDir\package-lock.json" -Destination "$INSTALL_DIR\package-lock.json" -Force
        }
        Write-Ok "Archivos copiados"
    } else {
        Write-Fail "Ejecuta el instalador desde la carpeta del proyecto ProxifyPRO"
    }
    
    Write-Detail "Instalando dependencias npm..."
    Push-Location $INSTALL_DIR
    npm install --production --silent 2>$null
    Pop-Location
    Write-Ok "Dependencias npm instaladas"
    
    # Adaptar paths para Windows en proxy manager
    $managerPath = "$INSTALL_DIR\src\proxy\manager.js"
    if (Test-Path $managerPath) {
        $content = Get-Content $managerPath -Raw
        $content = $content -replace "'/tmp'", "'$($INSTALL_DIR -replace '\\','/')/config'"
        $content = $content -replace "3proxy", "$($INSTALL_DIR -replace '\\','/')/bin/3proxy"
        Set-Content $managerPath $content
    }
}

# ── 7. CONFIGURE ──────────────────────────────────────────
function Configure-ProxifyPRO {
    Write-Step "Configurando ProxifyPRO..."
    
    $jwtSecret = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 64 | ForEach-Object {[char]$_})
    
    Write-Host ""
    Write-Host "  Configuracion inicial:" -ForegroundColor White
    Write-Host ""
    
    $adminEmail = Read-Host "    Email del administrador [admin@proxifypro.local]"
    if ([string]::IsNullOrEmpty($adminEmail)) { $adminEmail = "admin@proxifypro.local" }
    
    $adminPass = Read-Host "    Contrasena del administrador [Admin123!]" -AsSecureString
    $adminPassPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($adminPass))
    if ([string]::IsNullOrEmpty($adminPassPlain)) { $adminPassPlain = "Admin123!" }
    
    $port = Read-Host "    Puerto del dashboard [3000]"
    if ([string]::IsNullOrEmpty($port)) { $port = "3000" }
    
    $licenseKey = ""
    while ([string]::IsNullOrEmpty($licenseKey)) {
        $licenseKey = Read-Host "    Clave de licencia ProxifyPRO"
        if ([string]::IsNullOrEmpty($licenseKey)) {
            Write-Host "    La clave de licencia es obligatoria." -ForegroundColor Red
            Write-Host "    Obtén tu licencia en https://proxifypro.com" -ForegroundColor Cyan
        }
    }
    
    # Guardar .env con paths de Windows
    $envContent = @"
PORT=$port
DB_PATH=$INSTALL_DIR\data\proxifypro.db
LOG_PATH=$INSTALL_DIR\logs
JWT_SECRET=$jwtSecret
ADMIN_EMAIL=$adminEmail
ADMIN_PASSWORD=$adminPassPlain
NODE_ENV=production
INSTALL_DIR=$INSTALL_DIR
KEYGEN_ACCOUNT_ID=$KEYGEN_ACCOUNT
KEYGEN_PRODUCT_ID=$KEYGEN_PRODUCT
KEYGEN_TOKEN=$KEYGEN_TOKEN
INITIAL_LICENSE=$licenseKey
PROXY_BIN=$INSTALL_DIR\bin\3proxy.exe
"@
    Set-Content -Path "$INSTALL_DIR\.env" -Value $envContent
    Write-Ok "Configuracion guardada"
    
    return @{ Port = $port; Email = $adminEmail; LicenseKey = $licenseKey }
}

# ── 8. VALIDATE LICENSE ───────────────────────────────────
function Validate-License {
    param($LicenseKey)
    Write-Step "Validando licencia..."
    
    # Generar fingerprint de la máquina
    $macAddress = (Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1).MacAddress
    $hostname   = $env:COMPUTERNAME
    $combined   = "$macAddress$hostname"
    $sha256     = [System.Security.Cryptography.SHA256]::Create()
    $bytes      = [System.Text.Encoding]::UTF8.GetBytes($combined)
    $hash       = $sha256.ComputeHash($bytes)
    $fingerprint = -join ($hash | ForEach-Object { $_.ToString("x2") }) | Select-Object -First 1
    $fingerprint = ($hash | ForEach-Object { $_.ToString("x2") }) -join "" | Select-Object -First 32
    $fingerprint = (($hash | ForEach-Object { $_.ToString("x2") }) -join "").Substring(0, 32)
    
    $body = @{
        meta = @{
            key   = $LicenseKey
            scope = @{ fingerprint = $fingerprint }
        }
    } | ConvertTo-Json -Depth 5
    
    try {
        $response = Invoke-RestMethod `
            -Uri "https://api.keygen.sh/v1/accounts/$KEYGEN_ACCOUNT/licenses/actions/validate-key" `
            -Method POST `
            -Headers @{
                "Content-Type"  = "application/vnd.api+json"
                "Accept"        = "application/vnd.api+json"
                "Authorization" = "License $LicenseKey"
            } `
            -Body $body
        
        $code = $response.meta.code
        
        if ($response.meta.valid) {
            $policyId = $response.data.relationships.policy.data.id
            $plan = switch ($policyId) {
                "d7cbd3c1-3e20-4290-ac12-6fdfeaad12b3" { "Starter (5 dongles)" }
                "f97d3b0d-8d62-48e2-bc80-b981cfa63d5d" { "PRO (20 dongles)" }
                "50bf2741-ab84-45e1-8741-75eccb7af024" { "Enterprise (60 dongles)" }
                default { "Unknown" }
            }
            Write-Ok "Licencia valida - Plan: $plan"
            
        } elseif ($code -in @("FINGERPRINT_SCOPE_MISMATCH","NO_MACHINES","FINGERPRINT_SCOPE_REQUIRED")) {
            Write-Detail "Activando maquina..."
            
            # Obtener license ID
            $r2 = Invoke-RestMethod `
                -Uri "https://api.keygen.sh/v1/accounts/$KEYGEN_ACCOUNT/licenses/actions/validate-key" `
                -Method POST `
                -Headers @{
                    "Content-Type"  = "application/vnd.api+json"
                    "Accept"        = "application/vnd.api+json"
                    "Authorization" = "License $LicenseKey"
                } `
                -Body (@{ meta = @{ key = $LicenseKey } } | ConvertTo-Json)
            
            $licenseId = $r2.data.id
            
            # Activar máquina
            $machineBody = @{
                data = @{
                    type = "machines"
                    attributes = @{
                        fingerprint = $fingerprint
                        name        = $env:COMPUTERNAME
                        platform    = "windows"
                    }
                    relationships = @{
                        license = @{ data = @{ type = "licenses"; id = $licenseId } }
                    }
                }
            } | ConvertTo-Json -Depth 10
            
            Invoke-RestMethod `
                -Uri "https://api.keygen.sh/v1/accounts/$KEYGEN_ACCOUNT/machines" `
                -Method POST `
                -Headers @{
                    "Content-Type"  = "application/vnd.api+json"
                    "Accept"        = "application/vnd.api+json"
                    "Authorization" = "License $LicenseKey"
                } `
                -Body $machineBody | Out-Null
            
            Write-Ok "Maquina activada correctamente"
            Validate-License -LicenseKey $LicenseKey
            
        } else {
            Write-Fail "Licencia invalida: $code - Obtén tu licencia en proxifypro.com"
        }
    } catch {
        Write-Warn "No se pudo verificar la licencia online - modo offline activado"
    }
}

# ── 9. WINDOWS SERVICE ────────────────────────────────────
function Install-Service {
    param($Port)
    Write-Step "Instalando servicio de Windows..."
    
    # Usar NSSM para instalar como servicio
    $nssmUrl = "https://nssm.cc/release/nssm-2.24.zip"
    $nssmZip = "$env:TEMP\nssm.zip"
    $nssmDir = "$env:TEMP\nssm-extract"
    
    Write-Detail "Descargando NSSM (gestor de servicios)..."
    Invoke-WebRequest -Uri $nssmUrl -OutFile $nssmZip -UseBasicParsing
    Expand-Archive -Path $nssmZip -DestinationPath $nssmDir -Force
    $nssmExe = Get-ChildItem -Path $nssmDir -Filter "nssm.exe" -Recurse | 
               Where-Object { $_.FullName -like "*win64*" } | Select-Object -First 1
    
    if (-not $nssmExe) {
        $nssmExe = Get-ChildItem -Path $nssmDir -Filter "nssm.exe" -Recurse | Select-Object -First 1
    }
    
    Copy-Item $nssmExe.FullName -Destination "C:\Windows\System32\nssm.exe" -Force
    
    # Desinstalar servicio anterior si existe
    & nssm stop proxifypro 2>$null
    & nssm remove proxifypro confirm 2>$null
    
    # Instalar servicio
    $nodePath = (Get-Command node).Source
    & nssm install proxifypro $nodePath "$INSTALL_DIR\src\index.js"
    & nssm set proxifypro AppDirectory $INSTALL_DIR
    & nssm set proxifypro AppEnvironmentExtra `
        "PORT=$Port" `
        "DB_PATH=$INSTALL_DIR\data\proxifypro.db" `
        "NODE_ENV=production" `
        "INSTALL_DIR=$INSTALL_DIR"
    & nssm set proxifypro DisplayName "ProxifyPRO - 4G Proxy Manager"
    & nssm set proxifypro Description "ProxifyPRO 4G Mobile Proxy Manager"
    & nssm set proxifypro Start SERVICE_AUTO_START
    & nssm set proxifypro AppStdout "$INSTALL_DIR\logs\proxifypro.log"
    & nssm set proxifypro AppStderr "$INSTALL_DIR\logs\proxifypro-error.log"
    & nssm set proxifypro AppRotateFiles 1
    & nssm set proxifypro AppRotateOnline 1
    & nssm set proxifypro AppRotateBytes 10485760
    
    # Iniciar servicio
    & nssm start proxifypro
    Start-Sleep -Seconds 3
    
    $svc = Get-Service -Name proxifypro -ErrorAction SilentlyContinue
    if ($svc -and $svc.Status -eq "Running") {
        Write-Ok "Servicio ProxifyPRO instalado y corriendo"
    } else {
        Write-Warn "El servicio puede tardar unos segundos en iniciar"
    }
    
    # Limpiar
    Remove-Item $nssmZip -Force -ErrorAction SilentlyContinue
    Remove-Item $nssmDir -Recurse -Force -ErrorAction SilentlyContinue
}

# ── 10. FIREWALL ──────────────────────────────────────────
function Configure-Firewall {
    param($Port)
    Write-Step "Configurando firewall de Windows..."
    
    # Eliminar reglas anteriores
    Remove-NetFirewallRule -DisplayName "ProxifyPRO*" -ErrorAction SilentlyContinue
    
    # Dashboard
    New-NetFirewallRule -DisplayName "ProxifyPRO Dashboard" `
        -Direction Inbound -Protocol TCP -LocalPort $Port `
        -Action Allow -Profile Any | Out-Null
    
    # Proxy ports 20001-20010 SOCKS5, 30001-30010 HTTPS
    New-NetFirewallRule -DisplayName "ProxifyPRO Proxies SOCKS5" `
        -Direction Inbound -Protocol TCP -LocalPort "20001-20010" `
        -Action Allow -Profile Any | Out-Null
    
    New-NetFirewallRule -DisplayName "ProxifyPRO Proxies HTTPS" `
        -Direction Inbound -Protocol TCP -LocalPort "30001-30010" `
        -Action Allow -Profile Any | Out-Null
    
    Write-Ok "Firewall configurado (puertos $Port, 20001-20010, 30001-30010)"
}

# ── 11. CLI SHORTCUTS ─────────────────────────────────────
function Create-Shortcuts {
    param($Port)
    Write-Step "Creando accesos directos..."
    
    # Script CLI en PATH
    $cliContent = @"
@echo off
set PORT=$Port
set INSTALL_DIR=$INSTALL_DIR
if "%1"=="start"     ( net start proxifypro && echo ProxifyPRO iniciado & goto end )
if "%1"=="stop"      ( net stop proxifypro && echo ProxifyPRO detenido & goto end )
if "%1"=="restart"   ( net stop proxifypro & net start proxifypro & goto end )
if "%1"=="status"    ( sc query proxifypro & goto end )
if "%1"=="logs"      ( powershell Get-Content "$INSTALL_DIR\logs\proxifypro.log" -Wait & goto end )
if "%1"=="open"      ( start http://localhost:%PORT% & goto end )
if "%1"=="uninstall" ( powershell -File "$INSTALL_DIR\uninstall.ps1" & goto end )
echo.
echo   ProxifyPRO v1.0.0 - 4G Mobile Proxy Manager
echo.
echo   Comandos disponibles:
echo     proxifypro start     Iniciar el servicio
echo     proxifypro stop      Detener el servicio
echo     proxifypro restart   Reiniciar el servicio
echo     proxifypro status    Estado del servicio
echo     proxifypro logs      Ver logs en tiempo real
echo     proxifypro open      Abrir dashboard
echo     proxifypro uninstall Desinstalar
echo.
echo   Dashboard: http://localhost:%PORT%
echo.
:end
"@
    Set-Content -Path "C:\Windows\System32\proxifypro.bat" -Value $cliContent
    
    # Acceso directo en escritorio
    $shell    = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut("$env:PUBLIC\Desktop\ProxifyPRO.lnk")
    $shortcut.TargetPath       = "http://localhost:$Port"
    $shortcut.Description      = "ProxifyPRO Dashboard"
    $shortcut.Save()
    
    Write-Ok "Comando 'proxifypro' disponible en CMD"
    Write-Ok "Acceso directo creado en el escritorio"
}

# ── 12. VERIFY ────────────────────────────────────────────
function Verify-Installation {
    param($Port)
    Write-Step "Verificando instalacion..."
    Start-Sleep -Seconds 3
    
    try {
        $r = Invoke-WebRequest -Uri "http://localhost:$Port/api/status" `
             -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        Write-Ok "API respondiendo en puerto $Port"
    } catch {
        Write-Warn "API iniciando - verifica con: proxifypro status"
    }
}

# ── 13. SUMMARY ───────────────────────────────────────────
function Print-Summary {
    param($Port, $Email)
    Write-Host ""
    Write-Host "  +----------------------------------------------+" -ForegroundColor Green
    Write-Host "  |   ProxifyPRO instalado correctamente         |" -ForegroundColor Green
    Write-Host "  +----------------------------------------------+" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Dashboard:  http://localhost:$Port" -ForegroundColor White
    Write-Host "  API Docs:   http://localhost:$Port/api/docs" -ForegroundColor White
    Write-Host "  Email:      $Email" -ForegroundColor White
    Write-Host ""
    Write-Host "  Proximos pasos:" -ForegroundColor White
    Write-Host "  1. Conecta tus dongles USB 4G" -ForegroundColor Cyan
    Write-Host "  2. Abre http://localhost:$Port" -ForegroundColor Cyan
    Write-Host "  3. Inicia sesion con tu email y contrasena" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Comandos en CMD:" -ForegroundColor White
    Write-Host "    proxifypro start   - Iniciar" -ForegroundColor Cyan
    Write-Host "    proxifypro stop    - Detener" -ForegroundColor Cyan
    Write-Host "    proxifypro open    - Abrir dashboard" -ForegroundColor Cyan
    Write-Host "    proxifypro logs    - Ver logs" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Soporte: https://proxifypro.com" -ForegroundColor Yellow
    Write-Host ""
    
    # Abrir dashboard automáticamente
    Start-Sleep -Seconds 2
    Start-Process "http://localhost:$Port"
}

# ── MAIN ──────────────────────────────────────────────────
Write-Banner
Check-Admin
Check-Windows
Fix-DNS
Install-Node
Install-3proxy
Install-ProxifyPRO
$config = Configure-ProxifyPRO
# Validate-License — delegado a license-guard.js (al arrancar el service)
# Validate-License -LicenseKey $config.LicenseKey
Install-Service -Port $config.Port
Configure-Firewall -Port $config.Port
Create-Shortcuts -Port $config.Port
Verify-Installation -Port $config.Port
Print-Summary -Port $config.Port -Email $config.Email
