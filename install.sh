#!/bin/bash
set -e

# ============================================================
#   ProxifyPRO Installer v2.0
#   https://proxifypro.com
#   One line. Everything included. Zero configuration.
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

INSTALL_DIR="/opt/proxifypro"
SERVICE_NAME="proxifypro"
NODE_MIN=22
PROXIFYPRO_VERSION="2.0.0"
REPO_URL="https://github.com/ProxifyPRO/proxifypro-core"

# Keygen IDs embebidos
KEYGEN_ACCOUNT="9750731a-b53a-42f6-b8b7-323546599b23"
KEYGEN_PRODUCT="6edf4915-fd05-4aed-9f3c-53bce798360f"
KEYGEN_VALIDATION_TOKEN=""  # not used since v1.0.0 (validation moved to license-guard.js)

print_banner() {
  clear 2>/dev/null || true
  echo ""
  # PROXIFY en azul brillante (color landing)
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
  echo -e "              ${CYAN}created by${NC} ${BOLD}iamvolans${NC}"
  echo -e "                 ${CYAN}https://proxifypro.com${NC}"
  echo ""
}

log_step()   { echo -e "\n  ${BLUE}▶${NC} ${BOLD}$1${NC}"; }
log_ok()     { echo -e "  ${GREEN}✓${NC} $1"; }
log_warn()   { echo -e "  ${YELLOW}⚠${NC} $1"; }
log_error()  { echo -e "  ${RED}✗${NC} $1"; }
log_detail() { echo -e "    ${CYAN}→${NC} $1"; }

die() { log_error "$1"; exit 1; }

# ── 1. ROOT CHECK ─────────────────────────────────────────
check_root() {
  if [ "$EUID" -ne 0 ]; then
    die "Este instalador debe ejecutarse como root. Usa: sudo bash install.sh"
  fi
  log_ok "Ejecutando como root"
}

# ── 2. OS DETECTION ───────────────────────────────────────
check_os() {
  log_step "Detectando sistema operativo..."
  if [ -f /etc/debian_version ]; then
    OS="debian"
    PKG="apt-get"
    log_ok "Ubuntu/Debian detectado"
  elif [ -f /etc/redhat-release ]; then
    OS="redhat"
    PKG="yum"
    log_ok "RedHat/CentOS detectado"
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
    PKG="brew"
    log_ok "macOS detectado"
  else
    die "Sistema operativo no soportado. Usa Ubuntu 20.04+"
  fi
}

# ── 3. FIX DNS ────────────────────────────────────────────
fix_dns() {
  log_step "Configurando DNS..."
  # Verificar conectividad actual
  if curl -s --max-time 5 https://google.com > /dev/null 2>&1; then
    # Verificar que puede resolver dominios externos
    if ! curl -s --max-time 5 https://api.keygen.sh > /dev/null 2>&1; then
      log_warn "DNS no puede resolver api.keygen.sh — corrigiendo..."
      # Backup
      cp /etc/resolv.conf /etc/resolv.conf.backup 2>/dev/null || true
      # Configurar DNS de Google
      cat > /etc/resolv.conf << EOF
nameserver 8.8.8.8
nameserver 8.8.4.4
nameserver 1.1.1.1
EOF
      # Hacer inmutable para que systemd-resolved no lo sobreescriba
      chattr +i /etc/resolv.conf 2>/dev/null || true
      log_ok "DNS configurado: 8.8.8.8, 8.8.4.4, 1.1.1.1"
    else
      log_ok "DNS funcionando correctamente"
    fi
  else
    die "Sin conexión a internet. Verifica tu red y reintenta."
  fi
}

# ── 4. SYSTEM DEPENDENCIES ────────────────────────────────
install_deps() {
  log_step "Instalando dependencias del sistema..."

  if [ "$OS" = "debian" ]; then
    apt-get update -qq
    apt-get install -y -qq curl wget git build-essential sqlite3 net-tools 2>/dev/null
    log_ok "Dependencias base instaladas"

    # 3proxy
    if ! command -v 3proxy &> /dev/null; then
      log_detail "Instalando 3proxy..."
      apt-get install -y -qq 3proxy 2>/dev/null || install_3proxy_source
    fi
    log_ok "3proxy $(3proxy --version 2>&1 | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' | head -1) instalado"

    # uhubctl
    if ! command -v uhubctl &> /dev/null; then
      log_detail "Instalando uhubctl..."
      apt-get install -y -qq uhubctl 2>/dev/null || log_warn "uhubctl no disponible (opcional)"
    else
      log_ok "uhubctl instalado"
    fi
  fi
}

