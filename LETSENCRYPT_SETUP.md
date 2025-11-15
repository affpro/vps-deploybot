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
- Port 80 (HTTP) to be accessible on your VPS
- No other service running on port 80 during certificate provisioning
- The VPS must be reachable from the internet on port 80

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

### Certificate provisioning fails with connection error

**Possible causes and solutions:**

1. **Port 80 not accessible** - HTTP-01 validation requires port 80 to be open
   ```bash
   # Check if port 80 is accessible from internet
   curl -v http://example.com/.well-known/acme-challenge/test
   ```
   - Verify UFW allows port 80: `sudo ufw status | grep 80`
   - If blocked, allow it temporarily: `sudo ufw allow 80`
   - Or configure VPS firewall to allow port 80

2. **Another service on port 80** - A web server may be running on port 80
   - Check running services: `sudo netstat -tulpn | grep :80`
   - Temporarily stop the service during provisioning
   - Or use a different challenge type (requires DNS API integration)

3. **Domain DNS not pointing to VPS** - DNS must resolve to your VPS IP
   ```bash
   # Check DNS resolution
   nslookup example.com
   # Should show your VPS public IP
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
