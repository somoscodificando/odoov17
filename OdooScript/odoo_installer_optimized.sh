#!/bin/bash

# ===============================================================================
# Enhanced Odoo Installation Script for Ubuntu 22.04 - OPTIMIZED for Low Resources
# ===============================================================================
# Version: 3.0-OPTIMIZED
# Author: Mahmoud Abel Latif, https://mah007.net
# Modified: CODIFICANDO - Optimized for DigitalOcean Droplets
# Description: Odoo installation optimized for 1GB RAM servers with SendGrid,
#              public links configuration, and automatic database creation
#
# MINIMUM REQUIREMENTS:
#   - 1 GB Memory
#   - 1 Intel vCPU  
#   - 35 GB Disk
#   - Ubuntu 22.04 (LTS) x64
#
# FEATURES:
#   - Memory optimization with swap configuration
#   - SendGrid SMTP auto-configuration
#   - Public links configuration (proxy_mode, web.base.url)
#   - Default database "CODIFICANDO" creation
#   - Extra addons directory at /opt/extra-addons
# ===============================================================================

# Script configuration
SCRIPT_VERSION="3.0-OPTIMIZED"
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

# SendGrid Configuration
SENDGRID_ENABLED="false"
SENDGRID_API_KEY=""
SENDGRID_FROM_DOMAIN=""
SENDGRID_FROM_EMAIL=""

# Database Configuration
CREATE_DEFAULT_DB="true"
DEFAULT_DB_NAME="CODIFICANDO"
DB_ADMIN_PASSWORD=""

# Extra Addons
EXTRA_ADDONS_PATH="/opt/extra-addons"

