#!/bin/bash
set -e

# ============================================================
#   ProxifyPRO Installer for macOS
#   https://proxifypro.com
#   Compatible: macOS 12 Monterey, 13 Ventura, 14 Sonoma
#   Architecture: Intel x64 + Apple Silicon (M1/M2/M3)
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

INSTALL_DIR="$HOME/.proxifypro"
SERVICE_NAME="com.proxifypro.app"
NODE_MIN=22
PROXIFYPRO_VERSION="1.0.0"

KEYGEN_ACCOUNT="9750731a-b53a-42f6-b8b7-323546599b23"
KEYGEN_PRODUCT="6edf4915-fd05-4aed-9f3c-53bce798360f"
KEYGEN_TOKEN="activ-1c1033e67aa81e4a3aae0d7bc5f0c74dv3"

print_banner() {
  clear 2>/dev/null || true
  echo ""
  # PROXIFY en cyan brillante (color landing)
  echo -e "${CYAN}"
  cat << 'BANNER'
  ██████╗ ██████╗  ██████╗ ██╗  ██╗██╗███████╗██╗   ██╗
  ██╔══██╗██╔══██╗██╔═══██╗╚██╗██╔╝██║██╔════╝╚██╗ ██╔╝
  ██████╔╝██████╔╝██║   ██║ ╚███╔╝ ██║█████╗   ╚████╔╝ 
  ██╔═══╝ ██╔══██╗██║   ██║ ██╔██╗ ██║██╔══╝    ╚██╔╝  
  ██║     ██║  ██║╚██████╔╝██╔╝ ██╗██║██║        ██║   
  ╚═╝     ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝╚═╝╚═╝        ╚═╝   
BANNER
  # PRO en verde (color cypherpunk landing)
  echo -e "${GREEN}"
  cat << 'BANNER'
             ██████╗ ██████╗  ██████╗ 
             ██╔══██╗██╔══██╗██╔═══██╗
             ██████╔╝██████╔╝██║   ██║
             ██╔═══╝ ██╔══██╗██║   ██║
             ██║     ██║  ██║╚██████╔╝
             ╚═╝     ╚═╝  ╚═╝ ╚═════╝ 
BANNER
  echo -e "${NC}"
  echo -e "         ${BOLD}4G Mobile Proxy Manager${NC} ${CYAN}·${NC} Installer v${PROXIFYPRO_VERSION}"
  echo -e "                 ${CYAN}https://proxifypro.com${NC}"
  echo ""
}

log_step()   { echo -e "\n  ${BLUE}▶${NC} ${BOLD}$1${NC}"; }
log_ok()     { echo -e "  ${GREEN}✓${NC} $1"; }
log_warn()   { echo -e "  ${YELLOW}⚠${NC} $1"; }
log_error()  { echo -e "  ${RED}✗${NC} $1"; }
log_detail() { echo -e "    ${CYAN}→${NC} $1"; }

die() { log_error "$1"; exit 1; }

# ── 1. MACOS CHECK ────────────────────────────────────────
check_macos() {
  log_step "Detectando sistema..."
  
  # Verificar macOS
  if [[ "$OSTYPE" != "darwin"* ]]; then
    die "Este instalador es solo para macOS"
  fi
  
  # Version
  MACOS_VER=$(sw_vers -productVersion)
  MACOS_MAJOR=$(echo "$MACOS_VER" | cut -d. -f1)
  if [ "$MACOS_MAJOR" -lt 12 ]; then
    die "macOS 12 Monterey o superior requerido. Tienes: $MACOS_VER"
  fi
  log_ok "macOS $MACOS_VER detectado"
  
  # Arquitectura
  ARCH=$(uname -m)
  if [ "$ARCH" = "arm64" ]; then
    log_ok "Apple Silicon (M1/M2/M3) detectado"
    IS_APPLE_SILICON=true
  else
    log_ok "Intel x64 detectado"
    IS_APPLE_SILICON=false
  fi
}

