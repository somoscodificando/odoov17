# Enhanced Odoo Installer

[![Version](https://img.shields.io/badge/Version-3.2.1--20260122-blue.svg)](https://github.com/somoscodificando/odoov17)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04%20LTS-orange.svg)](https://ubuntu.com/)
[![Odoo](https://img.shields.io/badge/Odoo-14.0%20to%2018.0-purple.svg)](https://www.odoo.com/)
[![Nginx](https://img.shields.io/badge/Nginx-Latest-green.svg)](https://nginx.org/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-blue.svg)](https://www.postgresql.org/)

> **Professional Odoo installation script with domain configuration, official Nginx, SSL certificates, and dynamic configuration generation for Ubuntu 22.04**

## 📦 Versión Actual: `3.2.1-20260122`

**Cambios en esta versión:**
- ✅ Credenciales personalizadas: contacto@sistemascodificando.com / @Multiboot97
- ✅ Módulos actualizados: pos, stock, purchase, account, sale
- ✅ Eliminado perfil mínimo (512 MB) - Requiere 900 MB+ ahora
- ✅ Simplificado a 2 perfiles: Básico (900 MB+) y Estándar (2 GB+)
- ✅ SendGrid: Ingreso directo de API Key (sin configuración previa)
- ✅ Interfaz traducida a español para mejor experiencia de usuario

**Verificar versión instalada:**
```bash
head -10 odoo_installer.sh | grep "Version"
# Debe mostrar: Version: 3.2.1-20260122
```

## 🚀 Quick Start

```bash
# Download the installer
wget https://raw.githubusercontent.com/somoscodificando/odoov17/main/OdooScript/odoo_installer.sh
# Make it executable
chmod +x odoo_installer.sh

# Verify version
head -10 odoo_installer.sh | grep "Version"

# Run the installer
sudo ./odoo_installer.sh
```

---

## 📖 Guía de Instalación Paso a Paso

### **Paso 1: Preparar el Servidor**

1. Crear un droplet en DigitalOcean (o servidor Ubuntu 22.04):
   - **Imagen**: Ubuntu 22.04 (LTS) x64
   - **Plan**: Basic - Regular (1 GB / 1 vCPU / 35 GB)
   - **Región**: Selecciona la más cercana

2. Conectar al servidor:
```bash
ssh root@TU_IP_DEL_SERVIDOR
```

### **Paso 2: Descargar el Script**

```bash
# Descargar el instalador
wget https://raw.githubusercontent.com/somoscodificando/odoov17/main/OdooScript/odoo_installer.sh

# Dar permisos de ejecución
chmod +x odoo_installer.sh
```

### **Paso 3: Ejecutar el Instalador**

```bash
sudo ./odoo_installer.sh
```

### **Paso 4: Configuración Interactiva**

El asistente te guiará por las siguientes opciones:

#### 4.1 Selección de Perfil de Recursos ⭐ ACTUALIZADO

El script detecta automáticamente la RAM del servidor y recomienda el perfil óptimo:

```
╔══════════════════════════════════════════════════════════════╗
║  OPCIÓN 1: BÁSICO (900 MB+ RAM) - DigitalOcean $6            ║
║  • 900 MB+ RAM / 1 CPU                                       ║
║  • 8 GB SSD (mínimo requerido)                               ║
║  • Swap: 2GB, Workers: 0, Optimizado para bajos recursos     ║
╠══════════════════════════════════════════════════════════════╣
║  OPCIÓN 2: ESTÁNDAR (2 GB+ RAM) - DigitalOcean $12+          ║
║  • 2 GB+ RAM / 1+ CPU                                        ║
║  • 50 GB+ SSD                                                ║
║  • Swap: 2GB, Workers: 2, Configuración normal               ║
╚══════════════════════════════════════════════════════════════╝

RAM detectada: 1024 MB - Recomendado: Opción 1 (Básico)

Selecciona perfil [1-2] (por defecto: 1): 1
✓ Perfil configurado: basic
```

**Tabla de optimizaciones por perfil:**

| Configuración | Básico (900MB+) | Estándar (2GB+) |
|---------------|-----------------|------------------|
| **Swap** | 2 GB | 2 GB |
| **Workers** | 0 (thread) | 2 |
| **Cron Threads** | 1 | 2 |
| **Memory Hard** | 1 GB | 2.5 GB |
| **Memory Soft** | 768 MB | 2 GB |
| **PG Shared Buffers** | 32 MB | 128 MB |
| **PG Max Connections** | 30 | 50 |
| **Systemd MemoryMax** | 800 MB | 2 GB |

#### 4.2 Selección de Versión de Odoo
```
1) Odoo 16.0 (Estable - Recomendado para pocos recursos)
2) Odoo 17.0 (Última estable) [Por defecto]
3) Odoo 18.0 (Más reciente - Puede tener issues)
```

#### 4.3 Configuración de Dominio
```
¿Tienes un nombre de dominio apuntando a este servidor? [y/N]: y
Ingresa tu nombre de dominio: odoo.tuempresa.com
```
> Si no tienes dominio, presiona `N` y usará la IP del servidor.

#### 4.3 Configuración de SendGrid (Email) ⭐ SIMPLIFICADO

El script solicita directamente tu API Key de SendGrid:

```
╔══════════════════════════════════════════════════════════════╗
║           CONFIGURACIÓN (Sistemas Codificando)               ║
╠══════════════════════════════════════════════════════════════╣
║  Dominio:       sistemascodificando.com                      ║
║  Email:         contacto@sistemascodificando.com             ║
║  Usuario SMTP:  apikey                                       ║
║  Puerto SMTP:   2525                                         ║
╚══════════════════════════════════════════════════════════════╝

Ingresa tu SendGrid API Key:
(Puedes obtenerla en: SendGrid → Settings → API Keys)
(Déjalo vacío para omitir y configurar después en Odoo)

API Key [SG.xxx...]: SG.tu_api_key_aqui
✓ API Key configurada
✓ Key: SG.xxxxxxxxxxxxx...
```

> 💡 **TIP**: Si no tienes una API Key de SendGrid aún, puedes presionar Enter para omitir este paso y configurarlo más tarde desde la interfaz de Odoo.

**Opción A: Variable de entorno (recomendado)**
```bash
export SENDGRID_API_KEY="SG.tu_api_key_aqui"
sudo -E ./odoo_installer.sh
```

**Opción B: Editar el script directamente**
```bash
# Busca esta línea en el script y agrega tu key:
SENDGRID_API_KEY="${SENDGRID_API_KEY:-}" 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 # <-- AGREGAR TU API KEY AQUÍ
```

#### 4.4 Configuración de Base de Datos y Módulos
```
Database name [CODIFICANDO]: CODIFICANDO
Path [/opt/extra-addons]: /opt/extra-addons

╔══════════════════════════════════════════════════════════════╗
║               MÓDULOS POR DEFECTO A INSTALAR                 ║
╠══════════════════════════════════════════════════════════════╣
║  Módulos: pos,stock,purchase,account,sale                ║
╚══════════════════════════════════════════════════════════════╝

¿Instalar módulos por defecto? [Y/n]: Y
✓ Se instalarán: pos,stock,purchase,account,sale
```

**Módulos disponibles por defecto:**
| Módulo | Descripción | Instalado por defecto |
|--------|-------------|-----------------------|
| `pos` | Punto de Venta | ✅ |
| `stock` | Inventario | ✅ |
| `purchase` | Compras | ✅ |
| `account` | Contabilidad | ✅ |
| `sale` | Ventas | ✅ |
| `crm` | CRM (Gestión de clientes) | ❌ |
| `project` | Proyectos | ❌ |
| `hr` | Recursos Humanos | ❌ |
| `website` | Sitio Web | ❌ |

#### 4.5 Confirmación
```
¿Deseas continuar con la instalación? [y/N]: y
```

### **Paso 5: Esperar la Instalación**

El proceso toma aproximadamente **15-30 minutos** dependiendo del servidor:

```
Step 1/10: Pre-flight Checks
Step 2/10: Swap Configuration
Step 3/10: System Preparation
Step 4/10: Database Setup
Step 5/10: Dependencies Installation
Step 6/10: Wkhtmltopdf Installation
Step 7/10: Odoo Installation
Step 8/10: Odoo Configuration
Step 9/10: Nginx & SSL Configuration
Step 10/10: Final Setup
```

### **Paso 6: Acceder a Odoo**

Una vez completado:

- **Con dominio**: `https://odoo.tuempresa.com`
- **Sin dominio**: `http://TU_IP:8069`

**Credenciales iniciales de Odoo**:
| Campo | Valor |
|-------|-------|
| Usuario | `contacto@sistemascodificando.com` |
| Contraseña | `@Multiboot97` ⚠️ **¡Cambiar inmediatamente!** |

**Credenciales SendGrid (pre-configuradas)**:
| Campo | Valor |
|-------|-------|
| SMTP Server | `smtp.sendgrid.net` |
| Puerto | `2525` |
| Usuario SMTP | `apikey` |
| Contraseña SMTP | Tu API Key de SendGrid |
| Email remitente | `contacto@sistemascodificando.com` |

### **Paso 7: Post-Instalación**

1. **Cambiar contraseña de admin** (¡Muy importante!)
2. **Configurar datos de empresa**
3. **Verificar envío de emails** (ya configurado con SendGrid)
4. **Los módulos ya están instalados** (pos, stock, purchase, account, sale)

---

## 📧 Configuración de SendGrid (Detallada)

### Pre-requisitos

1. **Crear cuenta en SendGrid**: https://sendgrid.com

2. **Verificar dominio** (Domain Authentication):
   ```
   SendGrid → Settings → Sender Authentication → Domain Authentication
   ```

3. **Configurar DNS en DigitalOcean**:

   | Tipo | Hostname | Valor |
   |------|----------|-------|
   | CNAME | em6423 | u59079871.wl122.sendgrid.net. |
   | CNAME | s1._domainkey | s1.domainkey.u59079871.wl122.sendgrid.net. |
   | CNAME | s2._domainkey | s2.domainkey.u59079871.wl122.sendgrid.net. |
   | TXT | _dmarc | v=DMARC1; p=none; |

4. **Crear API Key**:
   ```
   SendGrid → Settings → API Keys → Create API Key → Full Access
   ```
   > ⚠️ Guarda la API Key, solo se muestra una vez.

5. **Verificar conectividad** (desde el servidor):
   ```bash
   nc -vz smtp.sendgrid.net 2525
   # Respuesta esperada: succeeded
   ```

---

## 📁 Estructura de Archivos Post-Instalación

```
/odoo/odoo/                  # Código fuente de Odoo
/opt/extra-addons/           # Módulos personalizados
  └── modulos/               # Repo somoscodificando/modulos (clonado automáticamente)
      ├── modulo_ventas/
      ├── modulo_inventario/
      └── ...
/etc/odoo/odoo.conf          # Configuración de Odoo
/var/log/odoo/               # Logs de Odoo
/var/lib/odoo/               # Datos de Odoo
/root/.odoo_credentials      # Credenciales (SEGURO)
/root/odoo_installation_report.txt  # Reporte de instalación
```

---

## 📦 Agregar Módulos Personalizados

### **Opción 1: Durante la Instalación (Recomendado)**

El script te preguntará si deseas agregar repositorios de módulos personalizados:

```
¿Deseas agregar repositorios de módulos personalizados? [y/N]: y

Ingresa las URLs de los repositorios (una por línea).
Formato: URL o URL|rama (ej: https://github.com/user/repo.git|17.0)
Escribe 'done' cuando termines:

Repo URL: https://github.com/somoscodificando/odoo-modulos-custom.git|17.0
✓ Agregado: https://github.com/somoscodificando/odoo-modulos-custom.git|17.0

Repo URL: https://github.com/OCA/web.git|17.0
✓ Agregado: https://github.com/OCA/web.git|17.0

Repo URL: done
✓ 2 repositorio(s) configurado(s)
```

Los repositorios se clonarán automáticamente en `/opt/extra-addons/`.

### **Opción 2: Pre-configurar en el Script (Por defecto)**

El script ya incluye el repositorio de Sistemas Codificando:

```bash
# Custom Module Repositories (línea ~82)
CUSTOM_MODULE_REPOS=(
    # Repositorio principal de Sistemas Codificando (PRIVADO)
    "git@github.com:somoscodificando/modulos.git|17.0"
)
```

### **⚠️ Repositorios Privados - Configurar SSH Key**

Si tu repositorio es **privado**, necesitas configurar una SSH key en el servidor **ANTES** de ejecutar el instalador:

```bash
# 1. Conectar al servidor
ssh root@TU_IP_DEL_SERVIDOR

# 2. Generar SSH key
ssh-keygen -t ed25519 -C "servidor-odoo"
# Presiona Enter en todas las preguntas (sin passphrase)

# 3. Ver la clave pública
cat ~/.ssh/id_ed25519.pub
# Copiar todo el contenido que aparece

# 4. Agregar la clave a GitHub
# Ve a: https://github.com/settings/keys
# Click "New SSH key"
# Título: "Servidor Odoo - TU_DOMINIO"
# Key: Pegar la clave copiada
# Click "Add SSH key"

# 5. Probar conexión
ssh -T git@github.com
# Debe responder: "Hi somoscodificando! You've successfully authenticated..."

# 6. Ahora ejecutar el instalador
wget https://raw.githubusercontent.com/somoscodificando/odoov17/main/OdooScript/odoo_installer.sh
chmod +x odoo_installer.sh
sudo ./odoo_installer.sh
```

> 💡 **Tip**: Para repositorios **públicos**, usa URL HTTPS:
> `"https://github.com/somoscodificando/modulos.git|17.0"`

### **Opción 3: Después de la Instalación**

```bash
# Clonar manualmente (privado con SSH)
cd /opt/extra-addons
git clone -b 17.0 git@github.com:somoscodificando/modulos.git

# O público con HTTPS
git clone -b 17.0 https://github.com/somoscodificando/modulos.git

# Cambiar permisos
chown -R odoo:odoo /opt/extra-addons

# Reiniciar Odoo
systemctl restart odoo

# En Odoo: Apps → Actualizar lista de aplicaciones → Buscar e instalar
```

### **Estructura de un Módulo Personalizado**

```
/opt/extra-addons/
└── mi_modulo/
    ├── __init__.py
    ├── __manifest__.py
    ├── models/
    │   ├── __init__.py
    │   └── mi_modelo.py
    ├── views/
    │   └── mi_vista.xml
    ├── security/
    │   └── ir.model.access.csv
    └── static/
        └── description/
            └── icon.png
```

---

## ⚡ Comandos Útiles

### Gestión del Servicio Odoo
```bash
# Ver estado
systemctl status odoo

# Reiniciar
systemctl restart odoo

# Ver logs en tiempo real
tail -f /var/log/odoo/odoo-server.log
```

### Agregar Módulos Personalizados
```bash
# 1. Subir módulo a /opt/extra-addons
cd /opt/extra-addons
git clone https://github.com/usuario/modulo.git

# 2. Cambiar permisos
chown -R odoo:odoo /opt/extra-addons

# 3. Reiniciar Odoo
systemctl restart odoo

# 4. En Odoo: Apps → Actualizar lista → Buscar e instalar
```

### Ver Credenciales
```bash
cat /root/.odoo_credentials
```

---

## 📋 Table of Contents

- [Features](#-features)
- [System Requirements](#-system-requirements)
- [Installation Process](#-installation-process)
- [Technical Architecture](#-technical-architecture)
- [Configuration Options](#-configuration-options)
- [SSL Certificate Management](#-ssl-certificate-management)
- [Nginx Configuration](#-nginx-configuration)
- [Troubleshooting](#-troubleshooting)
- [Contributing](#-contributing)
- [License](#-license)

## ✨ Features

### 🚀 **CODIFICANDO Edition - Optimizaciones para Bajos Recursos**
- **Swap automático de 2GB** para compensar RAM limitada
- **PostgreSQL optimizado** para bajo consumo de memoria
- **Workers auto-ajustados** según recursos disponibles
- **Límites de memoria** configurados para evitar OOM kills
- **Systemd con MemoryMax** para control de recursos

### 📧 **Configuración Automática de SendGrid (Email)**
- Asistente interactivo para configurar API Key
- SMTP pre-configurado: `smtp.sendgrid.net:2525`
- Compatible con DigitalOcean (puertos 25, 465, 587 bloqueados)
- Filtro de dominio automático
- Inserción automática en base de datos de Odoo

### 🔗 **Links Públicos Configurados**
- `proxy_mode = True` habilitado automáticamente
- `web.base.url` configurado según dominio o IP
- `web.base.url.freeze = True` para URLs consistentes
- Headers de proxy correctos en Nginx

### 🗄️ **Base de Datos y Addons Personalizados**
- Creación automática de base de datos "CODIFICANDO"
- Directorio `/opt/extra-addons` listo para módulos personalizados
- Credenciales guardadas de forma segura en `/root/.odoo_credentials`
- Path de addons configurado automáticamente

### 🌐 **Domain & DNS Management**
- Interactive domain configuration with validation
- Automatic DNS verification and IP detection
- Support for both domain-based and IP-based installations
- Graceful fallback for DNS misconfigurations

### 🔧 **Official Nginx Installation**
- Latest Nginx version from official nginx.org repository (1.20.5+)
- Automatic removal of outdated Ubuntu stock versions
- Proper repository configuration with signing keys
- Modern SSL/TLS configuration with security headers

### 🔒 **SSL Certificate Automation**
- **Let's Encrypt**: Automated certificate generation with Certbot
- **Self-signed**: Fallback certificates for testing environments
- Automatic certificate renewal setup
- Modern TLS 1.2/1.3 configuration

### ⚙️ **Dynamic Configuration**
- Native Odoo configuration generation using `odoo-bin`
- Clean configuration without forced master passwords
- Automatic proxy mode detection for Nginx setups
- Secure file permissions and ownership

### 🛡️ **Enterprise-Grade Security**
- Comprehensive error handling with graceful degradation
- Detailed logging and audit trails
- Secure user and permission management
- Modern cryptographic standards

### 📊 **Advanced Monitoring**
- Real-time progress tracking with visual indicators
- Multi-level logging (DEBUG, INFO, WARNING, ERROR)
- Installation validation and health checks
- Comprehensive installation reports

## 🖥️ System Requirements

### **Operating System**
- Ubuntu 22.04 LTS (Jammy Jellyfish)
- Root or sudo privileges required

### **Perfiles de Hardware Soportados**

| Perfil | RAM | CPU | Disco | Precio DigitalOcean | Uso Recomendado |
|--------|-----|-----|-------|---------------------|-----------------|
| **Básico** ⭐ | 900 MB+ | 1 vCPU | 8 GB | ~$6/mes | Pequeñas empresas, 3-5 usuarios |
| **Estándar** | 2 GB+ | 1+ vCPU | 50 GB+ | ~$12+/mes | Producción, 10+ usuarios |

> 💡 **Recomendado**: El perfil **Básico (900MB+)** ofrece el mejor balance costo/rendimiento para Odoo 17.

### **Optimizaciones Automáticas por Perfil**

```
┌─────────────────────────────────────────────────────────────────────┐
│ PERFIL BÁSICO (900 MB+) - Balance Óptimo ⭐ RECOMENDADO            │
├─────────────────────────────────────────────────────────────────────┤
│ • Swap: 2GB                                                        │
│ • Workers: 0 (modo thread, estable para 900MB+)                    │
│ • PostgreSQL: 32MB shared_buffers, 30 conexiones máx               │
│ • Systemd: MemoryMax=800MB                                         │
│ • Log level: warn                                                  │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│ PERFIL ESTÁNDAR (2 GB+) - Configuración Normal                     │
├─────────────────────────────────────────────────────────────────────┤
│ • Swap: 2GB                                                        │
│ • Workers: 2 (procesos paralelos)                                  │
│ • PostgreSQL: 128MB shared_buffers, 50 conexiones máx              │
│ • Systemd: MemoryMax=2GB                                           │
│ • Log level: info                                                  │
└─────────────────────────────────────────────────────────────────────┘
```

### **Network Requirements**
- Internet connection for package downloads
- Domain name (optional, IP fallback available)
- Open ports: 80 (HTTP), 443 (HTTPS), 8069 (Odoo direct)

## 🔄 Installation Process

The installer follows a **10-step** automated process optimized for low-resource servers:

### **Step 1: Pre-flight Checks**
- System requirements validation
- Ubuntu version verification
- Disk space and memory checks
- Internet connectivity testing

### **Step 2: Swap Configuration** ⭐ NEW
- Creates 2GB swap file for low-RAM servers
- Configures swappiness and cache pressure
- Makes swap permanent in `/etc/fstab`

### **Step 3: System Preparation**
- User and group creation (`odoo` user)
- System package updates (minimal for speed)
- Creates `/opt/extra-addons` directory
- Basic tool installation

### **Step 4: Database Setup**
- PostgreSQL installation from Ubuntu repos (faster)
- Database user configuration
- **PostgreSQL optimized for low memory** ⭐
- Service enablement and startup

### **Step 5: Dependencies Installation**
- Minimal Python packages (--no-install-recommends)
- System development tools
- Node.js and npm packages
- Odoo-specific dependencies

### **Step 6: Wkhtmltopdf Installation**
- PDF generation library installation
- Architecture detection (x64)
- Version verification

### **Step 7: Odoo Installation**
- Shallow clone from official repository (--depth 1)
- Python requirements installation
- Directory structure creation
- Permission configuration

### **Step 8: Odoo Configuration** ⭐ NEW
- Optimized configuration for low resources
- SendGrid SMTP auto-configuration
- Public links (proxy_mode, web.base.url)
- Extra addons path configured
- Credentials saved securely

### **Step 9: Nginx & SSL Configuration**
- Nginx installation
- Let's Encrypt or self-signed SSL
- Reverse proxy configuration
- WebSocket support

### **Step 10: Final Setup**
- Systemd service with memory limits
- Default database creation
- SendGrid configuration in Odoo
- Installation validation
- Report generation

## 🏗️ Technical Architecture

### **Core Components**

```
Enhanced Odoo Installer
├── Configuration Management
│   ├── Domain validation and DNS checking
│   ├── SSL certificate type selection
│   └── Dynamic Odoo configuration generation
├── Package Management
│   ├── Official repository integration
│   ├── Dependency resolution
│   └── Version compatibility checking
├── Service Management
│   ├── Systemd service configuration
│   ├── Process monitoring
│   └── Automatic startup configuration
└── Security Framework
    ├── User privilege management
    ├── File permission enforcement
    └── SSL/TLS implementation
```

### **Script Structure**

```bash
odoo_installer.sh
├── Global Variables & Configuration
├── Utility Functions
│   ├── Logging system
│   ├── Progress tracking
│   ├── Error handling
│   └── User interaction
├── Validation Functions
│   ├── System requirements
│   ├── Network connectivity
│   └── Version compatibility
├── Installation Functions
│   ├── step_preflight_checks()
│   ├── step_system_preparation()
│   ├── step_database_setup()
│   ├── step_dependencies_installation()
│   ├── step_wkhtmltopdf_installation()
│   ├── step_odoo_installation()
│   ├── step_service_configuration()
│   └── step_final_setup()
├── Nginx & SSL Functions
│   ├── install_official_nginx()
│   ├── generate_self_signed_ssl()
│   ├── install_letsencrypt_ssl()
│   └── create_nginx_odoo_config()
└── Main Execution Flow
```

## ⚙️ Configuration Options

### **Odoo Versions Supported**
- Odoo 14.0 (LTS)
- Odoo 15.0
- Odoo 16.0
- Odoo 17.0
- Odoo 18.0 (Latest)

### **Installation Modes**

#### **Domain-based Installation**
```bash
# User provides domain name
Domain: odoo.example.com
SSL: Let's Encrypt (automatic)
Access: https://odoo.example.com
```

#### **IP-based Installation**
```bash
# No domain provided
Domain: Server IP address
SSL: Self-signed certificate
Access: https://[server-ip]
```

### **Generated Configuration Files**

#### **Odoo Configuration (`/etc/odoo/odoo.conf`)**
```ini
[options]
; Basic Odoo configuration
db_host = localhost
db_port = 5432
db_user = odoo
db_password = False
addons_path = /odoo/odoo/addons
logfile = /var/log/odoo/odoo-server.log
log_level = info
; Proxy mode configuration (when Nginx is installed)
proxy_mode = True
```

#### **Systemd Service (`/etc/systemd/system/odoo.service`)**
```ini
[Unit]
Description=Odoo
Documentation=http://www.odoo.com
Requires=postgresql.service
After=postgresql.service

[Service]
Type=simple
SyslogIdentifier=odoo
PermissionsStartOnly=true
User=odoo
Group=odoo
ExecStart=/odoo/odoo/odoo-bin -c /etc/odoo/odoo.conf
StandardOutput=journal+console

[Install]
WantedBy=multi-user.target
```

## 🔒 SSL Certificate Management

### **Let's Encrypt Integration**

The installer uses Certbot via snapd for Let's Encrypt certificates:

```bash
# Automatic installation process
1. Install snapd (if not present)
2. Install certbot via snap
3. Create temporary Nginx configuration
4. Obtain SSL certificate
5. Configure automatic renewal
6. Update Nginx configuration
```

#### **Certificate Renewal**
```bash
# Test renewal (dry run)
certbot renew --dry-run

# Manual renewal
certbot renew

# Automatic renewal (configured by installer)
systemctl status snap.certbot.renew.timer
```

### **Self-signed Certificates**

For testing or internal use:

```bash
# Certificate generation
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/nginx/server.key \
    -out /etc/ssl/nginx/server.crt \
    -subj "/C=US/ST=State/L=City/O=Organization/OU=OrgUnit/CN=$DOMAIN_NAME"
```

## 🌐 Nginx Configuration

### **Reverse Proxy Setup**

The installer creates a production-ready Nginx configuration:

```nginx
# Upstream configuration
upstream odoo {
  server 127.0.0.1:8069;
}
upstream odoochat {
  server 127.0.0.1:8072;
}

# HTTP to HTTPS redirect
server {
  listen 80;
  server_name example.com;
  rewrite ^(.*) https://$host$1 permanent;
}

# HTTPS server block
server {
  listen 443 ssl;
  server_name example.com;
  
  # SSL configuration
  ssl_certificate /path/to/certificate;
  ssl_certificate_key /path/to/private/key;
  ssl_protocols TLSv1.2 TLSv1.3;
  
  # Proxy configuration
  location / {
    proxy_pass http://odoo;
    proxy_set_header X-Forwarded-Host $http_host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Real-IP $remote_addr;
  }
  
  # WebSocket support
  location /websocket {
    proxy_pass http://odoochat;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection $connection_upgrade;
  }
}
```

### **Security Headers**

```nginx
# Security enhancements
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains";
proxy_cookie_flags session_id samesite=lax secure;
```

## 🔧 Troubleshooting

### **Common Issues**

#### **DNS Resolution Problems**
```bash
# Check DNS configuration
dig +short your-domain.com

# Verify server IP
curl -s ifconfig.me

# Test domain resolution
nslookup your-domain.com
```

#### **Service Status Checks**
```bash
# Check Odoo service
systemctl status odoo
journalctl -u odoo -f

# Check PostgreSQL
systemctl status postgresql
sudo -u postgres psql -l

# Check Nginx (if installed)
systemctl status nginx
nginx -t
```

#### **Log File Locations**
```bash
# Installation logs
/tmp/odoo_install_YYYYMMDD_HHMMSS.log

# Odoo application logs
/var/log/odoo/odoo-server.log

# Nginx logs (if installed)
/var/log/nginx/odoo.access.log
/var/log/nginx/odoo.error.log

# System logs
journalctl -u odoo
journalctl -u nginx
```

### **Port Configuration**

| Service | Port | Protocol | Purpose |
|---------|------|----------|---------|
| Odoo | 8069 | HTTP | Web interface |
| Odoo | 8072 | HTTP | WebSocket/Chat |
| Nginx | 80 | HTTP | HTTP redirect |
| Nginx | 443 | HTTPS | Secure web access |
| PostgreSQL | 5432 | TCP | Database |

### **File Permissions**

```bash
# Odoo directories
/odoo/odoo/          - odoo:odoo (755)
/etc/odoo/           - odoo:odoo (755)
/var/log/odoo/       - odoo:odoo (755)

# Configuration files
/etc/odoo/odoo.conf  - odoo:odoo (640)

# SSL certificates
/etc/ssl/nginx/      - root:root (644/600)
```

## 🧪 Testing the Installation

### **Basic Functionality Test**
```bash
# Test Odoo web interface
curl -I http://localhost:8069

# Test with Nginx (if installed)
curl -I https://your-domain.com

# Check database connectivity
sudo -u odoo psql -h localhost -p 5432 -U odoo -l
```

### **SSL Certificate Validation**
```bash
# Check certificate details
openssl x509 -in /path/to/certificate -text -noout

# Test SSL connection
openssl s_client -connect your-domain.com:443 -servername your-domain.com
```

## 📊 Performance Optimization

### **Recommended System Tuning**

#### **PostgreSQL Configuration**
```sql
-- /etc/postgresql/16/main/postgresql.conf
shared_buffers = 256MB
effective_cache_size = 1GB
maintenance_work_mem = 64MB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
```

#### **Nginx Optimization**
```nginx
# /etc/nginx/nginx.conf
worker_processes auto;
worker_connections 1024;
keepalive_timeout 65;
client_max_body_size 100M;
```

#### **Odoo Configuration Tuning**
```ini
# /etc/odoo/odoo.conf
workers = 4
max_cron_threads = 2
limit_memory_hard = 2684354560
limit_memory_soft = 2147483648
limit_request = 8192
limit_time_cpu = 600
limit_time_real = 1200
```

## 🔄 Backup and Maintenance

### **Database Backup**
```bash
# Create database backup
sudo -u odoo pg_dump -h localhost -p 5432 -U odoo database_name > backup.sql

# Restore database
sudo -u odoo psql -h localhost -p 5432 -U odoo -d database_name < backup.sql
```

### **File System Backup**
```bash
# Backup Odoo files
tar -czf odoo_backup.tar.gz /odoo/odoo /etc/odoo /var/log/odoo

# Backup SSL certificates
tar -czf ssl_backup.tar.gz /etc/ssl/nginx /etc/letsencrypt
```

### **Update Procedures**
```bash
# Update Odoo to newer version
cd /odoo/odoo
git fetch origin
git checkout 17.0  # or desired version
sudo systemctl restart odoo

# Update system packages
sudo apt update && sudo apt upgrade

# Update SSL certificates
sudo certbot renew
```

## 🤝 Contributing

We welcome contributions to improve the Enhanced Odoo Installer! Here's how you can help:

### **Development Setup**
```bash
# Clone the repository
git clone https://github.com/somoscodificando/odoov17.git
cd odoov17/OdooScript

# Create a feature branch
git checkout -b feature/your-feature-name

# Make your changes and test
./odoo_installer.sh

# Commit and push
git commit -m "Add your feature description"
git push origin feature/your-feature-name
```

### **Testing Guidelines**
- Test on clean Ubuntu 22.04 installations
- Verify both domain and IP-based installations
- Test SSL certificate generation (both Let's Encrypt and self-signed)
- Validate all Odoo versions (14.0-18.0)
- Check error handling and recovery scenarios

### **Code Style**
- Use consistent bash scripting practices
- Add comments for complex logic
- Follow the existing function naming convention
- Include proper error handling
- Update documentation for new features

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Odoo](https://www.odoo.com/) for the amazing ERP platform
- [Nginx](https://nginx.org/) for the high-performance web server
- [Let's Encrypt](https://letsencrypt.org/) for free SSL certificates
- [PostgreSQL](https://www.postgresql.org/) for the robust database system
- The open-source community for continuous inspiration

## 📞 Support

- **Documentation**: [GitHub Wiki](https://github.com/somoscodificando/odoov17/wiki)
- **Issues**: [GitHub Issues](https://github.com/somoscodificando/odoov17/issues)
- **Discussions**: [GitHub Discussions](https://github.com/somoscodificando/odoov17/discussions)

---

<div align="center">

**Made with ❤️ for the Odoo community By Mahmoud Abdel Latif**


[Documentation](https://github.com/somoscodificando/odoov17/wiki) • [Issues](https://github.com/somoscodificando/odoov17/issues)

</div>



# OdooScript
Odoo dependence installation script for Ubuntu 14.04 , 15.04 ,16.04 ,20.04 , 22.04 ,*24.04(universal)  
make your envirument ready for all kind of odoo with pycharm IDE
after run the script u have to download odoo manully 

ssh-keygen -t ed25519 -C "your_email@example.com"

### Copy this script and run it on your terminal 

./odoo-bin -w a -s -c  ../odoo.conf --stop-after-init

./odoo-bin -w a -s -c  /etc/odoo/odoo.conf --stop-after-init

export LC_ALL="en_US.UTF-8" <br />
export LC_CTYPE="en_US.UTF-8" <br />
sudo dpkg-reconfigure locales <br />

########################################################################<br />
adduser odoo

########################################################################<br />

apt-get update <br />
apt-get install software-properties-common <br />
add-apt-repository ppa:certbot/certbot <br />
apt-get update <br />
apt-get install python-certbot-apache <br />
sudo certbot --apache <br />
#######################################################################<br />

wget https://raw.githubusercontent.com/somoscodificando/odoov17/main/OdooScript/src/nginx.sh <br />
bash nginx.sh <br />

 apt-get update <br />
 apt-get install software-properties-common -y <br />
 add-apt-repository universe <br />
 add-apt-repository ppa:certbot/certbot <br />
 apt-get update <br />
 apt-get install certbot python-certbot-nginx -y<br />
 
 sudo certbot --nginx <br />



#######################################################################<br />

nano  /etc/apt/sources.list.d/pgdg.list <br />
deb deb http://apt.postgresql.org/pub/repos/apt/ bionic-pgdg main <br />
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add - <br />

sudo apt-get update <br />

########################################################################<br />

sudo su - postgres -c "createuser -s odoo" 2> /dev/null || true <br />
wget https://raw.githubusercontent.com/somoscodificando/odoov17/main/OdooScript/odoo_installer.sh <br />
sudo /bin/sh odoo_pro.sh <br />

#

wget http://software.virtualmin.com/gpl/scripts/install.sh <br />
sh /root/install.sh -b LEMP <br />

********************PG UTF*********************<br />

sudo su postgres <br />
psql <br />
update pg_database set datistemplate=false where datname='template1'; <br />
drop database Template1; <br />
create database template1 with owner=postgres encoding='UTF-8' <br />
  lc_collate='en_US.utf8' lc_ctype='en_US.utf8' template template0; <br />
update pg_database set datistemplate=true where datname='template1'; <br />