install_3proxy_source() {
  log_detail "Compilando 3proxy desde fuente..."
  cd /tmp
  wget -q https://github.com/3proxy/3proxy/archive/refs/tags/0.9.4.tar.gz -O 3proxy.tar.gz
  tar xzf 3proxy.tar.gz
  cd 3proxy-0.9.4
  make -f Makefile.Linux -j$(nproc) 2>/dev/null
  cp bin/3proxy /usr/bin/3proxy
  chmod +x /usr/bin/3proxy
  cd /
  log_ok "3proxy compilado e instalado"
}

# ── 5. NODE.JS ────────────────────────────────────────────
install_node() {
  log_step "Verificando Node.js..."
  if command -v node &> /dev/null; then
    VER=$(node -v | cut -dv -f2 | cut -d. -f1)
    if [ "$VER" -ge "$NODE_MIN" ]; then
      log_ok "Node.js $(node -v) — OK"
      return
    fi
    log_warn "Node.js $(node -v) muy antiguo — actualizando..."
  else
    log_warn "Node.js no encontrado — instalando..."
  fi

  if [ "$OS" = "debian" ]; then
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash - 2>/dev/null
    apt-get install -y -qq nodejs
  elif [ "$OS" = "macos" ]; then
    brew install node@22
  fi
  log_ok "Node.js $(node -v) instalado"
}