# ── 2. FIX DNS ────────────────────────────────────────────
fix_dns() {
  log_step "Verificando conectividad y DNS..."
  
  if ! curl -s --max-time 5 https://google.com > /dev/null 2>&1; then
    die "Sin conexión a internet. Verifica tu red y reintenta."
  fi
  
  if ! curl -s --max-time 5 https://api.keygen.sh > /dev/null 2>&1; then
    log_warn "DNS no puede resolver api.keygen.sh — corrigiendo..."
    # Configurar DNS via networksetup
    INTERFACE=$(route -n get default 2>/dev/null | grep interface | awk '{print $2}')
    if [ -n "$INTERFACE" ]; then
      NETWORK_SERVICE=$(networksetup -listallhardwareports | grep -A1 "$INTERFACE" | grep "Hardware Port" | sed 's/Hardware Port: //')
      if [ -n "$NETWORK_SERVICE" ]; then
        networksetup -setdnsservers "$NETWORK_SERVICE" 8.8.8.8 8.8.4.4 1.1.1.1
        dscacheutil -flushcache
        killall -HUP mDNSResponder 2>/dev/null || true
        log_ok "DNS configurado: 8.8.8.8, 8.8.4.4, 1.1.1.1"
      fi
    fi
  else
    log_ok "DNS y conectividad OK"
  fi
}

# ── 3. XCODE TOOLS ────────────────────────────────────────
install_xcode_tools() {
  log_step "Verificando herramientas de desarrollo..."
  if xcode-select -p &>/dev/null; then
    log_ok "Xcode Command Line Tools ya instalado"
  else
    log_warn "Instalando Xcode Command Line Tools..."
    xcode-select --install 2>/dev/null || true
    echo ""
    echo -e "    ${YELLOW}Se abrirá un diálogo para instalar las herramientas de desarrollo.${NC}"
    echo -e "    ${YELLOW}Acepta la instalación y vuelve a ejecutar este script.${NC}"
    echo ""
    read -p "    Presiona Enter cuando la instalación haya terminado..."
  fi
}

# ── 4. HOMEBREW ───────────────────────────────────────────
install_homebrew() {
  log_step "Verificando Homebrew..."
  if command -v brew &>/dev/null; then
    log_ok "Homebrew $(brew --version | head -1 | awk '{print $2}') instalado"
    # Actualizar silenciosamente
    brew update --quiet 2>/dev/null || true
  else
    log_warn "Homebrew no encontrado — instalando..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Agregar al PATH para Apple Silicon
    if [ "$IS_APPLE_SILICON" = true ]; then
      echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
      eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
    log_ok "Homebrew instalado"
  fi
}

# ── 5. NODE.JS ────────────────────────────────────────────
install_node() {
  log_step "Verificando Node.js..."
  if command -v node &>/dev/null; then
    VER=$(node -v | cut -dv -f2 | cut -d. -f1)
    if [ "$VER" -ge "$NODE_MIN" ]; then
      log_ok "Node.js $(node -v) — OK"
      return
    fi
    log_warn "Node.js $(node -v) muy antiguo — actualizando..."
  else
    log_warn "Node.js no encontrado — instalando..."
  fi
  
  brew install node@22 --quiet 2>/dev/null
  brew link node@22 --force --quiet 2>/dev/null || true
  
  # Agregar al PATH
  if [ "$IS_APPLE_SILICON" = true ]; then
    export PATH="/opt/homebrew/opt/node@22/bin:$PATH"
  else
    export PATH="/usr/local/opt/node@22/bin:$PATH"
  fi
  
  log_ok "Node.js $(node -v) instalado"
}

# ── 6. 3PROXY ─────────────────────────────────────────────
install_3proxy() {
  log_step "Instalando 3proxy..."
  
  if command -v 3proxy &>/dev/null; then
    log_ok "3proxy ya instalado"
    return
  fi
  
  # Intentar via Homebrew
  brew install 3proxy --quiet 2>/dev/null && log_ok "3proxy instalado via Homebrew" && return
  
  # Compilar desde fuente
  log_detail "Compilando 3proxy desde fuente..."
  cd /tmp
  curl -fsSL https://github.com/3proxy/3proxy/archive/refs/tags/0.9.4.tar.gz -o 3proxy.tar.gz
  tar xzf 3proxy.tar.gz
  cd 3proxy-0.9.4
  make -f Makefile.Mac 2>/dev/null || make 2>/dev/null
  cp bin/3proxy /usr/local/bin/3proxy
  chmod +x /usr/local/bin/3proxy
  cd ~
  rm -rf /tmp/3proxy*
  log_ok "3proxy compilado e instalado"
}