# Low Resource Optimizations
SWAP_SIZE="2G"  # 2GB swap for 1GB RAM servers
WORKERS=0       # 0 = automatic (recommended for low RAM)
MAX_CRON_THREADS=1
LIMIT_MEMORY_HARD=2684354560  # ~2.5GB
LIMIT_MEMORY_SOFT=2147483648  # 2GB
LIMIT_TIME_CPU=600
LIMIT_TIME_REAL=1200

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
    
    # Check available disk space (minimum 10GB)
    local available_space=$(df / | awk 'NR==2 {print $4}')
    local required_space=10485760  # 10GB in KB
    
    if [ "$available_space" -lt "$required_space" ]; then
        log_message "ERROR" "Insufficient disk space. Required: 10GB, Available: $((available_space/1024/1024))GB"
        errors=$((errors + 1))
    fi
    
    # Check memory - WARNING for low memory but continue (we'll add swap)
    local total_memory=$(free -m | awk 'NR==2{print $2}')
    if [ "$total_memory" -lt 1024 ]; then
        log_message "WARNING" "Very low memory: ${total_memory}MB. Will configure swap and optimize settings."
    elif [ "$total_memory" -lt 2048 ]; then
        log_message "INFO" "Low memory detected: ${total_memory}MB. Will optimize for low resource usage."
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
    display_billboard "Domain Configuration"
    
    echo -e "${BOLD}${WHITE}Domain Setup for Odoo Installation${NC}"
    echo
    
    get_server_ip
    echo -e "${YELLOW}Your server IP address: ${BOLD}$SERVER_IP${NC}"
    echo
    
    while true; do
        echo -e -n "${BOLD}${WHITE}Do you have a domain name pointing to this server? [y/N]: ${NC}"
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
                echo -e "${RED}Please answer yes (y) or no (n).${NC}"
                ;;
        esac
    done
    
    if [ "$HAS_DOMAIN" = "true" ]; then
        while true; do
            echo -e -n "${BOLD}${WHITE}Enter your domain name (e.g., odoo.sistemascodificando.com): ${NC}"
            read -r domain_input
            
            if [ -n "$domain_input" ]; then
                if [[ "$domain_input" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
                    DOMAIN_NAME="$domain_input"
                    echo -e "${GREEN}Domain set to: $DOMAIN_NAME${NC}"
                    break
                else
                    echo -e "${RED}Invalid domain format. Please enter a valid domain name.${NC}"
                fi
            else
                echo -e "${RED}Domain name cannot be empty.${NC}"
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
    display_billboard "SendGrid Email Configuration"
    
    echo -e "${BOLD}${WHITE}📧 SendGrid SMTP Configuration${NC}"
    echo
    echo -e "${CYAN}Configure automatic email sending using SendGrid.${NC}"
    echo -e "${CYAN}This is recommended for DigitalOcean since ports 25, 465, 587 are blocked.${NC}"
    echo -e "${CYAN}SendGrid uses port 2525 which works with DigitalOcean.${NC}"
    echo
    
    while true; do
        echo -e -n "${BOLD}${WHITE}Do you want to configure SendGrid for outgoing emails? [Y/n]: ${NC}"
        read -r sendgrid_input
        case "$sendgrid_input" in
            [Yy]|[Yy][Ee][Ss]|"")
                SENDGRID_ENABLED="true"
                break
                ;;
            [Nn]|[Nn][Oo])
                SENDGRID_ENABLED="false"
                echo -e "${YELLOW}SendGrid configuration skipped. You can configure it later in Odoo.${NC}"
                return 0
                ;;
            *)
                echo -e "${RED}Please answer yes (y) or no (n).${NC}"
                ;;
        esac
    done
    
    # Get SendGrid API Key
    echo
    echo -e "${CYAN}Enter your SendGrid API Key:${NC}"
    echo -e "${YELLOW}(Get it from: SendGrid → Settings → API Keys → Create API Key)${NC}"
    while true; do
        echo -e -n "${BOLD}${WHITE}API Key: ${NC}"
        read -r api_key_input
        
        if [ -n "$api_key_input" ]; then
            SENDGRID_API_KEY="$api_key_input"
            echo -e "${GREEN}✓ API Key configured${NC}"
            break
        else
            echo -e "${RED}API Key cannot be empty.${NC}"
        fi
    done
    
    # Get Sending Domain
    echo
    echo -e "${CYAN}Enter your verified SendGrid domain:${NC}"
    echo -e "${YELLOW}(This must match your SendGrid Domain Authentication)${NC}"
    while true; do
        echo -e -n "${BOLD}${WHITE}Domain (e.g., sistemascodificando.com): ${NC}"
        read -r domain_input
        
        if [ -n "$domain_input" ]; then
            SENDGRID_FROM_DOMAIN="$domain_input"
            echo -e "${GREEN}✓ Sending domain: @$SENDGRID_FROM_DOMAIN${NC}"
            break
        else
            echo -e "${RED}Domain cannot be empty.${NC}"
        fi
    done
    
    # Get From Email
    echo
    echo -e "${CYAN}Enter the default sender email address:${NC}"
    while true; do
        echo -e -n "${BOLD}${WHITE}Email (e.g., contacto@$SENDGRID_FROM_DOMAIN): ${NC}"
        read -r email_input
        
        if [ -n "$email_input" ]; then
            SENDGRID_FROM_EMAIL="$email_input"
            echo -e "${GREEN}✓ Sender email: $SENDGRID_FROM_EMAIL${NC}"
            break
        else
            SENDGRID_FROM_EMAIL="contacto@$SENDGRID_FROM_DOMAIN"
            echo -e "${GREEN}✓ Using default: $SENDGRID_FROM_EMAIL${NC}"
            break
        fi
    done
    
    # Test SendGrid connectivity
    echo
    echo -e "${CYAN}Testing SendGrid connectivity (port 2525)...${NC}"
    if nc -z -w5 smtp.sendgrid.net 2525 2>/dev/null; then
        echo -e "${GREEN}✓ SendGrid SMTP is reachable on port 2525${NC}"
        log_message "INFO" "SendGrid connectivity test passed"
    else
        echo -e "${YELLOW}⚠ Could not reach SendGrid. Will configure anyway, but verify connectivity later.${NC}"
        log_message "WARNING" "SendGrid connectivity test failed"
    fi
    
    log_message "INFO" "SendGrid configuration: ENABLED=$SENDGRID_ENABLED, DOMAIN=$SENDGRID_FROM_DOMAIN"
}

