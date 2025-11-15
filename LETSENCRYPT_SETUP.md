# Let's Encrypt Certificate Provisioning Setup

## Overview

This document explains SSL certificate provisioning with Let's Encrypt using **acme.sh** for automated certificate management and renewal.

## Current Status: ✅ Recommended Setup

The deployment workflows now use the **recommended `setup-vps-letsencrypt-acmesh` action** which provides:

- ✅ **Pure shell script** - No Python dependencies
- ✅ **HTTP-01 validation** - Simple standalone webserver challenge (no DNS API required)
- ✅ **Automatic renewal** - acme.sh automatically checks and renews certificates
- ✅ **Zero-downtime** - Renews certificates 60 days before expiration
- ✅ **Simple setup** - Minimal configuration required
- ✅ **Compatible with all DNS providers** - Works with any domain

### Action Options Available

1. **✅ NEW (Recommended): `setup-vps-letsencrypt-acmesh`**
   - Uses acme.sh with HTTP-01 standalone validation
   - No DNS API token required
   - No Python dependencies (pure shell)
   - Automatic renewal via acme.sh background cron job
   - Works with any DNS provider (Hetzner, Cloudflare, etc.)

2. **Legacy: `setup-vps-letsencrypt`** (For old DNS API)
   - Uses certbot with dns-hetzner plugin
   - Requires old `dns.hetzner.com` API
   - Higher setup complexity (Python dependencies)
   - Token from: https://dns.hetzner.com (deprecated)

## Quick Start: Setup acme.sh Certificate Provisioning

### Step 1: Prepare Your VPS

The acme.sh action uses HTTP-01 validation, which requires:
- **Port 80 (HTTP) must be accessible** from the internet on your VPS
- **No other service running on port 80** during certificate provisioning (nginx, Apache, etc. must be stopped)
- **Domain DNS must point to your VPS** - Let's Encrypt will connect to http://yourdomain.com to validate
- The action automatically installs `socat` and `curl` (required for HTTP-01 webserver) if not present

**Pre-flight checks:**
```bash
# 1. Check if port 80 is open in your firewall
sudo ufw status | grep 80

# 2. Check DNS resolution
nslookup yourdomain.com
# Should return your VPS public IP

# 3. Check if port 80 is already in use
sudo netstat -tulpn | grep :80
# Or: sudo lsof -i :80
```

### Step 2: Ensure GitHub Secrets Are Set

Required secrets in your repository:

```
VPS_HOST              # Your VPS hostname or IP address
VPS_USER              # SSH username for VPS
VPS_SSH_KEY           # OpenSSH private key for SSH access
LETSENCRYPT_EMAIL     # Email for renewal notifications
```

Note: Unlike the legacy approach, the new acme.sh action does **not** require a Hetzner API token.

### Step 3: Use in Your Workflow

Add this step to your GitHub Actions workflow:

```yaml
- name: Provision SSL Certificate (acme.sh)
  id: ssl
  uses: affpro/vps-deploybot/setup-vps-letsencrypt-acmesh@v0.0.120
  with:
    host: ${{ secrets.VPS_HOST }}
    user: ${{ secrets.VPS_USER }}
    domain: example.com
    additional_domains: "www.example.com,api.example.com"  # Optional
    email: ${{ secrets.LETSENCRYPT_EMAIL }}
```

The action will:
1. Install acme.sh on your VPS
2. Start a temporary HTTP-01 validation webserver
3. Let's Encrypt validates domain ownership via HTTP
4. Install certificate to `/etc/letsencrypt/live/example.com/`

### Step 4: Use Certificate Paths in Next Steps

The acme.sh action outputs certificate paths for use by nginx:

```yaml
- name: Configure Nginx Service
  uses: affpro/vps-deploybot/configure-nginx-service@v0.0.119
  with:
    host: ${{ secrets.VPS_HOST }}
    user: ${{ secrets.VPS_USER }}
    service_name: my-api
    container_name: my-api-container
    container_port: 3000
    routing_type: subdomain
    server_name: api.example.com
    enable_ssl: true
    ssl_cert_path: ${{ steps.ssl.outputs.cert_path }}
    ssl_key_path: ${{ steps.ssl.outputs.key_path }}
```