# ── 7. INSTALL PROXIFYPRO ─────────────────────────────────
install_proxifypro() {
  log_step "Instalando ProxifyPRO en $INSTALL_DIR..."
  
  mkdir -p "$INSTALL_DIR"/{data,logs,config,bin}
  
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  
  if [ -f "$SCRIPT_DIR/package.json" ]; then
    log_detail "Copiando archivos..."
    cp -r "$SCRIPT_DIR/src"          "$INSTALL_DIR/"
    cp    "$SCRIPT_DIR/package.json" "$INSTALL_DIR/"
    cp    "$SCRIPT_DIR/package-lock.json" "$INSTALL_DIR/" 2>/dev/null || true
    log_ok "Archivos copiados"
  else
    die "Ejecuta el instalador desde la carpeta del proyecto ProxifyPRO"
  fi
  
  log_detail "Instalando dependencias npm..."
  cd "$INSTALL_DIR"
  npm install --production --silent 2>/dev/null
  log_ok "Dependencias npm instaladas"
}

# ── 8. CONFIGURE ──────────────────────────────────────────
configure() {
  log_step "Configurando ProxifyPRO..."
  
  JWT_SECRET=$(node -e "console.log(require('crypto').randomBytes(32).toString('hex'))")
  
  echo ""
  echo -e "  ${BOLD}Configuración inicial:${NC}"
  echo ""
  
  read -p "    Email del administrador [admin@proxifypro.local]: " ADMIN_EMAIL
  ADMIN_EMAIL=${ADMIN_EMAIL:-admin@proxifypro.local}
  
  read -s -p "    Contraseña del administrador [Admin123!]: " ADMIN_PASS
  echo ""
  ADMIN_PASS=${ADMIN_PASS:-Admin123!}
  
  read -p "    Puerto del dashboard [3000]: " PORT
  PORT=${PORT:-3000}
  
  LICENSE_KEY=""
  while [ -z "$LICENSE_KEY" ]; do
    read -p "    Clave de licencia ProxifyPRO: " LICENSE_KEY
    if [ -z "$LICENSE_KEY" ]; then
      echo -e "    ${RED}La clave de licencia es obligatoria.${NC}"
      echo -e "    ${CYAN}Obtén tu licencia en https://proxifypro.com${NC}"
    fi
  done
  
  cat > "$INSTALL_DIR/.env" << ENV
PORT=$PORT
DB_PATH=$INSTALL_DIR/data/proxifypro.db
LOG_PATH=$INSTALL_DIR/logs
JWT_SECRET=$JWT_SECRET
ADMIN_EMAIL=$ADMIN_EMAIL
ADMIN_PASSWORD=$ADMIN_PASS
NODE_ENV=production
INSTALL_DIR=$INSTALL_DIR
KEYGEN_ACCOUNT_ID=$KEYGEN_ACCOUNT
KEYGEN_PRODUCT_ID=$KEYGEN_PRODUCT
KEYGEN_TOKEN=$KEYGEN_TOKEN
INITIAL_LICENSE=$LICENSE_KEY
ENV
  
  log_ok "Configuración guardada"
}

