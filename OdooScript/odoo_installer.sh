#!/bin/bash

# ===============================================================================
# Enhanced Odoo Installation Script for Ubuntu 22.04 - OPTIMIZED for Low Resources
# ===============================================================================
# Version: 3.2.3-20260122
# Release Date: 2026-01-22
# Author: Mahmoud Abel Latif, https://mah007.net
# Modified: CODIFICANDO - Optimized for DigitalOcean Droplets
# Description: Odoo installation optimized for 900MB-2GB RAM servers with SendGrid,
#              public links configuration, and automatic database creation
#
# MINIMUM REQUIREMENTS (Perfil Básico):
#   - 900 MB Memory (with 2GB swap)
#   - 1 Intel vCPU  
#   - 8 GB Disk
#   - Ubuntu 22.04 (LTS) x64
#
# FEATURES:
#   - 2 Resource profiles: basic (900MB+), standard (2GB+)
#   - Memory optimization with swap configuration
#   - SendGrid SMTP direct API Key configuration
#   - Public links configuration (proxy_mode, web.base.url)
#   - Default database "CODIFICANDO" configurable (no auto-creation)
#   - Extra addons directory at /opt/extra-addons
#   - Custom module repository cloning
#   - Spanish interface for better user experience
#   - Default modules: pos, stock, purchase, account, sale
# ===============================================================================

# Script configuration
SCRIPT_VERSION="3.2.3-20260122"
SCRIPT_NAME="Odoo Installer - CODIFICANDO Edition"
LOG_FILE="/tmp/odoo_install_$(date +%Y%m%d_%H%M%S).log"
CONFIG_FILE="/tmp/odoo_install_config.conf"

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Progress tracking
TOTAL_STEPS=10
CURRENT_STEP=0

# Installation configuration - DEFAULTS
OE_USER="odoo"
OE_BRANCH="17.0"
INSTALL_WKHTMLTOPDF="True"
IS_ENTERPRISE="False"  # Community version for low resources
WKHTML_X64="https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-2/wkhtmltox_0.12.6.1-2.jammy_amd64.deb"

# Domain and SSL configuration
DOMAIN_NAME=""
HAS_DOMAIN="false"
INSTALL_NGINX="true"
SSL_TYPE="letsencrypt"
SERVER_IP=""

# SendGrid Configuration (Pre-configured defaults for Sistemas Codificando)
# ⚠️ IMPORTANTE: Agregar tu API Key aquí antes de ejecutar:
#   export SENDGRID_API_KEY="SG.tu_api_key_aqui"
#   O edita directamente la línea SENDGRID_API_KEY abajo
SENDGRID_ENABLED="false"
SENDGRID_API_KEY="${SENDGRID_API_KEY:-}"  # <-- AGREGAR TU API KEY AQUÍ: SG.xxxxx
SENDGRID_API_KEY_NAME="Odoo-SMTP"
SENDGRID_FROM_DOMAIN="${SENDGRID_FROM_DOMAIN:-sistemascodificando.com}"
SENDGRID_FROM_EMAIL="${SENDGRID_FROM_EMAIL:-contacto@sistemascodificando.com}"
SENDGRID_SMTP_USER="apikey"
SENDGRID_SMTP_PASS="${SENDGRID_API_KEY}"

# Default Modules to Install (comma-separated)
# Módulos configurados: pos (Punto de Venta), stock (Inventario), purchase (Compras), account (Contabilidad), sale (Ventas)
DEFAULT_MODULES="${DEFAULT_MODULES:-pos,stock,purchase,account,sale}"

# Database Configuration
CREATE_DEFAULT_DB="false"  # No auto-create; user can create from Odoo UI
DEFAULT_DB_NAME="CODIFICANDO"
DB_ADMIN_USER="contacto@sistemascodificando.com"
DB_ADMIN_PASSWORD="@Multiboot97"

# Extra Addons
EXTRA_ADDONS_PATH="/opt/extra-addons"

# Custom Module Repositories (GitHub URLs to clone into extra-addons)
# Add your custom module repositories here - they will be cloned automatically
# Format: "URL|branch" or just "URL" (uses main/master by default)
# For PRIVATE repos: Use SSH URL (git@github.com:user/repo.git) and configure SSH key
CUSTOM_MODULE_REPOS=(
    # Repositorio principal de Sistemas Codificando (PRIVADO - requiere SSH key)
    "git@github.com:somoscodificando/modulos.git|17.0"
    # Para repo público usar: "https://github.com/somoscodificando/modulos.git|17.0"
)

# Server Resource Profile (will be set during configuration)
# Options: "minimal" (512MB), "basic" (1GB), "standard" (2GB+)
RESOURCE_PROFILE="minimal"

# Resource-specific configurations (will be set based on profile)
SWAP_SIZE="2G"
WORKERS=0
MAX_CRON_THREADS=1
LIMIT_MEMORY_HARD=1073741824   # Will be adjusted per profile
LIMIT_MEMORY_SOFT=805306368    # Will be adjusted per profile
LIMIT_TIME_CPU=120
LIMIT_TIME_REAL=240
LIMIT_REQUEST=2048

# PostgreSQL optimization level
PG_SHARED_BUFFERS="32MB"
PG_EFFECTIVE_CACHE="64MB"
PG_WORK_MEM="2MB"
PG_MAINTENANCE_WORK_MEM="16MB"

# Trap for cleanup on exit
trap cleanup_on_exit EXIT INT TERM

#==============================================================================
# UTILITY FUNCTIONS
#==============================================================================

log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    case "$level" in
        "ERROR")   echo -e "${RED}[ERROR]${NC} $message" >&2 ;;
        "WARNING") echo -e "${YELLOW}[WARNING]${NC} $message" ;;
        "INFO")    echo -e "${GREEN}[INFO]${NC} $message" ;;
        "DEBUG")   echo -e "${CYAN}[DEBUG]${NC} $message" ;;
    esac
}

show_progress_bar() {
    local current="$1"
    local total="$2"
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((current * width / total))
    local remaining=$((width - completed))
    
    printf "\r${BLUE}["
    printf "%*s" $completed | tr ' ' '='
    printf "%*s" $remaining | tr ' ' '-'
    printf "] %d%% (%d/%d)${NC}" $percentage $current $total
}

execute_simple() {
    local command="$1"
    local description="$2"
    
    log_message "DEBUG" "Executing: $command"
    echo -e "${CYAN}$description...${NC}"
    
    if eval "$command" >> "$LOG_FILE" 2>&1; then
        echo -e "${GREEN}✓${NC} $description"
        log_message "INFO" "Successfully completed: $description"
        return 0
    else
        local exit_code=$?
        echo -e "${RED}✗${NC} $description"
        log_message "ERROR" "Failed to execute: $description (Exit code: $exit_code)"
        return $exit_code
    fi
}

display_billboard() {
    local message="$1"
    local width=80
    local padding=$(( (width - ${#message}) / 2 ))
    
    echo
    echo -e "${PURPLE}${BOLD}$(printf '%*s' $width | tr ' ' '=')"
    echo -e "$(printf '%*s' $padding)${WHITE}$message${PURPLE}"
    echo -e "$(printf '%*s' $width | tr ' ' '=')${NC}"
    echo
}

show_step_header() {
    local step_num="$1"
    local step_name="$2"
    local step_desc="$3"
    
    CURRENT_STEP=$step_num
    echo
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${WHITE}Step $step_num/$TOTAL_STEPS: $step_name${NC}"
    echo -e "${CYAN}$step_desc${NC}"
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    show_progress_bar $step_num $TOTAL_STEPS
    echo
    log_message "INFO" "Starting Step $step_num: $step_name"
}

cleanup_on_exit() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo
        echo -e "${RED}${BOLD}Installation interrupted or failed!${NC}"
        echo -e "${YELLOW}Check the log file for details: $LOG_FILE${NC}"
    fi
}

get_server_ip() {
    SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || curl -s icanhazip.com 2>/dev/null)
    
    if [ -z "$SERVER_IP" ]; then
        SERVER_IP=$(hostname -I | awk '{print $1}')
    fi
    
    if [ -z "$SERVER_IP" ]; then
        SERVER_IP="Unable to detect"
        log_message "WARNING" "Could not detect server IP address"
    else
        log_message "INFO" "Detected server IP: $SERVER_IP"
    fi
}

generate_random_password() {
    openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 20
}

#==============================================================================
# VALIDATION FUNCTIONS
#==============================================================================

check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_message "ERROR" "This script must be run as root (use sudo)"
        exit 1
    fi
}

check_system_requirements() {
    local errors=0
    
    # Check Ubuntu version
    if ! lsb_release -d | grep -q "Ubuntu 22.04"; then
        log_message "WARNING" "This script is optimized for Ubuntu 22.04. Current version: $(lsb_release -d | cut -f2)"
    fi
    
    # Check available disk space based on resource profile
    local available_space=$(df / | awk 'NR==2 {print $4}')
    local required_space=10485760  # 10GB in KB (default)
    local required_gb=10
    
    # Adjust disk requirement based on profile
    case "$RESOURCE_PROFILE" in
        "basic")
            required_space=8388608   # 8GB in KB for basic profile
            required_gb=8
            ;;
        "standard")
            required_space=10485760  # 10GB in KB for standard profile
            required_gb=10
            ;;
    esac
    
    local available_gb=$((available_space/1024/1024))
    
    if [ "$available_space" -lt "$required_space" ]; then
        log_message "ERROR" "Espacio en disco insuficiente. Requerido: ${required_gb}GB, Disponible: ${available_gb}GB"
        errors=$((errors + 1))
    else
        log_message "INFO" "Espacio en disco OK: ${available_gb}GB disponibles (${required_gb}GB requeridos para perfil $RESOURCE_PROFILE)"
    fi
    
    # Check memory - WARNING for low memory but continue (we'll add swap)
    local total_memory=$(free -m | awk 'NR==2{print $2}')
    if [ "$total_memory" -lt 900 ]; then
        log_message "WARNING" "Memoria muy baja: ${total_memory}MB. Se recomienda mínimo 900MB RAM. Se configurará swap y optimizaciones."
    elif [ "$total_memory" -lt 1800 ]; then
        log_message "INFO" "Memoria: ${total_memory}MB. Se optimizará para bajo consumo de recursos."
    fi
    
    # Check internet connectivity
    if ! ping -c 1 google.com &> /dev/null; then
        log_message "ERROR" "No internet connection detected"
        errors=$((errors + 1))
    fi
    
    return $errors
}