# ── 6. INSTALL PROXIFYPRO ─────────────────────────────────
install_proxifypro() {
  log_step "Instalando ProxifyPRO en $INSTALL_DIR..."

  mkdir -p "$INSTALL_DIR"/{data,logs,config}
  mkdir -p /var/log/proxifypro /run/proxifypro /etc/proxifypro

  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  if [ -f "$SCRIPT_DIR/package.json" ]; then
    # Running from project directory (developer mode)
    log_detail "Copiando archivos desde directorio local..."
    cp -r "$SCRIPT_DIR/src"           "$INSTALL_DIR/"
    cp    "$SCRIPT_DIR/package.json"  "$INSTALL_DIR/"
    cp    "$SCRIPT_DIR/package-lock.json" "$INSTALL_DIR/" 2>/dev/null || true
    log_ok "Archivos copiados (modo local)"
  else
    # Running from curl pipe (production mode) — download tarball
    DOWNLOAD_URL="https://github.com/ProxifyPRO/proxifypro-installer/releases/latest/download/proxifypro-v2.tar.gz"
    log_detail "Descargando ProxifyPRO v${PROXIFYPRO_VERSION}..."
    
    TMPTAR=$(mktemp /tmp/proxifypro-XXXXXX.tar.gz)
    HTTP_CODE=$(curl -fsSL -w "%{http_code}" -o "$TMPTAR" "$DOWNLOAD_URL" 2>/dev/null || echo "000")
    
    if [ "$HTTP_CODE" != "200" ] || [ ! -s "$TMPTAR" ]; then
      rm -f "$TMPTAR"
      die "Error descargando ProxifyPRO (HTTP $HTTP_CODE). Verifica tu conexión o contacta soporte."
    fi
    
    log_detail "Extrayendo archivos..."
    tar xzf "$TMPTAR" -C "$INSTALL_DIR/" 2>/dev/null || die "Error extrayendo el paquete"
    rm -f "$TMPTAR"
    log_ok "ProxifyPRO descargado y extraído"
  fi

  log_detail "Instalando dependencias npm..."
  cd "$INSTALL_DIR"
  npm install --production --silent 2>/dev/null || npm install --production 2>/dev/null
  log_ok "Dependencias npm instaladas"
  
  # USB autosuspend rules
  cat > /etc/udev/rules.d/99-proxifypro-usb.rules << 'UDEVRULE'
ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="12d1", ATTR{power/autosuspend_delay_ms}="-1", ATTR{power/control}="on"
ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="19d2", ATTR{power/autosuspend_delay_ms}="-1", ATTR{power/control}="on"
ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="2c7c", ATTR{power/autosuspend_delay_ms}="-1", ATTR{power/control}="on"
UDEVRULE
  udevadm control --reload-rules 2>/dev/null
  for d in /sys/bus/usb/devices/*/power/autosuspend_delay_ms; do echo -1 > "$d" 2>/dev/null; done
  log_ok "USB autosuspend desactivado"
  
  # sysctl config
  echo "net.ipv4.conf.all.route_localnet=1" > /etc/sysctl.d/99-proxifypro.conf
  echo "net.ipv4.ip_forward=1" >> /etc/sysctl.d/99-proxifypro.conf
  sysctl -p /etc/sysctl.d/99-proxifypro.conf >/dev/null 2>&1
  log_ok "Network config (route_localnet + ip_forward)"
}

# ── 7. CONFIGURE ──────────────────────────────────────────
configure() {
  log_step "Configurando ProxifyPRO..."

  JWT_SECRET=$(node -e "console.log(require('crypto').randomBytes(32).toString('hex'))")
  MACHINE_ID=$(node -e "
    const {execSync}=require('child_process');
    const crypto=require('crypto');
    try {
      const iface=execSync('ls /sys/class/net | grep -v lo | head -1').toString().trim();
      const mac=execSync('cat /sys/class/net/'+iface+'/address').toString().trim();
      const host=execSync('hostname').toString().trim();
      console.log(crypto.createHash('sha256').update(mac+host).digest('hex').substring(0,32));
    } catch(e){ console.log(crypto.randomBytes(16).toString('hex')); }
  ")

  echo ""
  echo -e "  ${BOLD}Configuración inicial:${NC}"
  echo ""

  read -p "    Email del administrador [admin@proxifypro.local]: " ADMIN_EMAIL < /dev/tty
  ADMIN_EMAIL=${ADMIN_EMAIL:-admin@proxifypro.local}

  read -s -p "    Contraseña del administrador [Admin123!]: " ADMIN_PASS
  echo ""
  ADMIN_PASS=${ADMIN_PASS:-Admin123!}

  read -p "    Puerto del dashboard [3000]: " PORT < /dev/tty
  PORT=${PORT:-3000}

  read -p "    Clave de licencia ProxifyPRO: " LICENSE_KEY < /dev/tty
  while [ -z "$LICENSE_KEY" ]; do
    echo -e "    ${RED}La clave de licencia es obligatoria.${NC}"
    echo -e "    ${CYAN}Obtén tu licencia en https://proxifypro.com${NC}"
    read -p "    Clave de licencia: " LICENSE_KEY < /dev/tty
  done

  cat > "$INSTALL_DIR/.env" << EOF
# ProxifyPRO Configuration
NODE_ENV=production
PORT=$PORT
HOST=0.0.0.0
INSTALL_DIR=$INSTALL_DIR
DB_PATH=$INSTALL_DIR/data/proxifypro.db
LOG_PATH=$INSTALL_DIR/logs

# Secrets
JWT_SECRET=$JWT_SECRET
ADMIN_EMAIL=$ADMIN_EMAIL
ADMIN_PASSWORD=$ADMIN_PASS

# License (auto-removed by license-guard after activation)
INITIAL_LICENSE=$LICENSE_KEY

# Keygen
KEYGEN_ACCOUNT_ID=$KEYGEN_ACCOUNT
KEYGEN_PRODUCT_ID=$KEYGEN_PRODUCT
KEYGEN_TOKEN=$KEYGEN_VALIDATION_TOKEN
EOF
  chmod 600 "$INSTALL_DIR/.env"

  log_ok "Configuración guardada"
}

# ── 8. VALIDATE LICENSE ───────────────────────────────────
validate_license() {
  log_step "Validando licencia..."

  LICENSE_KEY=$(grep "^LICENSE_KEY=" "$INSTALL_DIR/.env" | cut -d= -f2)
  FINGERPRINT=$(node -e "
    const {execSync}=require('child_process');
    const crypto=require('crypto');
    try {
      const iface=execSync('ls /sys/class/net | grep -v lo | head -1').toString().trim();
      const mac=execSync('cat /sys/class/net/'+iface+'/address').toString().trim();
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
        if(r.meta?.valid) { console.log('VALID:'+r.data?.relationships?.policy?.data?.id); }
        else if(code==='FINGERPRINT_SCOPE_MISMATCH'||code==='NO_MACHINES'||code==='FINGERPRINT_SCOPE_REQUIRED') { console.log('ACTIVATE'); }
        else { console.log('INVALID:'+(r.errors?.[0]?.detail||code||'unknown')); }
      }catch(e){ console.log('ERROR:'+e.message); }
    });
  ")

  if [[ "$VALID" == VALID:* ]]; then
    POLICY_ID="${VALID#VALID:}"
    # Detectar plan
    if [ "$POLICY_ID" = "d7cbd3c1-3e20-4290-ac12-6fdfeaad12b3" ]; then PLAN="Starter"; MAX=5;
    elif [ "$POLICY_ID" = "f97d3b0d-8d62-48e2-bc80-b981cfa63d5d" ]; then PLAN="PRO"; MAX=20;
    elif [ "$POLICY_ID" = "50bf2741-ab84-45e1-8741-75eccb7af024" ]; then PLAN="Enterprise"; MAX=60;
    else PLAN="Unknown"; MAX=1; fi
    log_ok "Licencia válida — Plan: ${BOLD}$PLAN${NC} | Max dongles: $MAX"

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
        -d "{\"data\":{\"type\":\"machines\",\"attributes\":{\"fingerprint\":\"$FINGERPRINT\",\"name\":\"$HOSTNAME\",\"platform\":\"linux\"},\"relationships\":{\"license\":{\"data\":{\"type\":\"licenses\",\"id\":\"$LICENSE_ID\"}}}}}" > /dev/null
      log_ok "Máquina activada correctamente"
      # Re-validar
      validate_license
      return
    fi
    die "No se pudo activar la licencia. Contacta soporte en proxifypro.com"

  elif [[ "$VALID" == INVALID:* ]]; then
    die "Licencia inválida: ${VALID#INVALID:}. Obtén tu licencia en proxifypro.com"
  else
    log_warn "No se pudo verificar la licencia online — modo offline activado"
  fi
}

# ── 9. SUDOERS + ROTATE SCRIPT ────────────────────────────
setup_permissions() {
  log_step "Configurando permisos del sistema..."

  cat > /usr/local/bin/proxifypro-rotate << 'ROTATE'
#!/bin/bash
IFACE=$1
if [ -z "$IFACE" ]; then exit 1; fi
ip link set "$IFACE" down && sleep 3 && ip link set "$IFACE" up
ROTATE
  chmod +x /usr/local/bin/proxifypro-rotate

  CURRENT_USER="${SUDO_USER:-$(whoami)}"
  echo "$CURRENT_USER ALL=(ALL) NOPASSWD: /usr/local/bin/proxifypro-rotate, /usr/bin/uhubctl" \
    > /etc/sudoers.d/proxifypro
  chmod 440 /etc/sudoers.d/proxifypro
  log_ok "Permisos configurados para: $CURRENT_USER"
}

# ── 10. SYSTEMD ───────────────────────────────────────────
setup_systemd() {
  log_step "Configurando servicio del sistema..."

  PORT=$(grep "^PORT=" "$INSTALL_DIR/.env" | cut -d= -f2)

  cat > /etc/systemd/system/proxifypro.service << EOF
[Unit]
Description=ProxifyPRO V2 — 4G Mobile Proxy Management
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
EnvironmentFile=$INSTALL_DIR/.env
ExecStart=$(which node) $INSTALL_DIR/src/dongle/v2/main.js
Restart=always
RestartSec=10
LimitNOFILE=65535
StandardOutput=append:$INSTALL_DIR/logs/proxifypro.log
StandardError=append:$INSTALL_DIR/logs/proxifypro-error.log

[Install]
WantedBy=multi-user.target
EOF

  # Config 3proxy dir
  mkdir -p /opt/proxifypro/config
  chmod 777 /opt/proxifypro/config

  systemctl daemon-reload
  systemctl enable proxifypro --quiet
  systemctl start proxifypro

  sleep 3

  if systemctl is-active --quiet proxifypro; then
    log_ok "Servicio proxifypro iniciado y habilitado"
  else
    log_warn "Revisando logs..."
    journalctl -u proxifypro -n 5 --no-pager
    die "El servicio no pudo iniciarse. Revisa los logs en $INSTALL_DIR/logs/"
  fi
}

# ── 11. CLI ───────────────────────────────────────────────
create_cli() {
  log_step "Creando comando CLI..."

  cat > /usr/local/bin/proxifypro << CLIEOF
#!/bin/bash
INSTALL_DIR="$INSTALL_DIR"
PORT=\$(grep "^PORT=" \$INSTALL_DIR/.env 2>/dev/null | cut -d= -f2 || echo 3000)
case "\$1" in
  start)
    systemctl start proxifypro
    echo -e "\033[0;32m✓\033[0m ProxifyPRO iniciado → http://localhost:\$PORT"
    ;;
  stop)
    systemctl stop proxifypro
    echo -e "\033[0;32m✓\033[0m ProxifyPRO detenido"
    ;;
  restart)
    systemctl restart proxifypro
    echo -e "\033[0;32m✓\033[0m ProxifyPRO reiniciado → http://localhost:\$PORT"
    ;;
  status)
    systemctl status proxifypro
    ;;
  logs)
    tail -f \$INSTALL_DIR/logs/proxifypro.log
    ;;
  errors)
    tail -f \$INSTALL_DIR/logs/proxifypro-error.log
    ;;
  update)
    echo "Actualizando ProxifyPRO..."
    systemctl stop proxifypro
    SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
    cp -r \$SCRIPT_DIR/src \$INSTALL_DIR/
    cp \$SCRIPT_DIR/package.json \$INSTALL_DIR/
    cd \$INSTALL_DIR && npm install --production --silent
    systemctl start proxifypro
    echo -e "\033[0;32m✓\033[0m ProxifyPRO actualizado"
    ;;
  open)
    xdg-open "http://localhost:\$PORT" 2>/dev/null || \
    echo "Abre en tu navegador: http://localhost:\$PORT"
    ;;
  uninstall)
    read -p "¿Desinstalar ProxifyPRO? Se eliminarán todos los datos [s/N]: " confirm < /dev/tty
    if [ "\$confirm" = "s" ] || [ "\$confirm" = "S" ]; then
      systemctl stop proxifypro 2>/dev/null
      systemctl disable proxifypro 2>/dev/null
      rm -f /etc/systemd/system/proxifypro.service
      rm -f /etc/sudoers.d/proxifypro
      rm -f /usr/local/bin/proxifypro-rotate
      rm -f /usr/local/bin/proxifypro
      rm -rf \$INSTALL_DIR
      systemctl daemon-reload
      echo "ProxifyPRO desinstalado"
    fi
    ;;
  *)
    echo ""
    echo "  ProxifyPRO v$PROXIFYPRO_VERSION — 4G Mobile Proxy Manager"
    echo ""
    echo "  Uso: proxifypro {comando}"
    echo ""
    echo "  Comandos:"
    echo "    start     Iniciar el servicio"
    echo "    stop      Detener el servicio"
    echo "    restart   Reiniciar el servicio"
    echo "    status    Estado del servicio"
    echo "    logs      Ver logs en tiempo real"
    echo "    errors    Ver errores en tiempo real"
    echo "    open      Abrir dashboard en el navegador"
    echo "    update    Actualizar ProxifyPRO"
    echo "    uninstall Desinstalar completamente"
    echo ""
    echo "  Dashboard: http://localhost:\$PORT"
    echo "  Docs API:  http://localhost:\$PORT/api/docs"
    echo ""
    ;;
esac
CLIEOF

  chmod +x /usr/local/bin/proxifypro
  log_ok "Comando 'proxifypro' disponible"
}

# ── 12. VERIFY INSTALLATION ───────────────────────────────
verify() {
  log_step "Verificando instalación..."
  sleep 2

  PORT=$(grep "^PORT=" "$INSTALL_DIR/.env" | cut -d= -f2)
  RESPONSE=$(curl -s --max-time 5 "http://localhost:$PORT/api/status" 2>/dev/null)

  if echo "$RESPONSE" | grep -q "error\|ProxifyPRO" 2>/dev/null; then
    log_ok "API respondiendo en puerto $PORT"
  else
    log_warn "API tardando en iniciar — verifica con: proxifypro status"
  fi

  # Verificar 3proxy
  if pgrep 3proxy > /dev/null 2>&1; then
    log_ok "3proxy corriendo"
  else
    log_warn "3proxy iniciará cuando conectes un dongle"
  fi

  log_ok "Instalación verificada"
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
  echo -e "  ${CYAN}2.${NC} Abre http://localhost:$PORT en tu navegador"
  echo -e "  ${CYAN}3.${NC} Inicia sesión y comienza a usar tus proxies"
  echo ""
  echo -e "  ${BOLD}Comandos:${NC}"
  echo -e "    ${CYAN}proxifypro start${NC}    — Iniciar"
  echo -e "    ${CYAN}proxifypro stop${NC}     — Detener"
  echo -e "    ${CYAN}proxifypro logs${NC}     — Ver logs"
  echo -e "    ${CYAN}proxifypro status${NC}   — Estado"
  echo -e "    ${CYAN}proxifypro open${NC}     — Abrir dashboard"
  echo ""
  echo -e "  ${YELLOW}Soporte: https://proxifypro.com${NC}"
  echo ""
}

# ── MAIN ──────────────────────────────────────────────────
main() {
  print_banner
  check_root
  check_os
  fix_dns
  install_deps
  install_node
  install_proxifypro
  configure
  # validate_license — delegado a license-guard.js (al arrancar el service)
  setup_permissions
  setup_systemd
  create_cli
  verify
  print_summary
}

main "$@"