# ── 9. VALIDATE LICENSE ───────────────────────────────────
validate_license() {
  log_step "Validando licencia..."
  
  LICENSE_KEY=$(grep "^LICENSE_KEY=" "$INSTALL_DIR/.env" | cut -d= -f2)
  
  FINGERPRINT=$(node -e "
    const {execSync}=require('child_process');
    const crypto=require('crypto');
    try {
      const mac=execSync('ifconfig en0 | grep ether | awk \"{print \\\$2}\"').toString().trim();
      const host=execSync('hostname').toString().trim();
      console.log(crypto.createHash('sha256').update(mac+host).digest('hex').substring(0,32));
    } catch(e){ console.log(crypto.randomBytes(16).toString('hex')); }
  ")
  
  RESPONSE=$(curl -s -X POST \
    "https://api.keygen.sh/v1/accounts/$KEYGEN_ACCOUNT/licenses/actions/validate-key" \
    -H "Content-Type: application/vnd.api+json" \
    -H "Accept: application/vnd.api+json" \
    -H "Authorization: License $LICENSE_KEY" \
    -d "{\"meta\":{\"key\":\"$LICENSE_KEY\",\"scope\":{\"fingerprint\":\"$FINGERPRINT\"}}}")
  
  VALID=$(echo "$RESPONSE" | node -e "
    let d='';
    process.stdin.on('data',c=>d+=c);
    process.stdin.on('end',()=>{
      try{
        const r=JSON.parse(d);
        const code=r.meta?.code;
        if(r.meta?.valid){ console.log('VALID:'+r.data?.relationships?.policy?.data?.id); }
        else if(['FINGERPRINT_SCOPE_MISMATCH','NO_MACHINES','FINGERPRINT_SCOPE_REQUIRED'].includes(code)){ console.log('ACTIVATE'); }
        else { console.log('INVALID:'+(r.errors?.[0]?.detail||code||'unknown')); }
      }catch(e){ console.log('ERROR:'+e.message); }
    });
  ")
  
  if [[ "$VALID" == VALID:* ]]; then
    POLICY_ID="${VALID#VALID:}"
    if [ "$POLICY_ID" = "d7cbd3c1-3e20-4290-ac12-6fdfeaad12b3" ]; then PLAN="Starter (5 dongles)";
    elif [ "$POLICY_ID" = "f97d3b0d-8d62-48e2-bc80-b981cfa63d5d" ]; then PLAN="PRO (20 dongles)";
    elif [ "$POLICY_ID" = "50bf2741-ab84-45e1-8741-75eccb7af024" ]; then PLAN="Enterprise (60 dongles)";
    else PLAN="Unknown"; fi
    log_ok "Licencia válida — Plan: ${BOLD}$PLAN${NC}"
    
  elif [ "$VALID" = "ACTIVATE" ]; then
    log_detail "Activando máquina..."
    LICENSE_ID=$(curl -s -X POST \
      "https://api.keygen.sh/v1/accounts/$KEYGEN_ACCOUNT/licenses/actions/validate-key" \
      -H "Content-Type: application/vnd.api+json" \
      -H "Accept: application/vnd.api+json" \
      -H "Authorization: License $LICENSE_KEY" \
      -d "{\"meta\":{\"key\":\"$LICENSE_KEY\"}}" | \
      node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{console.log(JSON.parse(d).data?.id||'')}catch(e){}})")
    
    if [ -n "$LICENSE_ID" ]; then
      HOSTNAME=$(hostname)
      curl -s -X POST \
        "https://api.keygen.sh/v1/accounts/$KEYGEN_ACCOUNT/machines" \
        -H "Content-Type: application/vnd.api+json" \
        -H "Accept: application/vnd.api+json" \
        -H "Authorization: License $LICENSE_KEY" \
        -d "{\"data\":{\"type\":\"machines\",\"attributes\":{\"fingerprint\":\"$FINGERPRINT\",\"name\":\"$HOSTNAME\",\"platform\":\"macos\"},\"relationships\":{\"license\":{\"data\":{\"type\":\"licenses\",\"id\":\"$LICENSE_ID\"}}}}}" > /dev/null
      log_ok "Máquina activada correctamente"
      validate_license
      return
    fi
    die "No se pudo activar la licencia. Contacta soporte en proxifypro.com"
    
  elif [[ "$VALID" == INVALID:* ]]; then
    die "Licencia inválida: ${VALID#INVALID:}"
  else
    log_warn "No se pudo verificar la licencia — modo offline activado"
  fi
}

# ── 10. LAUNCHD SERVICE ───────────────────────────────────
setup_service() {
  log_step "Configurando servicio del sistema (launchd)..."
  
  PORT=$(grep "^PORT=" "$INSTALL_DIR/.env" | cut -d= -f2)
  NODE_PATH=$(which node)
  PLIST_DIR="$HOME/Library/LaunchAgents"
  PLIST_FILE="$PLIST_DIR/$SERVICE_NAME.plist"
  
  mkdir -p "$PLIST_DIR"
  
  # Detener servicio anterior si existe
  launchctl unload "$PLIST_FILE" 2>/dev/null || true
  
  cat > "$PLIST_FILE" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$SERVICE_NAME</string>
  <key>ProgramArguments</key>
  <array>
    <string>$NODE_PATH</string>
    <string>$INSTALL_DIR/src/index.js</string>
  </array>
  <key>WorkingDirectory</key>
  <string>$INSTALL_DIR</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PORT</key>
    <string>$PORT</string>
    <key>DB_PATH</key>
    <string>$INSTALL_DIR/data/proxifypro.db</string>
    <key>LOG_PATH</key>
    <string>$INSTALL_DIR/logs</string>
    <key>NODE_ENV</key>
    <string>production</string>
    <key>INSTALL_DIR</key>
    <string>$INSTALL_DIR</string>
  </dict>
  <key>StandardOutPath</key>
  <string>$INSTALL_DIR/logs/proxifypro.log</string>
  <key>StandardErrorPath</key>
  <string>$INSTALL_DIR/logs/proxifypro-error.log</string>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>ThrottleInterval</key>
  <integer>10</integer>
</dict>
</plist>
PLIST
  
  # Cargar el servicio
  launchctl load "$PLIST_FILE"
  sleep 3
  
  if launchctl list | grep -q "$SERVICE_NAME"; then
    log_ok "Servicio launchd instalado y activo"
  else
    log_warn "El servicio puede tardar unos segundos — verifica con: proxifypro status"
  fi
}

# ── 11. CLI ───────────────────────────────────────────────
create_cli() {
  log_step "Creando comando CLI..."
  
  PORT=$(grep "^PORT=" "$INSTALL_DIR/.env" | cut -d= -f2)
  
  cat > /usr/local/bin/proxifypro << CLIEOF
#!/bin/bash
INSTALL_DIR="$INSTALL_DIR"
SERVICE="$SERVICE_NAME"
PORT="$PORT"

case "\$1" in
  start)
    launchctl load "\$HOME/Library/LaunchAgents/\$SERVICE.plist" 2>/dev/null
    launchctl start "\$SERVICE"
    echo -e "\033[0;32m✓\033[0m ProxifyPRO iniciado → http://localhost:\$PORT"
    ;;
  stop)
    launchctl stop "\$SERVICE"
    echo -e "\033[0;32m✓\033[0m ProxifyPRO detenido"
    ;;
  restart)
    launchctl stop "\$SERVICE"
    sleep 2
    launchctl start "\$SERVICE"
    echo -e "\033[0;32m✓\033[0m ProxifyPRO reiniciado → http://localhost:\$PORT"
    ;;
  status)
    if launchctl list | grep -q "\$SERVICE"; then
      echo -e "\033[0;32m✓\033[0m ProxifyPRO corriendo → http://localhost:\$PORT"
    else
      echo -e "\033[0;31m✗\033[0m ProxifyPRO detenido"
    fi
    ;;
  logs)
    tail -f "\$INSTALL_DIR/logs/proxifypro.log"
    ;;
  errors)
    tail -f "\$INSTALL_DIR/logs/proxifypro-error.log"
    ;;
  open)
    open "http://localhost:\$PORT"
    ;;
  uninstall)
    read -p "¿Desinstalar ProxifyPRO? [s/N]: " confirm
    if [ "\$confirm" = "s" ] || [ "\$confirm" = "S" ]; then
      launchctl stop "\$SERVICE" 2>/dev/null
      launchctl unload "\$HOME/Library/LaunchAgents/\$SERVICE.plist" 2>/dev/null
      rm -f "\$HOME/Library/LaunchAgents/\$SERVICE.plist"
      rm -f /usr/local/bin/proxifypro
      rm -rf "\$INSTALL_DIR"
      echo "ProxifyPRO desinstalado"
    fi
    ;;
  *)
    echo ""
    echo "  ProxifyPRO v1.0.0 — 4G Mobile Proxy Manager"
    echo ""
    echo "  Uso: proxifypro {comando}"
    echo ""
    echo "  Comandos:"
    echo "    start     Iniciar el servicio"
    echo "    stop      Detener el servicio"
    echo "    restart   Reiniciar el servicio"
    echo "    status    Estado del servicio"
    echo "    logs      Ver logs en tiempo real"
    echo "    errors    Ver errores"
    echo "    open      Abrir dashboard en Safari"
    echo "    uninstall Desinstalar completamente"
    echo ""
    echo "  Dashboard: http://localhost:\$PORT"
    echo "  Docs API:  http://localhost:\$PORT/api/docs"
    echo ""
    ;;