### Step 5: Automatic Certificate Renewal

acme.sh automatically handles certificate renewal:

- **Daily cron job** - Runs certificate renewal checks
- **Smart renewal** - Only renews when needed (60+ days before expiration)
- **Zero-downtime** - Renews in background without service interruption
- **No manual intervention** - Fully automatic process

Verify renewal on your VPS:

```bash
ssh user@your-vps
# Check cron job
crontab -l | grep acme

# Check certificate expiration
sudo openssl x509 -enddate -noout -in /etc/letsencrypt/live/example.com/fullchain.pem
```

## Action Inputs and Outputs

### Inputs

```yaml
host:                   # Required: VPS hostname or IP
user:                   # Required: SSH username
domain:                 # Required: Primary domain (e.g., example.com)
additional_domains:     # Optional: Comma-separated additional domains
hetzner_dns_token:      # Required: Hetzner Cloud API token
email:                  # Required: Email for Let's Encrypt notifications
port:                   # Optional: SSH port (default: 22)
certificates_dir:       # Optional: Certificate storage directory (default: /etc/letsencrypt)
force_renewal:          # Optional: Force renewal even if valid (default: false)
```

### Outputs

After the action completes, use these outputs in subsequent steps:

```yaml
cert_path:    # Full path to certificate file (fullchain.pem)
key_path:     # Full path to private key file (privkey.pem)
cert_dir:     # Directory containing certificate files
```

## Troubleshooting

### Certificate provisioning fails with "Please install socat tools first"

**Solution:**

The action automatically installs `socat`, but if installation fails:

```bash
ssh user@your-vps

# Install socat manually
sudo apt-get update
sudo apt-get install -y socat curl

# Try certificate provisioning again
```

### Certificate provisioning fails with "validation failed" or connection errors

**The action provides diagnostics in the error output. Look for:**

1. **Port 80 status** - The action will show if port 80 is listening
   - Solution: `sudo ufw allow 80` to allow port 80
   - Or configure your firewall to accept HTTP traffic

2. **Services on port 80** - Shows what's using port 80 if blocked
   ```bash
   # Stop the service temporarily
   sudo systemctl stop nginx    # or apache2, httpd, etc.

   # Run the action to provision certificate

   # Restart the service
   sudo systemctl start nginx
   ```

3. **acme.sh detailed log** - The action shows the detailed log from acme.sh
   - Log location displayed: `~/.acme.sh/{domain}/{domain}.log`
   - Manually check: `cat ~/.acme.sh/example.com/example.com.log`

**Common error messages and solutions:**

- `"Connection refused"` - Port 80 blocked by firewall or service
  ```bash
  sudo ufw allow 80
  ```

- `"Timeout waiting for validation"` - DNS not pointing to VPS or port not accessible
  ```bash
  # Verify DNS
  dig example.com +short
  # Should return your VPS public IP
  ```

- `"http validation failed"` - Let's Encrypt can't reach your VPS
  ```bash
  # Test accessibility from outside
  curl -v http://example.com/.well-known/acme-challenge/test
  # Should show HTTP 404 (not a certificate error)
  ```

### Certificate files not found after provisioning

Check acme.sh installation on VPS:

```bash
ssh user@your-vps

# Check if acme.sh is installed
ls -la ~/.acme.sh/

# Check certificate files
ls -la /etc/letsencrypt/live/example.com/

# Check acme.sh log
cat ~/.acme.sh/example.com/example.com.log
```

### Manual certificate renewal

Force certificate renewal on your VPS:

```bash
ssh user@your-vps

# Renew specific domain
~/.acme.sh/acme.sh --renew -d example.com --force

# Renew all certificates
~/.acme.sh/acme.sh --cron --force
```

## Related Actions

- **configure-nginx-service** - Setup nginx reverse proxy with SSL
- **setup-vps-letsencrypt** - Legacy certbot option (for old Hetzner DNS API)
- **setup-vps-connection** - SSH connection setup

## Reference

- [acme.sh Official Documentation](https://github.com/acmesh-official/acme.sh)
- [Hetzner Cloud API Documentation](https://docs.hetzner.cloud/)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- Project guide: `/CLAUDE.md`
