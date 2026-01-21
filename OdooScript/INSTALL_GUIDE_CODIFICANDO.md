# 🚀 Guía de Instalación - Odoo CODIFICANDO Edition

## Requisitos del Servidor

Este script está **optimizado** para servidores de bajos recursos:

| Recurso | Mínimo | Recomendado |
|---------|--------|-------------|
| RAM | 1 GB | 2 GB |
| CPU | 1 vCPU | 2 vCPU |
| Disco | 35 GB | 50 GB |
| OS | Ubuntu 22.04 (LTS) x64 | Ubuntu 22.04 (LTS) x64 |

### DigitalOcean Droplet Recomendado
```
1 GB Memory / 1 Intel vCPU / 35 GB Disk / Ubuntu 22.04 (LTS) x64
Costo aproximado: $6/mes
```

---

## 📦 Características del Script

### ✅ Optimizaciones para Bajos Recursos
- **Swap de 2GB** automático para compensar RAM limitada
- **Workers optimizados** (auto-ajuste según recursos)
- **Límites de memoria** configurados para evitar OOM
- **PostgreSQL optimizado** para bajo consumo
- **Nginx con caché** para mejor rendimiento

### ✅ Configuración de SendGrid (Email)
- Configuración automática de SMTP
- Puerto 2525 (compatible con DigitalOcean)
- Filtro de dominio configurado
- Listo para enviar emails desde Odoo

### ✅ Links Públicos
- `proxy_mode = True` habilitado
- `web.base.url` configurado automáticamente
- Compatible con HTTPS/SSL

### ✅ Base de Datos CODIFICANDO
- Base de datos creada automáticamente
- Carpeta `/opt/extra-addons` lista para módulos personalizados
- Credenciales guardadas de forma segura

---

## 🛠️ Instalación

### Paso 1: Conectar al Servidor
```bash
ssh root@TU_IP_DEL_SERVIDOR
```

### Paso 2: Descargar el Script
```bash
wget https://raw.githubusercontent.com/TU_USUARIO/OdooScript/main/odoo_installer.sh
chmod +x odoo_installer.sh
```

### Paso 3: Ejecutar el Instalador
```bash
./odoo_installer.sh
```

### Paso 4: Seguir el Asistente

El script te guiará a través de:

1. **Selección de versión de Odoo** (16.0, 17.0, 18.0)
2. **Configuración de dominio** (opcional)
3. **Configuración de SendGrid** (recomendado)
4. **Configuración de base de datos**
5. **Confirmación e instalación**

---

## 📧 Configuración de SendGrid

### Pre-requisitos en SendGrid

1. **Crear cuenta en SendGrid**: https://sendgrid.com

2. **Verificar dominio**:
   - SendGrid → Settings → Sender Authentication
   - Domain Authentication → Agregar tu dominio

3. **Configurar DNS en DigitalOcean**:

| Tipo | Hostname | Valor |
|------|----------|-------|
| CNAME | em6423 | u59079871.wl122.sendgrid.net. |
| CNAME | s1._domainkey | s1.domainkey.u59079871.wl122.sendgrid.net. |
| CNAME | s2._domainkey | s2.domainkey.u59079871.wl122.sendgrid.net. |
| TXT | _dmarc | v=DMARC1; p=none; |

4. **Crear API Key**:
   - SendGrid → Settings → API Keys
   - Create API Key → Full Access
   - **¡Guardar la clave!** Solo se muestra una vez

### Durante la Instalación

El script te pedirá:
- **API Key**: La clave de SendGrid
- **Dominio de envío**: ejemplo.com
- **Email de remitente**: contacto@ejemplo.com

### Verificar Conectividad
```bash
nc -vz smtp.sendgrid.net 2525
# Debe responder: succeeded
```

---

## 📁 Estructura de Archivos

Después de la instalación:

```
/odoo/odoo/                  # Código fuente de Odoo
/opt/extra-addons/           # Tus módulos personalizados
/etc/odoo/odoo.conf          # Configuración de Odoo
/var/log/odoo/               # Logs de Odoo
/root/.odoo_credentials      # Credenciales (SEGURO)
/root/odoo_installation_report.txt  # Reporte de instalación
```

---