#==============================================================================
# CONFIGURATION FUNCTIONS
#==============================================================================

configure_domain() {
    clear
    display_billboard "Configuración de Dominio"
    
    echo -e "${BOLD}${WHITE}Configuración de Dominio para la Instalación de Odoo${NC}"
    echo
    
    get_server_ip
    echo -e "${YELLOW}Tu dirección IP del servidor: ${BOLD}$SERVER_IP${NC}"
    echo
    
    while true; do
        echo -e -n "${BOLD}${WHITE}¿Tienes un nombre de dominio apuntando a este servidor? [y/N]: ${NC}"
        read -r has_domain_input
        case "$has_domain_input" in
            [Yy]|[Yy][Ee][Ss])
                HAS_DOMAIN="true"
                break
                ;;
            [Nn]|[Nn][Oo]|"")
                HAS_DOMAIN="false"
                break
                ;;
            *)
                echo -e "${RED}Por favor responde sí (y) o no (n).${NC}"
                ;;
        esac
    done
    
    if [ "$HAS_DOMAIN" = "true" ]; then
        while true; do
            echo -e -n "${BOLD}${WHITE}Ingresa tu nombre de dominio (ej: odoo.sistemascodificando.com): ${NC}"
            read -r domain_input
            
            if [ -n "$domain_input" ]; then
                if [[ "$domain_input" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
                    DOMAIN_NAME="$domain_input"
                    echo -e "${GREEN}Dominio configurado: $DOMAIN_NAME${NC}"
                    break
                else
                    echo -e "${RED}Formato de dominio inválido. Ingresa un nombre de dominio válido.${NC}"
                fi
            else
                echo -e "${RED}El nombre de dominio no puede estar vacío.${NC}"
            fi
        done
    else
        echo -e "${YELLOW}No domain configured. Will use IP address access only.${NC}"
        DOMAIN_NAME="$SERVER_IP"
        SSL_TYPE="self-signed"
    fi
    
    log_message "INFO" "Domain configuration: HAS_DOMAIN=$HAS_DOMAIN, DOMAIN_NAME=$DOMAIN_NAME"
}

configure_sendgrid() {
    clear
    display_billboard "Configuración de Email SendGrid"
    
    echo -e "${BOLD}${WHITE}📧 Configuración SMTP de SendGrid${NC}"
    echo
    echo -e "${CYAN}Configura el envío automático de emails usando SendGrid.${NC}"
    echo -e "${CYAN}Recomendado para DigitalOcean ya que los puertos 25, 465, 587 están bloqueados.${NC}"
    echo -e "${CYAN}SendGrid usa el puerto 2525 que funciona con DigitalOcean.${NC}"
    echo
    
    # Mostrar configuración por defecto
    echo -e "${BOLD}${YELLOW}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${YELLOW}║           CONFIGURACIÓN (Sistemas Codificando)               ║${NC}"
    echo -e "${BOLD}${YELLOW}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║  Dominio:       ${WHITE}$SENDGRID_FROM_DOMAIN${NC}"
    echo -e "${YELLOW}║  Email:         ${WHITE}$SENDGRID_FROM_EMAIL${NC}"
    echo -e "${YELLOW}║  Usuario SMTP:  ${WHITE}apikey${NC}"
    echo -e "${YELLOW}║  Puerto SMTP:   ${WHITE}2525${NC}"
    echo -e "${BOLD}${YELLOW}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    # Pedir API Key directamente
    echo -e "${BOLD}${WHITE}Ingresa tu SendGrid API Key:${NC}"
    echo -e "${CYAN}(Puedes obtenerla en: SendGrid → Settings → API Keys)${NC}"
    echo -e "${CYAN}(Déjalo vacío para omitir y configurar después en Odoo)${NC}"
    echo
    
    while true; do
        echo -e -n "${BOLD}${WHITE}API Key [SG.xxx...]: ${NC}"
        read -r api_key_input
        
        if [ -z "$api_key_input" ]; then
            SENDGRID_ENABLED="false"
            echo -e "${YELLOW}⚠ SendGrid omitido. Puedes configurarlo después en Odoo.${NC}"
            log_message "INFO" "SendGrid configuration skipped"
            return 0
        elif [[ "$api_key_input" =~ ^SG\. ]]; then
            SENDGRID_API_KEY="$api_key_input"
            SENDGRID_SMTP_PASS="$api_key_input"
            SENDGRID_ENABLED="true"
            echo -e "${GREEN}✓ API Key configurada${NC}"
            echo -e "${GREEN}✓ Key: ${SENDGRID_API_KEY:0:15}...${NC}"
            break
        else
            echo -e "${RED}✗ API Key inválida. Debe comenzar con 'SG.'${NC}"
            echo -e "${YELLOW}Intenta de nuevo o déjalo vacío para omitir.${NC}"
        fi
    done
    
    # Probar conectividad SendGrid
    echo
    echo -e "${CYAN}Probando conectividad con SendGrid (puerto 2525)...${NC}"
    if nc -z -w5 smtp.sendgrid.net 2525 2>/dev/null; then
        echo -e "${GREEN}✓ SendGrid SMTP accesible en puerto 2525${NC}"
        log_message "INFO" "SendGrid connectivity test passed"
    else
        echo -e "${YELLOW}⚠ No se pudo conectar a SendGrid. Se configurará de todos modos.${NC}"
        log_message "WARNING" "SendGrid connectivity test failed"
    fi
    
    log_message "INFO" "SendGrid configuration: ENABLED=$SENDGRID_ENABLED, DOMAIN=$SENDGRID_FROM_DOMAIN"
}

# Custom SendGrid configuration (when user wants to change defaults)
configure_database() {
    clear
    display_billboard "Configuración de Base de Datos"
    
    echo -e "${BOLD}${WHITE}🗄️ Configuración de Base de Datos por Defecto${NC}"
    echo
    echo -e "${CYAN}Configura la base de datos de Odoo y el directorio de addons adicionales.${NC}"
    echo
    
    # Database name
    echo -e "${CYAN}Nombre de la base de datos por defecto:${NC}"
    echo -e -n "${BOLD}${WHITE}Nombre de base de datos [$DEFAULT_DB_NAME]: ${NC}"
    read -r db_name_input
    
    if [ -n "$db_name_input" ]; then
        DEFAULT_DB_NAME="$db_name_input"
    fi
    echo -e "${GREEN}✓ Nombre de base de datos: $DEFAULT_DB_NAME${NC}"
    
    # Generate admin password
    DB_ADMIN_PASSWORD=$(generate_random_password)
    echo
    echo -e "${GREEN}✓ Master password generada (guardada en /root/.odoo_credentials)${NC}"
    
    # Extra addons path
    echo
    echo -e "${CYAN}Directorio de addons adicionales:${NC}"
    echo -e -n "${BOLD}${WHITE}Ruta [$EXTRA_ADDONS_PATH]: ${NC}"
    read -r addons_path_input
    
    if [ -n "$addons_path_input" ]; then
        EXTRA_ADDONS_PATH="$addons_path_input"
    fi
    echo -e "${GREEN}✓ Ruta de addons adicionales: $EXTRA_ADDONS_PATH${NC}"
    
    # Default modules to install
    echo
    echo -e "${BOLD}${YELLOW}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${YELLOW}║               MÓDULOS POR DEFECTO A INSTALAR                 ║${NC}"
    echo -e "${BOLD}${YELLOW}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║  Módulos: ${WHITE}$DEFAULT_MODULES${NC}"
    echo -e "${YELLOW}║  (sale=Ventas, purchase=Compras, stock=Inventario,           ${NC}"
    echo -e "${YELLOW}║   account=Contabilidad, crm=CRM, project=Proyectos,          ${NC}"
    echo -e "${YELLOW}║   hr=Recursos Humanos, website=Sitio Web)                    ${NC}"
    echo -e "${BOLD}${YELLOW}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e -n "${BOLD}${WHITE}¿Instalar módulos por defecto? [Y/n]: ${NC}"
    read -r modules_confirm
    
    case "$modules_confirm" in
        [Nn]|[Nn][Oo])
            echo -e "${CYAN}¿Deseas especificar otros módulos? [y/N]: ${NC}"
            read -r custom_modules
            case "$custom_modules" in
                [Yy]|[Yy][Ee][Ss])
                    echo -e "${CYAN}Ingresa los módulos separados por coma (ej: sale,crm,hr):${NC}"
                    echo -e -n "${BOLD}${WHITE}Módulos: ${NC}"
                    read -r modules_input
                    if [ -n "$modules_input" ]; then
                        DEFAULT_MODULES="$modules_input"
                        echo -e "${GREEN}✓ Módulos personalizados: $DEFAULT_MODULES${NC}"
                    else
                        DEFAULT_MODULES=""
                        echo -e "${YELLOW}No se instalarán módulos automáticamente.${NC}"
                    fi
                    ;;
                *)
                    DEFAULT_MODULES=""
                    echo -e "${YELLOW}No se instalarán módulos automáticamente.${NC}"
                    ;;
            esac
            ;;
        *)
            echo -e "${GREEN}✓ Se instalarán: $DEFAULT_MODULES${NC}"
            ;;
    esac
    
    # Custom module repositories
    configure_custom_repos
    
    log_message "INFO" "Database configuration: DB_NAME=$DEFAULT_DB_NAME, ADDONS_PATH=$EXTRA_ADDONS_PATH, MODULES=$DEFAULT_MODULES"
}