configure_database() {
    clear
    display_billboard "Database Configuration"
    
    echo -e "${BOLD}${WHITE}🗄️ Default Database Configuration${NC}"
    echo
    echo -e "${CYAN}Configure the default Odoo database and extra addons directory.${NC}"
    echo
    
    # Database name
    echo -e "${CYAN}Default database name:${NC}"
    echo -e -n "${BOLD}${WHITE}Database name [$DEFAULT_DB_NAME]: ${NC}"
    read -r db_name_input
    
    if [ -n "$db_name_input" ]; then
        DEFAULT_DB_NAME="$db_name_input"
    fi
    echo -e "${GREEN}✓ Database name: $DEFAULT_DB_NAME${NC}"
    
    # Generate admin password
    DB_ADMIN_PASSWORD=$(generate_random_password)
    echo
    echo -e "${GREEN}✓ Master password generated (saved to /root/.odoo_credentials)${NC}"
    
    # Extra addons path
    echo
    echo -e "${CYAN}Extra addons directory:${NC}"
    echo -e -n "${BOLD}${WHITE}Path [$EXTRA_ADDONS_PATH]: ${NC}"
    read -r addons_path_input
    
    if [ -n "$addons_path_input" ]; then
        EXTRA_ADDONS_PATH="$addons_path_input"
    fi
    echo -e "${GREEN}✓ Extra addons path: $EXTRA_ADDONS_PATH${NC}"
    
    log_message "INFO" "Database configuration: DB_NAME=$DEFAULT_DB_NAME, ADDONS_PATH=$EXTRA_ADDONS_PATH"
}