## 🔐 Credenciales

Las credenciales se guardan en `/root/.odoo_credentials`:

```bash
cat /root/.odoo_credentials
```

Contenido:
- Master Password de Odoo
- Nombre de base de datos
- URL de acceso
- Configuración de SendGrid (si aplica)

### Credenciales por Defecto
- **Usuario admin**: admin
- **Contraseña admin**: admin (¡CAMBIAR INMEDIATAMENTE!)

---

## 🌐 Acceso a Odoo

### Con Dominio (HTTPS)
```
https://tu-dominio.com
```

### Sin Dominio (IP)
```
http://TU_IP:8069
```

### Gestor de Bases de Datos
```
https://tu-dominio.com/web/database/manager
```

---

## ⚙️ Comandos Útiles

### Gestión del Servicio
```bash
# Ver estado
systemctl status odoo

# Reiniciar
systemctl restart odoo

# Parar
systemctl stop odoo

# Iniciar
systemctl start odoo

# Ver logs en tiempo real
tail -f /var/log/odoo/odoo-server.log
```

### Gestión de Nginx
```bash
# Ver estado
systemctl status nginx

# Reiniciar
systemctl restart nginx

# Probar configuración
nginx -t
```

### Gestión de PostgreSQL
```bash
# Ver estado
systemctl status postgresql

# Reiniciar
systemctl restart postgresql
```

---

## 📦 Agregar Módulos Personalizados

### Paso 1: Subir Módulos
```bash
cd /opt/extra-addons
# Subir tu módulo aquí (scp, git clone, etc.)
```

### Paso 2: Cambiar Permisos
```bash
chown -R odoo:odoo /opt/extra-addons
```

### Paso 3: Reiniciar Odoo
```bash
systemctl restart odoo
```

### Paso 4: Actualizar Apps en Odoo
1. Ir a Apps
2. Actualizar lista de apps
3. Buscar e instalar tu módulo

---

## 🔧 Solución de Problemas

### Odoo no inicia
```bash
# Ver logs
tail -100 /var/log/odoo/odoo-server.log

# Ver errores de systemd
journalctl -u odoo -n 100
```

### Error de memoria (OOM)
```bash
# Verificar swap
free -h

# Agregar más swap si es necesario
fallocate -l 4G /swapfile2
chmod 600 /swapfile2
mkswap /swapfile2
swapon /swapfile2
```

### Emails no se envían
```bash
# Verificar conectividad
nc -vz smtp.sendgrid.net 2525

# Verificar configuración en Odoo
# Ajustes → Técnico → Servidores de correo saliente
```

### SSL no funciona
```bash
# Renovar certificado Let's Encrypt
certbot renew

# Verificar Nginx
nginx -t
systemctl restart nginx
```

---

## 📊 Monitoreo

### Memoria
```bash
free -h
```

### CPU
```bash
top -u odoo
```

### Disco
```bash
df -h
```

### Conexiones de Base de Datos
```bash
sudo -u postgres psql -c "SELECT count(*) FROM pg_stat_activity;"
```

---

## 🔄 Actualizaciones

### Actualizar Odoo
```bash
cd /odoo/odoo
git pull origin 17.0  # o la versión que uses
systemctl restart odoo
```

### Actualizar Módulos
```bash
# Desde línea de comandos
/odoo/odoo/odoo-bin -c /etc/odoo/odoo.conf -d CODIFICANDO -u all --stop-after-init

# O desde la interfaz web
# Apps → Actualizar lista de apps
```

---

## 📞 Soporte

- **Documentación Odoo**: https://www.odoo.com/documentation
- **SendGrid Docs**: https://docs.sendgrid.com
- **DigitalOcean Community**: https://www.digitalocean.com/community

---

## 📋 Checklist Post-Instalación

- [ ] Acceder a Odoo
- [ ] Cambiar contraseña de admin
- [ ] Configurar empresa
- [ ] Verificar envío de emails (si configuró SendGrid)
- [ ] Configurar backup automático
- [ ] Configurar firewall (ufw)
- [ ] Instalar módulos necesarios

---

**Versión del Script**: 3.0-OPTIMIZED  
**Última actualización**: Enero 2026  
**Autor**: CODIFICANDO