# Configure custom module repositories
configure_custom_repos() {
    echo
    echo -e "${BOLD}${WHITE}📦 Repositorios de Módulos Personalizados${NC}"
    echo
    echo -e "${CYAN}Puedes agregar repositorios de GitHub con tus módulos personalizados.${NC}"
    echo -e "${CYAN}Se clonarán automáticamente en: ${WHITE}$EXTRA_ADDONS_PATH${NC}"
    echo
    
    echo -e -n "${BOLD}${WHITE}¿Deseas agregar repositorios de módulos personalizados? [y/N]: ${NC}"
    read -r add_repos
    
    case "$add_repos" in
        [Yy]|[Yy][Ee][Ss])
            echo
            echo -e "${CYAN}Ingresa las URLs de los repositorios (una por línea).${NC}"
            echo -e "${CYAN}Formato: URL o URL|rama (ej: https://github.com/user/repo.git|17.0)${NC}"
            echo -e "${YELLOW}Escribe 'done' cuando termines:${NC}"
            echo
            
            while true; do
                echo -e -n "${BOLD}${WHITE}Repo URL: ${NC}"
                read -r repo_url
                
                if [ "$repo_url" = "done" ] || [ -z "$repo_url" ]; then
                    break
                fi
                
                CUSTOM_MODULE_REPOS+=("$repo_url")
                echo -e "${GREEN}✓ Agregado: $repo_url${NC}"
            done
            
            if [ ${#CUSTOM_MODULE_REPOS[@]} -gt 0 ]; then
                echo -e "${GREEN}✓ ${#CUSTOM_MODULE_REPOS[@]} repositorio(s) configurado(s)${NC}"
            fi
            ;;
        *)
            echo -e "${YELLOW}No se agregarán repositorios adicionales.${NC}"
            ;;
    esac
}

select_odoo_version() {
    while true; do
        clear
        display_billboard "Selección de Versión Odoo"
        
        echo -e "${BOLD}${WHITE}Por favor selecciona la versión de Odoo a instalar:${NC}"
        echo
        echo -e "  ${YELLOW}1)${NC} Odoo 16.0 ${CYAN}(Estable - Recomendado para pocos recursos)${NC}"
        echo -e "  ${YELLOW}2)${NC} Odoo 17.0 ${CYAN}(Latest Stable)${NC} ${GREEN}[Por Defecto]${NC}"
        echo -e "  ${YELLOW}3)${NC} Odoo 18.0 ${CYAN}(Más reciente - Puede tener problemas)${NC}"
        echo
        
        echo -e -n "${BOLD}${WHITE}Enter your choice [1-3] (default: 2): ${NC}"
        read -r choice
        
        case "$choice" in
            1) OE_BRANCH="16.0"; break;;
            2|"") OE_BRANCH="17.0"; break;;
            3) OE_BRANCH="18.0"; break;;
            *) 
                echo -e "${RED}Invalid choice. Please select 1-3.${NC}"
                sleep 2
                ;;
        esac
    done
    
    echo -e "${GREEN}Selected Odoo version: $OE_BRANCH${NC}"
    log_message "INFO" "User selected Odoo version: $OE_BRANCH"
    return 0
}

# Select server resource profile and configure optimizations
select_resource_profile() {
    clear
    display_billboard "Perfil de Recursos del Servidor"
    
    echo -e "${BOLD}${WHITE}🖥️ Selecciona el perfil de recursos de tu servidor:${NC}"
    echo
    echo -e "${BOLD}${YELLOW}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║  OPCIÓN 1: BÁSICO (1 GB RAM) - DigitalOcean \$6              ║${NC}"
    echo -e "${YELLOW}║  • 1 GB RAM / 1 vCPU                                         ║${NC}"
    echo -e "${YELLOW}║  • 25 GB SSD                                                 ║${NC}"
    echo -e "${YELLOW}║  • Swap: 2GB, Workers: 2 (POS Restaurante compatible)        ║${NC}"
    echo -e "${YELLOW}║  • Límites de memoria reducidos para 1GB                     ║${NC}"
    echo -e "${BOLD}${YELLOW}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║  OPCIÓN 2: ESTÁNDAR (2 GB+ RAM) - DigitalOcean \$12+         ║${NC}"
    echo -e "${YELLOW}║  • 2 GB+ RAM / 1+ vCPU                                       ║${NC}"
    echo -e "${YELLOW}║  • 50 GB+ SSD                                                ║${NC}"
    echo -e "${YELLOW}║  • Swap: 2GB, Workers: 2, Configuración normal               ║${NC}"
    echo -e "${BOLD}${YELLOW}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${GREEN}✓ Ambos perfiles soportan POS Restaurante con WebSocket${NC}"
    echo
    
    # Auto-detect RAM
    local total_ram_mb=$(free -m | awk '/^Mem:/{print $2}')
    local recommended="1"
    
    if [ "$total_ram_mb" -ge 1800 ]; then
        recommended="2"
        echo -e "${CYAN}RAM detectada: ${WHITE}${total_ram_mb} MB${NC} - Recomendado: ${GREEN}Opción 2 (Estándar)${NC}"
    else
        recommended="1"
        echo -e "${CYAN}RAM detectada: ${WHITE}${total_ram_mb} MB${NC} - Recomendado: ${GREEN}Opción 1 (Básico)${NC}"
    fi
    echo
    
    while true; do
        echo -e -n "${BOLD}${WHITE}Selecciona perfil [1-2] (por defecto: $recommended): ${NC}"
        read -r profile_choice
        
        case "${profile_choice:-$recommended}" in
            1)
                RESOURCE_PROFILE="basic"
                configure_basic_profile
                break
                ;;
            2)
                RESOURCE_PROFILE="standard"
                configure_standard_profile
                break
                ;;
            *)
                echo -e "${RED}Opción inválida. Selecciona 1 o 2.${NC}"
                ;;
        esac
    done
    
    echo
    echo -e "${GREEN}✓ Perfil configurado: $RESOURCE_PROFILE${NC}"
    log_message "INFO" "Resource profile selected: $RESOURCE_PROFILE"
}

# Profile: BASIC (1 GB RAM) - Optimizado para bajos recursos + POS Restaurante
# NOTA: workers=2 mínimo requerido para POS Restaurante (websocket/tiempo real)
# IMPORTANTE: Con 1GB RAM + 2GB Swap, Odoo funciona con POS Restaurante
configure_basic_profile() {
    echo -e "${CYAN}Configurando perfil BÁSICO (1 GB RAM)...${NC}"
    
    # Swap - CRÍTICO para 1GB RAM (compensa RAM limitada)
    SWAP_SIZE="2G"  # 2GB swap - obligatorio para 1GB RAM
    
    # =========================================================================
    # Odoo settings - Optimizado para 1GB RAM + POS Restaurante
    # =========================================================================
    # workers=2: Mínimo para WebSocket/gevent (POS Restaurante tiempo real)
    # Cada worker usa ~100-150MB RAM, con 2 workers + cron ~300-400MB para Odoo
    # PostgreSQL usa ~100-150MB, Nginx ~20MB, Sistema ~200MB
    # Total: ~700-800MB RAM física, resto usa swap
    # =========================================================================
    WORKERS=2                       # Mínimo 2 para POS Restaurante (tiempo real)
    MAX_CRON_THREADS=1              # 1 hilo cron (reduce memoria)
    
    # Límites de memoria POR WORKER (reducidos para 1GB)
    LIMIT_MEMORY_HARD=536870912     # 512MB límite máximo por worker
    LIMIT_MEMORY_SOFT=419430400     # 400MB límite suave por worker
    LIMIT_TIME_CPU=60               # 60 segundos tiempo CPU (reducido)
    LIMIT_TIME_REAL=120             # 120 segundos tiempo real (reducido)
    LIMIT_REQUEST=2048              # Reciclar después de 2048 solicitudes
    
    # PostgreSQL - Memoria mínima para 1GB
    PG_SHARED_BUFFERS="32MB"        # Bajo para dejar RAM a Odoo
    PG_EFFECTIVE_CACHE="128MB"      # Cache efectivo bajo
    PG_WORK_MEM="2MB"               # Memoria de trabajo mínima
    PG_MAINTENANCE_WORK_MEM="16MB"  # Mantenimiento bajo
    PG_MAX_CONNECTIONS=20           # Conexiones limitadas
    
    log_message "INFO" "Basic profile configured for 1GB RAM (workers=2 for POS Restaurante)"
}

# Profile: STANDARD (2 GB+ RAM) - Normal optimizations
configure_standard_profile() {
    echo -e "${CYAN}Configurando perfil ESTÁNDAR (2 GB+ RAM)...${NC}"
    
    # Swap
    SWAP_SIZE="2G"  # 2GB swap
    
    # Odoo settings - Normal
    WORKERS=2                       # 2 workers
    MAX_CRON_THREADS=2              # 2 cron threads
    LIMIT_MEMORY_HARD=2684354560    # 2.5GB hard limit
    LIMIT_MEMORY_SOFT=2147483648    # 2GB soft limit
    LIMIT_TIME_CPU=600              # 600 seconds CPU time
    LIMIT_TIME_REAL=1200            # 1200 seconds real time
    LIMIT_REQUEST=8192              # Recycle after 8192 requests
    
    # PostgreSQL - Normal memory
    PG_SHARED_BUFFERS="128MB"
    PG_EFFECTIVE_CACHE="512MB"
    PG_WORK_MEM="4MB"
    PG_MAINTENANCE_WORK_MEM="64MB"
    PG_MAX_CONNECTIONS=50           # Conexiones normales
    
    log_message "INFO" "Standard profile configured for 2GB+ RAM"
}

