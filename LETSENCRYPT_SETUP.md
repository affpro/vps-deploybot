# Let's Encrypt Certificate Provisioning Setup

## Overview

This document explains SSL certificate provisioning with Let's Encrypt using **acme.sh** and Hetzner Cloud DNS for automated renewal.

## Current Status: ✅ Recommended Setup

The deployment workflows now use the **recommended `setup-vps-letsencrypt-acmesh` action** which provides:

- ✅ **Pure shell script** - No Python dependencies
- ✅ **Hetzner Cloud DNS API** - Uses modern `api.hetzner.cloud/v1` endpoint
- ✅ **Automatic renewal** - Daily cron job for certificate checks
- ✅ **Zero-downtime** - Renews certificates 60 days before expiration
- ✅ **Simple setup** - Minimal configuration required

### Action Options Available

1. **✅ NEW (Recommended): `setup-vps-letsencrypt-acmesh`**
   - Uses acme.sh with Hetzner Cloud DNS API
   - Works with modern Hetzner Cloud infrastructure
   - No Python dependencies (pure shell)
   - Automatic renewal via daily cron job
   - Token from: https://console.hetzner.cloud

2. **Legacy: `setup-vps-letsencrypt`** (For old DNS API)
   - Uses certbot with dns-hetzner plugin
   - Requires old `dns.hetzner.com` API
   - Higher setup complexity (Python dependencies)
   - Token from: https://dns.hetzner.com (deprecated)

## Quick Start: Setup acme.sh Certificate Provisioning

### Step 1: Get Your Hetzner Cloud API Token

1. Go to [Hetzner Cloud Console](https://console.hetzner.cloud)
2. Select your project
3. Navigate to **Security → API Tokens**
4. Click "Generate API Token"
5. Set permissions to **Read & Write** (required for DNS management)
6. Save the token securely
7. Add to GitHub: Settings → Secrets and variables → Actions → New repository secret
   - Name: `HETZNER_DNS_TOKEN`
   - Value: Your API token

### Step 2: Ensure GitHub Secrets Are Set

Required secrets in your repository:

```
VPS_HOST              # Your VPS hostname or IP address
VPS_USER              # SSH username for VPS
VPS_SSH_KEY           # OpenSSH private key for SSH access
HETZNER_DNS_TOKEN     # Hetzner Cloud API token (from Step 1)
LETSENCRYPT_EMAIL     # Email for renewal notifications
```

### Step 3: Use in Your Workflow

Add this step to your GitHub Actions workflow:

```yaml
- name: Provision SSL Certificate (acme.sh)
  id: ssl
  uses: affpro/vps-deploybot/setup-vps-letsencrypt-acmesh@v0.0.115
  with:
    host: ${{ secrets.VPS_HOST }}
    user: ${{ secrets.VPS_USER }}
    domain: example.com
    additional_domains: "www.example.com,api.example.com"  # Optional
    hetzner_dns_token: ${{ secrets.HETZNER_DNS_TOKEN }}
    email: ${{ secrets.LETSENCRYPT_EMAIL }}
```

### Step 4: Use Certificate Paths in Next Steps

The acme.sh action outputs certificate paths for use by nginx:

```yaml
- name: Configure Nginx Service
  uses: affpro/vps-deploybot/configure-nginx-service@v0.0.115
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

### Certificate provisioning fails with "zone not found"

**Possible causes and solutions:**

1. **DNS not propagated** - If you recently changed nameservers to Hetzner, wait 15-30 minutes for propagation
   ```bash
   # Check nameservers
   nslookup -type=NS example.com
   # Should show: helium.ns.hetzner.de, oxygen.ns.hetzner.com, hydrogen.ns.hetzner.com
   ```

2. **API token permissions** - Ensure token has "Read & Write" permissions for DNS
   - Go to Hetzner Cloud Console → Security → API Tokens
   - Check token permissions (should include DNS management)

3. **Zone not created** - Verify zone exists in Hetzner Cloud
   - Go to Hetzner Cloud Console → Networking → Zones
   - Zone name must match your domain exactly

4. **Wrong API token** - Using old dns.hetzner.com token instead of Hetzner Cloud token
   - Get new token from https://console.hetzner.cloud (not dns.hetzner.com)

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