select_odoo_version() {
    while true; do
        clear
        display_billboard "Odoo Version Selection"
        
        echo -e "${BOLD}${WHITE}Please select the Odoo version to install:${NC}"
        echo
        echo -e "  ${YELLOW}1)${NC} Odoo 16.0 ${CYAN}(Stable - Recommended for low resources)${NC}"
        echo -e "  ${YELLOW}2)${NC} Odoo 17.0 ${CYAN}(Latest Stable)${NC} ${GREEN}[Default]${NC}"
        echo -e "  ${YELLOW}3)${NC} Odoo 18.0 ${CYAN}(Latest - May have issues)${NC}"
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

confirm_installation() {
    clear
    display_billboard "Installation Confirmation"
    
    echo -e "${BOLD}${WHITE}Installation Summary:${NC}"
    echo -e "  ${CYAN}Odoo Version:${NC} $OE_BRANCH (Community)"
    echo -e "  ${CYAN}System User:${NC} $OE_USER"
    echo -e "  ${CYAN}Domain:${NC} ${DOMAIN_NAME:-"IP-based access"}"
    echo -e "  ${CYAN}Install Nginx:${NC} $INSTALL_NGINX"
    echo -e "  ${CYAN}SSL Certificate:${NC} $SSL_TYPE"
    echo -e "  ${CYAN}Default Database:${NC} $DEFAULT_DB_NAME"
    echo -e "  ${CYAN}Extra Addons Path:${NC} $EXTRA_ADDONS_PATH"
    echo -e "  ${CYAN}SendGrid Email:${NC} $SENDGRID_ENABLED"
    if [ "$SENDGRID_ENABLED" = "true" ]; then
        echo -e "  ${CYAN}Email Domain:${NC} @$SENDGRID_FROM_DOMAIN"
    fi
    echo -e "  ${CYAN}Swap Size:${NC} $SWAP_SIZE (for low RAM optimization)"
    echo
    echo -e "${YELLOW}${BOLD}OPTIMIZATIONS FOR LOW RESOURCES:${NC}"
    echo -e "  • Swap memory: $SWAP_SIZE"
    echo -e "  • Workers: $WORKERS (auto-adjusted)"
    echo -e "  • Max cron threads: $MAX_CRON_THREADS"
    echo -e "  • Memory limits configured for 1GB RAM"
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
    
    log_message "INFO" "System preparation completed"
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
    echo -e "${CYAN}Optimizing PostgreSQL for low memory...${NC}"
    
    local pg_conf=$(find /etc/postgresql -name "postgresql.conf" 2>/dev/null | head -1)
    
    if [ -n "$pg_conf" ]; then
        # Backup original
        cp "$pg_conf" "${pg_conf}.backup"
        
        # Apply low-memory optimizations
        cat >> "$pg_conf" << EOF

# Optimizations for low memory (1GB RAM)
shared_buffers = 128MB
effective_cache_size = 256MB
maintenance_work_mem = 32MB
work_mem = 4MB
max_connections = 50
checkpoint_completion_target = 0.9
wal_buffers = 4MB
random_page_cost = 1.1
EOF
        
        execute_simple "systemctl restart postgresql" "Restarting PostgreSQL with optimizations"
        log_message "INFO" "PostgreSQL optimized for low memory"
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
        "build-essential" "node-less" "npm"
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
    
    # Install Python requirements
    execute_simple "pip3 install --upgrade pip" "Upgrading pip"
    execute_simple "pip3 install -r /odoo/odoo/requirements.txt" "Installing Odoo requirements"
    execute_simple "pip3 install phonenumbers" "Installing phonenumbers"
    
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
; Odoo Configuration - Optimized for Low Resources (1GB RAM)
; Generated by CODIFICANDO Installer v$SCRIPT_VERSION
; ============================================================================

; Database Configuration
db_host = False
db_port = False
db_user = $OE_USER
db_password = False
db_name = False
dbfilter = .*
list_db = True

; Paths
addons_path = /odoo/odoo/addons,$EXTRA_ADDONS_PATH
data_dir = /var/lib/odoo

; Logging
logfile = /var/log/odoo/odoo-server.log
log_level = warn
log_handler = :WARNING

; Security
admin_passwd = $DB_ADMIN_PASSWORD

; Performance - Optimized for 1GB RAM
workers = $WORKERS
max_cron_threads = $MAX_CRON_THREADS
limit_memory_hard = $LIMIT_MEMORY_HARD
limit_memory_soft = $LIMIT_MEMORY_SOFT
limit_time_cpu = $LIMIT_TIME_CPU
limit_time_real = $LIMIT_TIME_REAL
limit_request = 8192

; Proxy Mode (for Nginx)
proxy_mode = True

; Public Links Configuration
web.base.url = $web_base_url
web.base.url.freeze = True

; Long Polling (for live chat, notifications)
longpolling_port = 8072
gevent_port = 8072

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
    
    # Configure SSL
    if [ "$SSL_TYPE" = "letsencrypt" ] && [ "$HAS_DOMAIN" = "true" ]; then
        install_letsencrypt_ssl
    else
        generate_self_signed_ssl
    fi
    
    # Create Nginx configuration
    create_nginx_config
    
    # Enable and start Nginx
    execute_simple "systemctl enable nginx" "Enabling Nginx"
    execute_simple "nginx -t" "Testing Nginx configuration"
    execute_simple "systemctl restart nginx" "Starting Nginx"
    
    log_message "INFO" "Nginx configuration completed"
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
    
    # Create temporary nginx config for verification
    cat > /etc/nginx/sites-available/odoo-temp << EOF
server {
    listen 80;
    server_name $DOMAIN_NAME;
    location / {
        return 200 'Temporary configuration for SSL setup';
    }
}
EOF
    
    ln -sf /etc/nginx/sites-available/odoo-temp /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    systemctl restart nginx
    
    # Get certificate
    if certbot --nginx -d "$DOMAIN_NAME" --non-interactive --agree-tos --email "admin@$DOMAIN_NAME" --redirect >> "$LOG_FILE" 2>&1; then
        log_message "INFO" "Let's Encrypt certificate obtained"
    else
        log_message "WARNING" "Let's Encrypt failed, using self-signed"
        SSL_TYPE="self-signed"
        generate_self_signed_ssl
    fi
    
    # Remove temporary config
    rm -f /etc/nginx/sites-available/odoo-temp /etc/nginx/sites-enabled/odoo-temp
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
# Odoo Nginx Configuration - CODIFICANDO Edition
# Optimized for low resources

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
    listen 443 ssl http2;
    server_name $DOMAIN_NAME;
    
    # SSL Configuration
    ssl_certificate $ssl_cert_path;
    ssl_certificate_key $ssl_key_path;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    # Logging
    access_log /var/log/nginx/odoo.access.log;
    error_log /var/log/nginx/odoo.error.log;

    # Proxy headers
    proxy_read_timeout 720s;
    proxy_connect_timeout 720s;
    proxy_send_timeout 720s;

    # File upload size
    client_max_body_size 100M;

    # Gzip compression
    gzip on;
    gzip_types text/css text/less text/plain text/xml application/xml application/json application/javascript;
    gzip_min_length 256;

    # WebSocket for longpolling
    location /websocket {
        proxy_pass http://odoochat;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header X-Forwarded-Host \$http_host;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    # Longpolling (compatibility)
    location /longpolling {
        proxy_pass http://odoochat;
        proxy_set_header X-Forwarded-Host \$http_host;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    # Main Odoo
    location / {
        proxy_pass http://odoo;
        proxy_set_header X-Forwarded-Host \$http_host;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_redirect off;

        # Security headers
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
        add_header X-Content-Type-Options nosniff always;
        add_header X-Frame-Options SAMEORIGIN always;
    }

    # Static files caching
    location ~* /web/static/ {
        proxy_pass http://odoo;
        proxy_cache_valid 200 90d;
        expires 90d;
        add_header Cache-Control "public, no-transform";
    }
}
EOF
    
    # Enable site
    ln -sf /etc/nginx/sites-available/odoo /etc/nginx/sites-enabled/
    
    log_message "INFO" "Nginx configuration created"
}

step_service_final_setup() {
    show_step_header 10 "Final Setup" "Starting services and creating database"
    
    # Create Odoo service file
    cat > /etc/systemd/system/odoo.service << EOF
[Unit]
Description=Odoo - CODIFICANDO Edition
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

# Memory limits for low resource servers
MemoryMax=1G
MemoryHigh=768M

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
        -F "login=admin" \
        -F "password=admin" \
        -F "lang=es_ES" \
        -F "country_code=CO" \
        >> "$LOG_FILE" 2>&1
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Database '$DEFAULT_DB_NAME' created${NC}"
        echo -e "${YELLOW}  Default credentials: admin / admin${NC}"
        log_message "INFO" "Default database created: $DEFAULT_DB_NAME"
    else
        echo -e "${YELLOW}⚠ Could not create database automatically. Create it manually at /web/database/manager${NC}"
        log_message "WARNING" "Failed to create default database"
    fi
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
    
    return $errors
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
- Master Password: $DB_ADMIN_PASSWORD
- Admin User: admin
- Admin Password: admin (CHANGE THIS!)

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

USEFUL COMMANDS:
----------------
- Check status: systemctl status odoo
- Restart Odoo: systemctl restart odoo
- View logs: tail -f /var/log/odoo/odoo-server.log
- Update addons: systemctl restart odoo -u all

MEMORY OPTIMIZATIONS:
---------------------
- Swap: $SWAP_SIZE configured
- Workers: $WORKERS (auto)
- Max cron threads: $MAX_CRON_THREADS
- Memory limits configured

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
    echo -e "${CYAN}Default Database:${NC} $DEFAULT_DB_NAME"
    echo -e "${CYAN}Admin Login:${NC} admin / admin ${YELLOW}(change this!)${NC}"
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