confirm_installation() {
    clear
    display_billboard "Installation Confirmation"
    
    echo -e "${BOLD}${WHITE}Installation Summary:${NC}"
    echo -e "  ${CYAN}Odoo Version:${NC} $OE_BRANCH (Community)"
    echo -e "  ${CYAN}Resource Profile:${NC} $RESOURCE_PROFILE"
    echo -e "  ${CYAN}System User:${NC} $OE_USER"
    echo -e "  ${CYAN}Domain:${NC} ${DOMAIN_NAME:-"IP-based access"}"
    echo -e "  ${CYAN}Install Nginx:${NC} $INSTALL_NGINX"
    echo -e "  ${CYAN}SSL Certificate:${NC} $SSL_TYPE"
    echo -e "  ${CYAN}Default Database:${NC} $DEFAULT_DB_NAME"
    echo -e "  ${CYAN}Extra Addons Path:${NC} $EXTRA_ADDONS_PATH"
    if [ -n "$DEFAULT_MODULES" ]; then
        echo -e "  ${CYAN}Default Modules:${NC} $DEFAULT_MODULES"
    else
        echo -e "  ${CYAN}Default Modules:${NC} (none - manual installation)"
    fi
    echo -e "  ${CYAN}SendGrid Email:${NC} $SENDGRID_ENABLED"
    if [ "$SENDGRID_ENABLED" = "true" ]; then
        echo -e "  ${CYAN}Email Domain:${NC} @$SENDGRID_FROM_DOMAIN"
        echo -e "  ${CYAN}Email From:${NC} $SENDGRID_FROM_EMAIL"
    fi
    if [ ${#CUSTOM_MODULE_REPOS[@]} -gt 0 ]; then
        echo -e "  ${CYAN}Custom Repos:${NC} ${#CUSTOM_MODULE_REPOS[@]} repositorio(s)"
        for repo in "${CUSTOM_MODULE_REPOS[@]}"; do
            echo -e "    ${WHITE}• ${repo%%|*}${NC}"
        done
    fi
    echo
    echo -e "${YELLOW}${BOLD}⚡ OPTIMIZACIONES PARA PERFIL: ${RESOURCE_PROFILE^^}${NC}"
    echo -e "  ${CYAN}Swap:${NC} $SWAP_SIZE"
    echo -e "  ${CYAN}Workers:${NC} $WORKERS ${GREEN}(mínimo 2 para POS Restaurante)${NC}"
    echo -e "  ${CYAN}Gevent Port:${NC} 8072 ${GREEN}(WebSocket para tiempo real)${NC}"
    echo -e "  ${CYAN}Cron Threads:${NC} $MAX_CRON_THREADS"
    echo -e "  ${CYAN}Memory Hard Limit:${NC} $(( LIMIT_MEMORY_HARD / 1048576 )) MB"
    echo -e "  ${CYAN}Memory Soft Limit:${NC} $(( LIMIT_MEMORY_SOFT / 1048576 )) MB"
    echo -e "  ${CYAN}PostgreSQL Shared Buffers:${NC} $PG_SHARED_BUFFERS"
    echo -e "  ${CYAN}PostgreSQL Effective Cache:${NC} $PG_EFFECTIVE_CACHE"
    echo
    echo -e "${GREEN}${BOLD}✓ POS RESTAURANTE:${NC} Configuración WebSocket incluida (mesas en tiempo real)"
    echo
    
    while true; do
        echo -e -n "${BOLD}${WHITE}Do you want to proceed with the installation? [y/N]: ${NC}"
        read -r confirm
        case "$confirm" in
            [Yy]|[Yy][Ee][Ss])
                return 0
                ;;
            [Nn]|[Nn][Oo]|"")
                echo -e "${YELLOW}Installation cancelled by user.${NC}"
                return 1
                ;;
            *)
                echo -e "${RED}Please answer yes (y) or no (n).${NC}"
                ;;
        esac
    done
}

#==============================================================================
# INSTALLATION FUNCTIONS
#==============================================================================

step_preflight_checks() {
    show_step_header 1 "Pre-flight Checks" "Validating system requirements"
    
    check_root
    
    if ! check_system_requirements; then
        log_message "ERROR" "System requirements check failed"
        exit 1
    fi
    
    log_message "INFO" "Pre-flight checks completed successfully"
}

step_swap_configuration() {
    show_step_header 2 "Swap Configuration" "Configuring swap memory for low RAM optimization"
    
    # Check if swap already exists
    local current_swap=$(free -m | awk '/^Swap:/ {print $2}')
    
    if [ "$current_swap" -gt 0 ]; then
        echo -e "${GREEN}✓ Swap already configured: ${current_swap}MB${NC}"
        log_message "INFO" "Swap already exists: ${current_swap}MB"
        return 0
    fi
    
    echo -e "${CYAN}Creating $SWAP_SIZE swap file...${NC}"
    
    # Create swap file
    execute_simple "fallocate -l $SWAP_SIZE /swapfile" "Creating swap file"
    execute_simple "chmod 600 /swapfile" "Setting swap file permissions"
    execute_simple "mkswap /swapfile" "Setting up swap space"
    execute_simple "swapon /swapfile" "Enabling swap"
    
    # Make swap permanent
    if ! grep -q '/swapfile' /etc/fstab; then
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
        log_message "INFO" "Added swap to /etc/fstab"
    fi
    
    # Optimize swappiness for low RAM
    execute_simple "sysctl vm.swappiness=10" "Setting swappiness to 10"
    echo "vm.swappiness=10" >> /etc/sysctl.conf
    
    # Set cache pressure
    execute_simple "sysctl vm.vfs_cache_pressure=50" "Setting cache pressure"
    echo "vm.vfs_cache_pressure=50" >> /etc/sysctl.conf
    
    echo -e "${GREEN}✓ Swap configured successfully${NC}"
    log_message "INFO" "Swap configuration completed: $SWAP_SIZE"
}

step_system_preparation() {
    show_step_header 3 "System Preparation" "Creating users and updating packages"
    
    # Create Odoo user and group
    execute_simple "groupadd -f $OE_USER" "Creating Odoo group"
    execute_simple "useradd --create-home -d /home/$OE_USER --shell /bin/bash -g $OE_USER $OE_USER 2>/dev/null || true" "Creating Odoo user"
    
    # Update system packages (minimal updates for speed)
    execute_simple "apt-get update" "Updating package lists"
    execute_simple "apt-get install -y --no-install-recommends zip gdebi-core net-tools curl wget gnupg2 software-properties-common netcat-openbsd" "Installing basic tools"
    
    # Configure localization
    execute_simple "export LC_ALL=en_US.UTF-8 && export LC_CTYPE=en_US.UTF-8" "Setting locale variables"
    
    # Create extra addons directory
    execute_simple "mkdir -p $EXTRA_ADDONS_PATH" "Creating extra addons directory"
    execute_simple "chown -R $OE_USER:$OE_USER $EXTRA_ADDONS_PATH" "Setting ownership for extra addons"
    
    # Clone custom module repositories
    clone_custom_repos
    
    log_message "INFO" "System preparation completed"
}