esac
CLIEOF
  
  chmod +x /usr/local/bin/proxifypro
  log_ok "Comando 'proxifypro' disponible en Terminal"
}

# ── 12. VERIFY ────────────────────────────────────────────
verify() {
  log_step "Verificando instalación..."
  sleep 2
  
  PORT=$(grep "^PORT=" "$INSTALL_DIR/.env" | cut -d= -f2)
  RESPONSE=$(curl -s --max-time 5 "http://localhost:$PORT/api/status" 2>/dev/null)
  
  if echo "$RESPONSE" | grep -q "error\|ProxifyPRO" 2>/dev/null; then
    log_ok "API respondiendo en puerto $PORT"
  else
    log_warn "API iniciando — verifica con: proxifypro status"
  fi
}

# ── 13. SUMMARY ───────────────────────────────────────────
print_summary() {
  PORT=$(grep "^PORT=" "$INSTALL_DIR/.env" | cut -d= -f2)
  ADMIN_EMAIL=$(grep "^ADMIN_EMAIL=" "$INSTALL_DIR/.env" | cut -d= -f2)
  
  echo ""
  echo -e "  ${GREEN}╔══════════════════════════════════════════════╗${NC}"
  echo -e "  ${GREEN}║     ProxifyPRO instalado correctamente       ║${NC}"
  echo -e "  ${GREEN}╚══════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "  ${BOLD}Dashboard:${NC}   http://localhost:$PORT"
  echo -e "  ${BOLD}API Docs:${NC}    http://localhost:$PORT/api/docs"
  echo -e "  ${BOLD}Email:${NC}       $ADMIN_EMAIL"
  echo ""
  echo -e "  ${BOLD}Próximos pasos:${NC}"
  echo -e "  ${CYAN}1.${NC} Conecta tus dongles USB 4G"
  echo -e "  ${CYAN}2.${NC} Abre http://localhost:$PORT"
  echo -e "  ${CYAN}3.${NC} Inicia sesión y comienza a usar tus proxies"
  echo ""
  echo -e "  ${BOLD}Comandos:${NC}"
  echo -e "    ${CYAN}proxifypro start${NC}   — Iniciar"
  echo -e "    ${CYAN}proxifypro stop${NC}    — Detener"
  echo -e "    ${CYAN}proxifypro logs${NC}    — Ver logs"
  echo -e "    ${CYAN}proxifypro open${NC}    — Abrir dashboard"
  echo ""
  echo -e "  ${YELLOW}Soporte: https://proxifypro.com${NC}"
  echo ""
  
  # Abrir dashboard automáticamente
  sleep 2
  open "http://localhost:$PORT" 2>/dev/null || true
}

# ── MAIN ──────────────────────────────────────────────────
main() {
  print_banner
  check_macos
  fix_dns
  install_xcode_tools
  install_homebrew
  install_node
  install_3proxy
  install_proxifypro
  configure
  # validate_license — delegado a license-guard.js (al arrancar el service)
  setup_service
  create_cli
  verify
  print_summary
}

main "$@"