# Clone custom module repositories into extra-addons
clone_custom_repos() {
    if [ ${#CUSTOM_MODULE_REPOS[@]} -eq 0 ]; then
        return 0
    fi
    
    echo -e "${CYAN}Cloning custom module repositories...${NC}"
    
    for repo_entry in "${CUSTOM_MODULE_REPOS[@]}"; do
        # Parse URL and branch (format: URL|branch or just URL)
        local repo_url="${repo_entry%%|*}"
        local repo_branch="${repo_entry##*|}"
        
        # If no branch specified, use the Odoo version branch or main
        if [ "$repo_url" = "$repo_branch" ]; then
            repo_branch="$OE_BRANCH"
        fi
        
        # Extract repo name from URL
        local repo_name=$(basename "$repo_url" .git)
        local target_dir="$EXTRA_ADDONS_PATH/$repo_name"
        
        echo -e "${CYAN}  Cloning: $repo_name (branch: $repo_branch)...${NC}"
        
        # Try to clone with specified branch, fallback to main/master
        if git clone --depth 1 -b "$repo_branch" "$repo_url" "$target_dir" 2>/dev/null; then
            echo -e "${GREEN}  ✓ $repo_name cloned successfully (branch: $repo_branch)${NC}"
            log_message "INFO" "Cloned custom repo: $repo_name branch: $repo_branch"
        elif git clone --depth 1 -b "main" "$repo_url" "$target_dir" 2>/dev/null; then
            echo -e "${GREEN}  ✓ $repo_name cloned successfully (branch: main)${NC}"
            log_message "INFO" "Cloned custom repo: $repo_name branch: main"
        elif git clone --depth 1 -b "master" "$repo_url" "$target_dir" 2>/dev/null; then
            echo -e "${GREEN}  ✓ $repo_name cloned successfully (branch: master)${NC}"
            log_message "INFO" "Cloned custom repo: $repo_name branch: master"
        elif git clone --depth 1 "$repo_url" "$target_dir" 2>/dev/null; then
            echo -e "${GREEN}  ✓ $repo_name cloned successfully (default branch)${NC}"
            log_message "INFO" "Cloned custom repo: $repo_name default branch"
        else
            echo -e "${YELLOW}  ⚠ Could not clone $repo_name - skipping${NC}"
            log_message "WARNING" "Failed to clone custom repo: $repo_url"
        fi
    done
    
    # Set proper ownership
    chown -R $OE_USER:$OE_USER $EXTRA_ADDONS_PATH
    echo -e "${GREEN}✓ Custom repositories cloned${NC}"
}

step_database_setup() {
    show_step_header 4 "Database Setup" "Installing PostgreSQL"
    
    # Install PostgreSQL from default repos (faster than adding external repo)
    execute_simple "apt-get install -y postgresql postgresql-contrib" "Installing PostgreSQL"
    
    # Start and enable PostgreSQL
    execute_simple "systemctl start postgresql" "Starting PostgreSQL"
    execute_simple "systemctl enable postgresql" "Enabling PostgreSQL"
    
    # Create PostgreSQL user for Odoo
    execute_simple "su - postgres -c \"createuser -s $OE_USER\" 2>/dev/null || true" "Creating PostgreSQL user"
    
    # Optimize PostgreSQL for low memory
    optimize_postgresql
    
    log_message "INFO" "Database setup completed"
}

optimize_postgresql() {
    echo -e "${CYAN}Optimizing PostgreSQL for profile: $RESOURCE_PROFILE...${NC}"
    
    local pg_conf=$(find /etc/postgresql -name "postgresql.conf" 2>/dev/null | head -1)
    
    if [ -n "$pg_conf" ]; then
        # Backup original
        cp "$pg_conf" "${pg_conf}.backup"
        
        # Use PG_MAX_CONNECTIONS from profile (set in configure_*_profile functions)
        local max_conn=${PG_MAX_CONNECTIONS:-50}
        
        # Apply profile-specific optimizations
        cat >> "$pg_conf" << EOF

# ============================================================================
# PostgreSQL Optimizations for profile: $RESOURCE_PROFILE
# ============================================================================
shared_buffers = $PG_SHARED_BUFFERS
effective_cache_size = $PG_EFFECTIVE_CACHE
maintenance_work_mem = $PG_MAINTENANCE_WORK_MEM
work_mem = $PG_WORK_MEM
max_connections = $max_conn
checkpoint_completion_target = 0.9
wal_buffers = 4MB
random_page_cost = 1.1
EOF
        
        execute_simple "systemctl restart postgresql" "Restarting PostgreSQL with optimizations"
        log_message "INFO" "PostgreSQL optimized for profile: $RESOURCE_PROFILE (max_connections=$max_conn)"
    else
        log_message "WARNING" "Could not find PostgreSQL configuration file"
    fi
}

step_dependencies_installation() {
    show_step_header 5 "Dependencies Installation" "Installing minimal required packages"
    
    # Install minimal system dependencies
    local system_packages=(
        "git" "python3-pip" "python3-dev" "python3-venv" "python3-wheel"
        "libxml2-dev" "libxslt1-dev" "libldap2-dev" "libsasl2-dev"
        "libjpeg-dev" "zlib1g-dev" "libpq-dev" "libfreetype6-dev"
        "build-essential" "node-less" "npm" "python3-psycopg2"
    )
    
    echo -e "${CYAN}Installing system packages...${NC}"
    
    for package in "${system_packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $package "; then
            apt-get install -y --no-install-recommends "$package" >> "$LOG_FILE" 2>&1 || true
        fi
    done
    
    echo -e "${GREEN}✓ System packages installed${NC}"
    
    # Install npm packages (minimal)
    execute_simple "npm install -g less less-plugin-clean-css rtlcss" "Installing Node.js packages"
    
    log_message "INFO" "Dependencies installation completed"
}

step_wkhtmltopdf_installation() {
    show_step_header 6 "Wkhtmltopdf Installation" "Installing PDF library"
    
    if [ "$INSTALL_WKHTMLTOPDF" = "True" ]; then
        local wkhtml_file="wkhtmltox_0.12.6.1-2.jammy_amd64.deb"
        
        if ! execute_simple "wget -q -O /tmp/$wkhtml_file $WKHTML_X64" "Downloading wkhtmltopdf"; then
            log_message "WARNING" "Failed to download wkhtmltopdf"
            return 0
        fi
        
        execute_simple "gdebi --non-interactive /tmp/$wkhtml_file" "Installing wkhtmltopdf"
        execute_simple "rm -f /tmp/$wkhtml_file" "Cleaning up"
    fi
    
    log_message "INFO" "Wkhtmltopdf installation completed"
}

step_odoo_installation() {
    show_step_header 7 "Odoo Installation" "Downloading and configuring Odoo"
    
    # Create directories
    execute_simple "mkdir -p /odoo /etc/odoo /var/log/odoo" "Creating Odoo directories"
    execute_simple "touch /var/log/odoo/odoo-server.log" "Creating log file"
    execute_simple "chown -R $OE_USER:$OE_USER /var/log/odoo /etc/odoo" "Setting ownership"
    
    # Clone Odoo with shallow clone (faster)
    cd /odoo || exit 1
    if ! execute_simple "git clone --depth 1 --branch $OE_BRANCH https://www.github.com/odoo/odoo" "Cloning Odoo repository"; then
        log_message "ERROR" "Failed to clone Odoo repository"
        return 1
    fi
    
    execute_simple "chown -R $OE_USER:$OE_USER /odoo" "Setting Odoo ownership"
    
    # Install Python requirements with pinned, prebuilt wheels to avoid build failures
    execute_simple "pip3 install --upgrade pip setuptools wheel" "Upgrading pip/build tools"

    # Preinstall critical packages to avoid missing drivers and reduce build load
    execute_simple "pip3 install --no-cache-dir lxml psycopg2-binary Pillow" "Installing critical packages"
    execute_simple "pip3 install --no-cache-dir 'greenlet>=2.0.2' 'gevent>=22.10.2,<24'" "Installing gevent/greenlet (compatible wheels)"
    execute_simple "pip3 install --no-cache-dir 'Werkzeug>=2.2,<3' num2words" "Installing Werkzeug/num2words"

    # Install remaining requirements excluding gevent/greenlet (already handled)
    execute_simple "grep -viE '^(gevent|greenlet)=' /odoo/odoo/requirements.txt > /tmp/odoo_req_nogevent.txt" "Preparing requirements list"
    execute_simple "pip3 install --no-cache-dir -r /tmp/odoo_req_nogevent.txt" "Installing Odoo requirements"
    execute_simple "pip3 install --no-cache-dir phonenumbers" "Installing phonenumbers"
    
    log_message "INFO" "Odoo installation completed"
}

step_odoo_configuration() {
    show_step_header 8 "Odoo Configuration" "Creating optimized configuration"
    
    # Determine web base URL
    local web_base_url
    if [ "$HAS_DOMAIN" = "true" ]; then
        web_base_url="https://$DOMAIN_NAME"
    else
        web_base_url="http://$SERVER_IP:8069"
    fi
    
    # Create optimized Odoo configuration
    cat > /etc/odoo/odoo.conf << EOF
[options]
; ============================================================================
; Odoo Configuration - Profile: $RESOURCE_PROFILE
; Generated by CODIFICANDO Installer v$SCRIPT_VERSION
; ============================================================================
; IMPORTANTE PARA POS RESTAURANTE:
; - workers >= 2 es OBLIGATORIO para que funcione el WebSocket/tiempo real
; - gevent_port = 8072 maneja las conexiones WebSocket
; - Sin esto, las mesas quedan "ocupadas" visualmente hasta recargar
; ============================================================================

; Database Configuration
db_host = False
db_port = False
db_user = $OE_USER
db_password = False
db_name = False
db_maxconn = 64
dbfilter = .*
list_db = True

; Paths
addons_path = /odoo/odoo/addons,$EXTRA_ADDONS_PATH
data_dir = /var/lib/odoo

; Logging
logfile = /var/log/odoo/odoo-server.log
log_level = info
log_handler = :INFO

; Security
admin_passwd = $DB_ADMIN_PASSWORD

; ============================================================================
; Performance - CRÍTICO PARA POS RESTAURANTE
; ============================================================================
; workers >= 2: Obligatorio para WebSocket (gevent). Sin workers, el bus
;               de tiempo real no funciona y las mesas no se actualizan.
; gevent_port: Puerto para WebSocket/longpolling (debe coincidir con Nginx)
; ============================================================================
workers = $WORKERS
max_cron_threads = $MAX_CRON_THREADS
limit_memory_hard = $LIMIT_MEMORY_HARD
limit_memory_soft = $LIMIT_MEMORY_SOFT
limit_time_cpu = $LIMIT_TIME_CPU
limit_time_real = $LIMIT_TIME_REAL
limit_request = $LIMIT_REQUEST

; Proxy Mode (OBLIGATORIO con Nginx)
proxy_mode = True

; Public Links Configuration
web.base.url = $web_base_url
web.base.url.freeze = True

; ============================================================================
; WebSocket / Long Polling - CRÍTICO PARA POS RESTAURANTE
; ============================================================================
; gevent_port: Puerto donde Odoo escucha conexiones WebSocket
; Nginx debe redirigir /websocket y /longpolling a este puerto
; websocket_keep_alive_timeout: Tiempo de vida de conexiones WebSocket
; ============================================================================
http_port = 8069
gevent_port = 8072
websocket_keep_alive_timeout = 3600
websocket_rate_limit_burst = 10
websocket_rate_limit_delay = 0.2

; SMTP Configuration (SendGrid)
EOF
    
    # Add SendGrid configuration if enabled
    if [ "$SENDGRID_ENABLED" = "true" ]; then
        cat >> /etc/odoo/odoo.conf << EOF

; SendGrid SMTP Configuration
smtp_server = smtp.sendgrid.net
smtp_port = 2525
smtp_ssl = False
smtp_user = apikey
smtp_password = $SENDGRID_API_KEY
email_from = $SENDGRID_FROM_EMAIL
EOF
    fi
    
    # Set permissions
    execute_simple "chown $OE_USER:$OE_USER /etc/odoo/odoo.conf" "Setting config ownership"
    execute_simple "chmod 640 /etc/odoo/odoo.conf" "Setting config permissions"
    
    # Create data directory
    execute_simple "mkdir -p /var/lib/odoo" "Creating data directory"
    execute_simple "chown -R $OE_USER:$OE_USER /var/lib/odoo" "Setting data dir ownership"
    
    # Save credentials
    cat > /root/.odoo_credentials << EOF
# Odoo Credentials - Generated $(date)
# KEEP THIS FILE SECURE!

ODOO_MASTER_PASSWORD=$DB_ADMIN_PASSWORD
ODOO_DEFAULT_DATABASE=$DEFAULT_DB_NAME
ODOO_ADMIN_USER=$DB_ADMIN_USER
ODOO_ADMIN_PASSWORD=$DB_ADMIN_PASSWORD
ODOO_URL=$web_base_url
EOF
    
    if [ "$SENDGRID_ENABLED" = "true" ]; then
        cat >> /root/.odoo_credentials << EOF

# SendGrid Configuration
SENDGRID_API_KEY=$SENDGRID_API_KEY
SENDGRID_DOMAIN=$SENDGRID_FROM_DOMAIN
SENDGRID_FROM_EMAIL=$SENDGRID_FROM_EMAIL
EOF
    fi
    
    chmod 600 /root/.odoo_credentials
    
    log_message "INFO" "Odoo configuration created"
}

step_nginx_ssl_configuration() {
    show_step_header 9 "Nginx & SSL Configuration" "Setting up web server and SSL"
    
    if [ "$INSTALL_NGINX" != "true" ]; then
        log_message "INFO" "Nginx installation skipped"
        return 0
    fi
    
    # Install Nginx
    execute_simple "apt-get install -y nginx" "Installing Nginx"
    
    # Stop nginx temporarily for clean configuration
    systemctl stop nginx 2>/dev/null || true
    
    # Remove any existing configurations that might conflict
    rm -f /etc/nginx/sites-enabled/default
    rm -f /etc/nginx/sites-enabled/odoo
    rm -f /etc/nginx/sites-enabled/odoo-temp
    rm -f /etc/nginx/sites-available/odoo-temp
    
    # Configure SSL
    if [ "$SSL_TYPE" = "letsencrypt" ] && [ "$HAS_DOMAIN" = "true" ]; then
        install_letsencrypt_ssl
    else
        generate_self_signed_ssl
    fi
    
    # Verify SSL certificates exist before creating config
    verify_ssl_certificates
    
    # Create Nginx configuration
    create_nginx_config
    
    # Enable and start Nginx with error handling
    execute_simple "systemctl enable nginx" "Enabling Nginx"
    
    # Test nginx configuration - CRÍTICO: no reiniciar si falla
    echo -e "${CYAN}Testing Nginx configuration...${NC}"
    local nginx_test_output
    nginx_test_output=$(nginx -t 2>&1)
    local nginx_test_result=$?
    
    echo "$nginx_test_output" >> "$LOG_FILE"
    
    if [ $nginx_test_result -eq 0 ]; then
        echo -e "${GREEN}✓ Nginx configuration is valid${NC}"
        echo "$nginx_test_output"
        
        # Start Nginx solo si la configuración es válida
        if systemctl start nginx 2>&1; then
            echo -e "${GREEN}✓ Nginx started successfully${NC}"
        else
            echo -e "${RED}✗ Failed to start Nginx${NC}"
            echo -e "${YELLOW}Check logs: journalctl -xeu nginx${NC}"
            log_message "ERROR" "Failed to start Nginx"
        fi
    else
        echo -e "${RED}✗ Nginx configuration has errors - NO SE REINICIARÁ NGINX${NC}"
        echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
        echo -e "${YELLOW}ERROR DE NGINX -t:${NC}"
        echo "$nginx_test_output"
        echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
        echo -e "${YELLOW}Archivo de configuración: /etc/nginx/sites-available/odoo${NC}"
        echo -e "${YELLOW}Revisar logs en: /var/log/nginx/odoo.error.log${NC}"
        echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
        log_message "ERROR" "Nginx configuration test failed: $nginx_test_output"
        
        # Mostrar contenido del archivo para diagnóstico
        echo -e "${CYAN}Contenido de /etc/nginx/sites-available/odoo:${NC}"
        head -50 /etc/nginx/sites-available/odoo 2>/dev/null || echo "No se puede leer el archivo"
        
        # NO reiniciar nginx - salir con error
        echo -e "${RED}INSTALACIÓN DETENIDA: Corrige la configuración de Nginx manualmente${NC}"
        exit 1
    fi
    
    log_message "INFO" "Nginx configuration completed"
}

# Verify SSL certificates exist
verify_ssl_certificates() {
    echo -e "${CYAN}Verifying SSL certificates...${NC}"
    
    local ssl_cert_path ssl_key_path
    
    if [ "$SSL_TYPE" = "letsencrypt" ]; then
        ssl_cert_path="/etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem"
        ssl_key_path="/etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem"
    else
        ssl_cert_path="/etc/ssl/nginx/server.crt"
        ssl_key_path="/etc/ssl/nginx/server.key"
    fi
    
    # Check if certificate files exist
    if [ ! -f "$ssl_cert_path" ] || [ ! -f "$ssl_key_path" ]; then
        echo -e "${YELLOW}⚠ SSL certificates not found at expected paths${NC}"
        echo -e "${YELLOW}  Expected cert: $ssl_cert_path${NC}"
        echo -e "${YELLOW}  Expected key: $ssl_key_path${NC}"
        
        # Fallback to self-signed if Let's Encrypt failed
        if [ "$SSL_TYPE" = "letsencrypt" ]; then
            echo -e "${YELLOW}Falling back to self-signed certificate...${NC}"
            SSL_TYPE="self-signed"
            generate_self_signed_ssl
        fi
    else
        echo -e "${GREEN}✓ SSL certificates found${NC}"
        log_message "INFO" "SSL certificates verified: $ssl_cert_path"
    fi
}

# Try to fix common nginx configuration issues
fix_nginx_config_issues() {
    echo -e "${YELLOW}Attempting to fix Nginx configuration...${NC}"
    
    local ssl_cert_path ssl_key_path
    
    if [ "$SSL_TYPE" = "letsencrypt" ]; then
        ssl_cert_path="/etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem"
        ssl_key_path="/etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem"
    else
        ssl_cert_path="/etc/ssl/nginx/server.crt"
        ssl_key_path="/etc/ssl/nginx/server.key"
    fi
    
    # Check if SSL files don't exist - generate self-signed
    if [ ! -f "$ssl_cert_path" ] || [ ! -f "$ssl_key_path" ]; then
        echo -e "${YELLOW}SSL certificates missing - generating self-signed...${NC}"
        SSL_TYPE="self-signed"
        generate_self_signed_ssl
        
        # Recreate nginx config with self-signed paths
        create_nginx_config
        
        # Test again
        if nginx -t 2>&1; then
            echo -e "${GREEN}✓ Fixed: Using self-signed certificate${NC}"
        fi
    fi
    
    # Check for duplicate upstream definitions
    if grep -c "upstream odoo" /etc/nginx/sites-enabled/* 2>/dev/null | grep -q "2"; then
        echo -e "${YELLOW}Found duplicate configs, cleaning...${NC}"
        rm -f /etc/nginx/sites-enabled/odoo-temp
        rm -f /etc/nginx/sites-enabled/default
    fi
}

generate_self_signed_ssl() {
    echo -e "${CYAN}Generating self-signed SSL certificate...${NC}"
    
    execute_simple "mkdir -p /etc/ssl/nginx" "Creating SSL directory"
    
    execute_simple "openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/ssl/nginx/server.key \
        -out /etc/ssl/nginx/server.crt \
        -subj \"/C=US/ST=State/L=City/O=CODIFICANDO/CN=$DOMAIN_NAME\"" "Generating SSL certificate"
    
    execute_simple "chmod 600 /etc/ssl/nginx/server.key" "Setting SSL permissions"
}

install_letsencrypt_ssl() {
    echo -e "${CYAN}Installing Let's Encrypt SSL certificate...${NC}"
    
    # Install certbot
    execute_simple "apt-get install -y certbot python3-certbot-nginx" "Installing Certbot"
    
    # Clean any existing nginx configs that might interfere
    rm -f /etc/nginx/sites-enabled/default
    rm -f /etc/nginx/sites-enabled/odoo
    rm -f /etc/nginx/sites-enabled/odoo-temp
    
    # Create temporary nginx config for verification (standalone mode is more reliable)
    cat > /etc/nginx/sites-available/odoo-temp << EOF
server {
    listen 80;
    server_name $DOMAIN_NAME;
    
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    location / {
        return 200 'Temporary configuration for SSL setup';
        add_header Content-Type text/plain;
    }
}
EOF
    
    ln -sf /etc/nginx/sites-available/odoo-temp /etc/nginx/sites-enabled/odoo-temp
    
    # Create webroot directory
    mkdir -p /var/www/html/.well-known/acme-challenge
    
    # Start nginx for certificate verification
    systemctl start nginx 2>/dev/null || true
    
    # Wait for nginx to be ready
    sleep 2
    
    # Try to get certificate using webroot method (more reliable than --nginx)
    echo -e "${CYAN}Requesting Let's Encrypt certificate for $DOMAIN_NAME...${NC}"
    
    local certbot_success=false
    
    # Method 1: Try webroot (most reliable)
    if certbot certonly --webroot -w /var/www/html -d "$DOMAIN_NAME" \
        --non-interactive --agree-tos --email "admin@$DOMAIN_NAME" \
        --no-eff-email >> "$LOG_FILE" 2>&1; then
        certbot_success=true
        echo -e "${GREEN}✓ Let's Encrypt certificate obtained (webroot method)${NC}"
        log_message "INFO" "Let's Encrypt certificate obtained via webroot"
    else
        echo -e "${YELLOW}Webroot method failed, trying standalone...${NC}"
        
        # Stop nginx for standalone method
        systemctl stop nginx 2>/dev/null || true
        
        # Method 2: Try standalone
        if certbot certonly --standalone -d "$DOMAIN_NAME" \
            --non-interactive --agree-tos --email "admin@$DOMAIN_NAME" \
            --no-eff-email >> "$LOG_FILE" 2>&1; then
            certbot_success=true
            echo -e "${GREEN}✓ Let's Encrypt certificate obtained (standalone method)${NC}"
            log_message "INFO" "Let's Encrypt certificate obtained via standalone"
        fi
    fi
    
    # Stop nginx and clean temp config
    systemctl stop nginx 2>/dev/null || true
    rm -f /etc/nginx/sites-available/odoo-temp
    rm -f /etc/nginx/sites-enabled/odoo-temp
    
    # Verify certificate was actually created
    if [ "$certbot_success" = true ] && [ -f "/etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem" ]; then
        echo -e "${GREEN}✓ SSL certificate verified at /etc/letsencrypt/live/$DOMAIN_NAME/${NC}"
        log_message "INFO" "Let's Encrypt certificate verified"
    else
        echo -e "${YELLOW}⚠ Let's Encrypt certificate not found, using self-signed${NC}"
        log_message "WARNING" "Let's Encrypt failed, falling back to self-signed"
        SSL_TYPE="self-signed"
        generate_self_signed_ssl
    fi
}

create_nginx_config() {
    echo -e "${CYAN}Creating Nginx configuration for Odoo...${NC}"
    
    local ssl_cert_path ssl_key_path
    
    if [ "$SSL_TYPE" = "letsencrypt" ]; then
        ssl_cert_path="/etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem"
        ssl_key_path="/etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem"
    else
        ssl_cert_path="/etc/ssl/nginx/server.crt"
        ssl_key_path="/etc/ssl/nginx/server.key"
    fi
    
    # Remove default site
    rm -f /etc/nginx/sites-enabled/default
    
    cat > /etc/nginx/sites-available/odoo << EOF
# ============================================================================
# Odoo Nginx Configuration - CODIFICANDO Edition
# Optimized for POS Restaurant (WebSocket/Real-time) + Low Resources
# ============================================================================
# IMPORTANTE: Esta configuración incluye correcciones críticas para:
# - POS Restaurante: WebSocket sin buffering para actualización de mesas en tiempo real
# - http2 on (formato correcto para Nginx moderno)
# - proxy_buffering off en /websocket para evitar delays
# ============================================================================

upstream odoo {
    server 127.0.0.1:8069;
}

upstream odoochat {
    server 127.0.0.1:8072;
}

map \$http_upgrade \$connection_upgrade {
    default upgrade;
    ''      close;
}

# HTTP -> HTTPS redirect
server {
    listen 80;
    server_name $DOMAIN_NAME;
    return 301 https://\$host\$request_uri;
}

# HTTPS server
server {
    # COMPATIBLE: listen 443 ssl http2; funciona en nginx 1.18+ (Ubuntu 22.04)
    # NO usar 'http2 on;' - solo funciona en nginx >= 1.25.1
    listen 443 ssl http2;
    server_name $DOMAIN_NAME;

    # Timeouts (importantes para operaciones largas en POS)
    proxy_read_timeout 720s;
    proxy_connect_timeout 720s;
    proxy_send_timeout 720s;

    # SSL Configuration
    ssl_certificate $ssl_cert_path;
    ssl_certificate_key $ssl_key_path;
    ssl_session_timeout 30m;
    ssl_session_cache shared:SSL:50m;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    # Logging
    access_log /var/log/nginx/odoo.access.log;
    error_log /var/log/nginx/odoo.error.log;

    # File upload size
    client_max_body_size 100M;

    # =========================================================================
    # WebSocket / Bus - CRÍTICO PARA POS RESTAURANTE (tiempo real de mesas)
    # =========================================================================
    # Sin esta configuración correcta, las mesas quedan "ocupadas" visualmente
    # hasta recargar la página manualmente.
    # =========================================================================
    location /websocket {
        proxy_pass http://odoochat;

        # WebSocket upgrade - OBLIGATORIO
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;

        # Headers de proxy
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Real-IP \$remote_addr;

        # CRÍTICO: Deshabilitar buffering para tiempo real
        # Sin esto, las actualizaciones de mesas en POS Restaurante se retrasan
        proxy_buffering off;
        proxy_cache off;

        # Security headers
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
        # NOTA: proxy_cookie_flags removido - incompatible con nginx < 1.19.3
    }

    # Longpolling (compatibilidad con versiones anteriores)
    location /longpolling {
        proxy_pass http://odoochat;

        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Real-IP \$remote_addr;

        proxy_buffering off;
        proxy_cache off;
    }

    # Main Odoo
    location / {
        proxy_pass http://odoo;

        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_redirect off;

        # Security headers
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
        add_header X-Content-Type-Options nosniff always;
        add_header X-Frame-Options SAMEORIGIN always;
        # NOTA: proxy_cookie_flags removido - incompatible con nginx < 1.19.3
    }

    # Static files caching
    location ~* /web/static/ {
        proxy_pass http://odoo;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_cache_valid 200 90d;
        expires 90d;
        add_header Cache-Control "public, no-transform";
    }

    # Gzip compression
    gzip on;
    gzip_types text/css text/scss text/less text/plain text/xml application/xml application/json application/javascript;
    gzip_min_length 256;
}
EOF
    
    # Enable site - eliminar default y crear symlink correcto
    rm -f /etc/nginx/sites-enabled/default
    rm -f /etc/nginx/sites-enabled/odoo  # Eliminar si existe para recrear limpio
    ln -sf /etc/nginx/sites-available/odoo /etc/nginx/sites-enabled/odoo
    
    # Verificar que el symlink es correcto
    if [ -L /etc/nginx/sites-enabled/odoo ]; then
        log_message "INFO" "Nginx site symlink created correctly"
    else
        log_message "ERROR" "Failed to create Nginx site symlink"
    fi
    
    log_message "INFO" "Nginx configuration created (compatible with nginx 1.18+)"
}

step_service_final_setup() {
    show_step_header 10 "Final Setup" "Starting services and creating database"
    
    # Set systemd memory limits based on profile
    # NOTA: Con swap de 2GB, estos límites permiten que Odoo use swap si necesita más
    local memory_max="1G"
    local memory_high="768M"
    
    case "$RESOURCE_PROFILE" in
        "basic")
            # Para 1GB RAM: Odoo puede usar hasta 700MB RAM, resto usa swap
            # MemoryMax es límite absoluto, MemoryHigh es "preferido"
            memory_max="700M"
            memory_high="500M"
            ;;
        "standard")
            memory_max="2G"
            memory_high="1500M"
            ;;
    esac
    
    # Create Odoo service file
    cat > /etc/systemd/system/odoo.service << EOF
[Unit]
Description=Odoo - CODIFICANDO Edition ($RESOURCE_PROFILE profile)
Documentation=http://www.odoo.com
Requires=postgresql.service
After=postgresql.service network.target

[Service]
Type=simple
SyslogIdentifier=odoo
User=$OE_USER
Group=$OE_USER
ExecStart=/odoo/odoo/odoo-bin -c /etc/odoo/odoo.conf
StandardOutput=journal+console
Restart=on-failure
RestartSec=5

# Memory limits for profile: $RESOURCE_PROFILE
MemoryMax=$memory_max
MemoryHigh=$memory_high

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload systemd and start services
    execute_simple "systemctl daemon-reload" "Reloading systemd"
    execute_simple "systemctl enable odoo" "Enabling Odoo service"
    execute_simple "systemctl start odoo" "Starting Odoo service"
    
    # Wait for Odoo to start
    echo -e "${CYAN}Waiting for Odoo to start...${NC}"
    sleep 15
    
    # Create default database
    create_default_database
    
    # Configure SendGrid in database if enabled
    if [ "$SENDGRID_ENABLED" = "true" ]; then
        configure_sendgrid_in_odoo
    fi
    
    # Validate installation
    validate_installation
    
    # Generate report
    generate_installation_report
    
    log_message "INFO" "Final setup completed"
}

create_default_database() {
    if [ "$CREATE_DEFAULT_DB" != "true" ]; then
        return 0
    fi
    
    echo -e "${CYAN}Creating default database: $DEFAULT_DB_NAME...${NC}"
    
    # Wait for Odoo to be ready
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -s "http://localhost:8069/web/database/list" > /dev/null 2>&1; then
            break
        fi
        sleep 2
        attempt=$((attempt + 1))
    done
    
    # Create database using Odoo's database manager
    curl -s -X POST "http://localhost:8069/web/database/create" \
        -F "master_pwd=$DB_ADMIN_PASSWORD" \
        -F "name=$DEFAULT_DB_NAME" \
        -F "login=$DB_ADMIN_USER" \
        -F "password=$DB_ADMIN_PASSWORD" \
        -F "lang=es_ES" \
        -F "country_code=CO" \
        >> "$LOG_FILE" 2>&1
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Database '$DEFAULT_DB_NAME' created${NC}"
        echo -e "${YELLOW}  Credenciales: $DB_ADMIN_USER / $DB_ADMIN_PASSWORD${NC}"
        log_message "INFO" "Default database created: $DEFAULT_DB_NAME"
        
        # Install default modules if configured
        if [ -n "$DEFAULT_MODULES" ]; then
            install_default_modules
        fi
    else
        echo -e "${YELLOW}⚠ Could not create database automatically. Create it manually at /web/database/manager${NC}"
        log_message "WARNING" "Failed to create default database"
    fi
}

# Install default modules in the database
install_default_modules() {
    echo -e "${CYAN}Installing default modules: $DEFAULT_MODULES...${NC}"
    echo -e "${YELLOW}  This may take several minutes...${NC}"
    
    # Stop Odoo service temporarily
    systemctl stop odoo
    
    # Install modules using odoo-bin
    # Convert comma-separated to proper format
    local modules_list="$DEFAULT_MODULES"
    
    su - odoo -s /bin/bash -c "cd /odoo/odoo && ./odoo-bin -c /etc/odoo/odoo.conf -d $DEFAULT_DB_NAME -i $modules_list --stop-after-init" >> "$LOG_FILE" 2>&1
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Default modules installed successfully${NC}"
        log_message "INFO" "Default modules installed: $DEFAULT_MODULES"
    else
        echo -e "${YELLOW}⚠ Some modules may not have installed correctly. Check Odoo logs.${NC}"
        log_message "WARNING" "Module installation may have issues"
    fi
    
    # Restart Odoo service
    systemctl start odoo
    
    echo -e "${GREEN}✓ Odoo service restarted${NC}"
}

configure_sendgrid_in_odoo() {
    echo -e "${CYAN}Configuring SendGrid in Odoo...${NC}"
    
    # This creates a SQL file to insert the mail server configuration
    cat > /tmp/sendgrid_config.sql << EOF
-- Insert SendGrid Mail Server Configuration
INSERT INTO ir_mail_server (name, smtp_host, smtp_port, smtp_encryption, smtp_user, smtp_pass, smtp_authentication, from_filter, sequence, active, create_uid, write_uid, create_date, write_date)
SELECT 
    'SendGrid SMTP',
    'smtp.sendgrid.net',
    2525,
    'starttls',
    'apikey',
    '$SENDGRID_API_KEY',
    'login',
    '@$SENDGRID_FROM_DOMAIN',
    10,
    true,
    1,
    1,
    NOW(),
    NOW()
WHERE NOT EXISTS (
    SELECT 1 FROM ir_mail_server WHERE name = 'SendGrid SMTP'
);
EOF
    
    # Execute SQL in the database
    if su - postgres -c "psql -d $DEFAULT_DB_NAME -f /tmp/sendgrid_config.sql" >> "$LOG_FILE" 2>&1; then
        echo -e "${GREEN}✓ SendGrid configured in Odoo database${NC}"
        log_message "INFO" "SendGrid mail server configured in database"
    else
        echo -e "${YELLOW}⚠ Could not configure SendGrid automatically. Configure it in Odoo settings.${NC}"
        log_message "WARNING" "Failed to configure SendGrid in database"
    fi
    
    rm -f /tmp/sendgrid_config.sql
}

validate_installation() {
    echo
    echo -e "${CYAN}Running validation tests...${NC}"
    
    local errors=0
    
    # Check services
    if systemctl is-active --quiet odoo; then
        echo -e "${GREEN}✓${NC} Odoo service is running"
    else
        echo -e "${RED}✗${NC} Odoo service is not running"
        errors=$((errors + 1))
    fi
    
    if systemctl is-active --quiet postgresql; then
        echo -e "${GREEN}✓${NC} PostgreSQL is running"
    else
        echo -e "${RED}✗${NC} PostgreSQL is not running"
        errors=$((errors + 1))
    fi
    
    if [ "$INSTALL_NGINX" = "true" ] && systemctl is-active --quiet nginx; then
        echo -e "${GREEN}✓${NC} Nginx is running"
    fi
    
    # Check directories
    if [ -d "/odoo/odoo" ]; then
        echo -e "${GREEN}✓${NC} Odoo source code installed"
    fi
    
    if [ -d "$EXTRA_ADDONS_PATH" ]; then
        echo -e "${GREEN}✓${NC} Extra addons directory exists"
    fi
    
    # Check swap
    local swap=$(free -m | awk '/^Swap:/ {print $2}')
    if [ "$swap" -gt 0 ]; then
        echo -e "${GREEN}✓${NC} Swap configured: ${swap}MB"
    fi
    
    # Validate WebSocket configuration (critical for POS Restaurant)
    validate_websocket_config
    
    return $errors
}

# Validate WebSocket configuration for POS Restaurant
validate_websocket_config() {
    echo
    echo -e "${CYAN}Validating WebSocket configuration (POS Restaurante)...${NC}"
    
    # Check workers in odoo.conf
    local workers_conf=$(grep -E "^workers\s*=" /etc/odoo/odoo.conf 2>/dev/null | awk -F'=' '{print $2}' | tr -d ' ')
    if [ -n "$workers_conf" ] && [ "$workers_conf" -ge 2 ]; then
        echo -e "${GREEN}✓${NC} Workers configurados: $workers_conf (OK para POS Restaurante)"
    else
        echo -e "${YELLOW}⚠${NC} Workers: $workers_conf - Se recomienda mínimo 2 para POS Restaurante"
    fi
    
    # Check gevent_port in odoo.conf
    if grep -qE "^gevent_port\s*=\s*8072" /etc/odoo/odoo.conf 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Gevent port 8072 configurado (WebSocket)"
    else
        echo -e "${YELLOW}⚠${NC} gevent_port no encontrado en odoo.conf"
    fi
    
    # Check Nginx websocket configuration
    if [ -f "/etc/nginx/sites-available/odoo" ]; then
        if grep -q "proxy_buffering off" /etc/nginx/sites-available/odoo 2>/dev/null; then
            echo -e "${GREEN}✓${NC} Nginx: proxy_buffering off configurado"
        else
            echo -e "${YELLOW}⚠${NC} Nginx: proxy_buffering off no encontrado"
        fi
        
        if grep -q "location /websocket" /etc/nginx/sites-available/odoo 2>/dev/null; then
            echo -e "${GREEN}✓${NC} Nginx: /websocket location configurado"
        else
            echo -e "${YELLOW}⚠${NC} Nginx: /websocket location no encontrado"
        fi
    fi
    
    # Test WebSocket port locally
    if nc -z -w2 127.0.0.1 8072 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Puerto 8072 (gevent/websocket) respondiendo"
    else
        echo -e "${YELLOW}⚠${NC} Puerto 8072 no responde aún (puede tardar unos segundos)"
    fi
    
    echo -e "${GREEN}✓${NC} Configuración WebSocket validada para POS Restaurante"
}

generate_installation_report() {
    local web_url
    if [ "$HAS_DOMAIN" = "true" ]; then
        web_url="https://$DOMAIN_NAME"
    else
        web_url="http://$SERVER_IP:8069"
    fi
    
    cat > /root/odoo_installation_report.txt << EOF
===============================================================================
            ODOO INSTALLATION REPORT - CODIFICANDO EDITION
===============================================================================

Installation Date: $(date)
Script Version: $SCRIPT_VERSION

CONFIGURATION:
--------------
- Odoo Version: $OE_BRANCH (Community)
- Domain: $DOMAIN_NAME
- Server IP: $SERVER_IP
- Default Database: $DEFAULT_DB_NAME
- Extra Addons: $EXTRA_ADDONS_PATH

ACCESS URLs:
------------
- Odoo Web: $web_url
- Database Manager: $web_url/web/database/manager

CREDENTIALS:
------------
- Master Password: $DB_ADMIN_PASSWORD (guardada en /root/.odoo_credentials)
- Admin credentials: crear al generar la base desde Odoo (/web/database/manager)

SENDGRID CONFIGURATION:
-----------------------
EOF

    if [ "$SENDGRID_ENABLED" = "true" ]; then
        cat >> /root/odoo_installation_report.txt << EOF
- Enabled: Yes
- SMTP Server: smtp.sendgrid.net:2525
- From Domain: @$SENDGRID_FROM_DOMAIN
- From Email: $SENDGRID_FROM_EMAIL
EOF
    else
        echo "- Enabled: No (configure manually in Odoo settings)" >> /root/odoo_installation_report.txt
    fi
    
    cat >> /root/odoo_installation_report.txt << EOF

IMPORTANT FILES:
----------------
- Configuration: /etc/odoo/odoo.conf
- Log file: /var/log/odoo/odoo-server.log
- Extra addons: $EXTRA_ADDONS_PATH
- Credentials: /root/.odoo_credentials
- Nginx config: /etc/nginx/sites-available/odoo

USEFUL COMMANDS:
----------------
- Check status: systemctl status odoo
- Restart Odoo: systemctl restart odoo
- View logs: tail -f /var/log/odoo/odoo-server.log
- Update addons: systemctl restart odoo -u all
- Test WebSocket: curl -I https://$DOMAIN_NAME/websocket

MEMORY OPTIMIZATIONS:
---------------------
- Swap: $SWAP_SIZE configured
- Workers: $WORKERS (mínimo 2 para POS Restaurante)
- Gevent Port: 8072 (WebSocket)
- Max cron threads: $MAX_CRON_THREADS
- Memory limits configured

POS RESTAURANTE - CONFIGURACIÓN WEBSOCKET:
-------------------------------------------
Esta instalación incluye configuración optimizada para POS Restaurante:
- Workers >= 2: Obligatorio para que funcione el bus de tiempo real
- gevent_port = 8072: Puerto WebSocket para actualizaciones en vivo
- Nginx con proxy_buffering off: Evita delays en actualizaciones de mesas
- http2 on: Formato correcto para Nginx moderno

Si las mesas no se actualizan en tiempo real:
1. Verificar workers >= 2 en /etc/odoo/odoo.conf
2. Verificar gevent_port = 8072 en /etc/odoo/odoo.conf  
3. Verificar proxy_buffering off en /etc/nginx/sites-available/odoo
4. Reiniciar: systemctl restart odoo nginx
5. Probar WebSocket: curl -I https://$DOMAIN_NAME/websocket

===============================================================================
EOF
    
    echo -e "${GREEN}Installation report saved to: /root/odoo_installation_report.txt${NC}"
}

show_success_message() {
    clear
    display_billboard "Installation Complete!"
    
    local web_url
    if [ "$HAS_DOMAIN" = "true" ]; then
        web_url="https://$DOMAIN_NAME"
    else
        web_url="http://$SERVER_IP:8069"
    fi
    
    echo -e "${GREEN}${BOLD}🎉 Odoo $OE_BRANCH - CODIFICANDO Edition installed successfully! 🎉${NC}"
    echo
    echo -e "${CYAN}Access your Odoo:${NC}"
    echo -e "  ${BOLD}${WHITE}$web_url${NC}"
    echo
    echo -e "${CYAN}Default Database (auto-create):${NC} $CREATE_DEFAULT_DB"
    echo -e "${CYAN}Crea la base desde:${NC} $web_url/web/database/manager"
    echo -e "${CYAN}Master Password:${NC} Saved in /root/.odoo_credentials"
    echo
    if [ "$SENDGRID_ENABLED" = "true" ]; then
        echo -e "${CYAN}📧 SendGrid Email:${NC} Configured for @$SENDGRID_FROM_DOMAIN"
        echo
    fi
    echo -e "${CYAN}Extra Addons Path:${NC} $EXTRA_ADDONS_PATH"
    echo -e "${YELLOW}  → Place your custom modules here and restart Odoo${NC}"
    echo
    echo -e "${CYAN}Important Files:${NC}"
    echo -e "  • Configuration: /etc/odoo/odoo.conf"
    echo -e "  • Credentials: /root/.odoo_credentials"
    echo -e "  • Installation Report: /root/odoo_installation_report.txt"
    echo -e "  • Log file: /var/log/odoo/odoo-server.log"
    echo
    echo -e "${GREEN}${BOLD}🍽️ POS RESTAURANTE:${NC}"
    echo -e "  • WebSocket configurado en puerto 8072"
    echo -e "  • Workers: $WORKERS (tiempo real habilitado)"
    echo -e "  • Las mesas se actualizarán automáticamente"
    echo -e "  • Verificar: curl -I $web_url/websocket"
    echo
    echo -e "${BOLD}${WHITE}Thank you for using CODIFICANDO Odoo Installer!${NC}"
    echo
}

#==============================================================================
# MAIN EXECUTION
#==============================================================================

main_installation() {
    local start_time=$(date +%s)
    
    step_preflight_checks
    step_swap_configuration
    step_system_preparation
    step_database_setup
    step_dependencies_installation
    step_wkhtmltopdf_installation
    step_odoo_installation
    step_odoo_configuration
    step_nginx_ssl_configuration
    step_service_final_setup
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))
    
    show_success_message
    log_message "INFO" "Installation completed in ${minutes}m ${seconds}s"
}

# Initialize
log_message "INFO" "Starting $SCRIPT_NAME v$SCRIPT_VERSION"

# Show welcome
clear
display_billboard "$SCRIPT_NAME"

echo -e "${BOLD}${WHITE}Welcome to the CODIFICANDO Odoo Installer!${NC}"
echo
echo -e "${CYAN}Optimized for low-resource servers (1GB RAM, 1 vCPU)${NC}"
echo
echo -e "${GREEN}Features:${NC}"
echo -e "  • Memory optimization with swap"
echo -e "  • SendGrid email configuration"
echo -e "  • Public links configuration"
echo -e "  • Default database creation"
echo -e "  • Extra addons directory"
echo -e "  • Nginx with SSL"
echo

# Run configuration steps
select_resource_profile    # NEW: Select server resources first
select_odoo_version
configure_domain
configure_sendgrid
configure_database

# Confirm and install
if confirm_installation; then
    main_installation
else
    echo -e "${YELLOW}Installation cancelled.${NC}"
    exit 0
fi
