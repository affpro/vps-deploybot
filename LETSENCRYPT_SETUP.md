# Let's Encrypt Certificate Provisioning Setup

## Overview

This document tracks the setup and troubleshooting of the `setup-vps-letsencrypt` composite action for automated SSL certificate provisioning via Hetzner DNS.

## Current Status

### ✅ Completed

1. **Created `setup-vps-letsencrypt` composite action** (v0.0.102)
   - Supports automated certificate provisioning with Hetzner DNS
   - Uses certbot with dns-hetzner plugin for DNS-01 challenge
   - Handles certificate renewal automatically
   - Returns certificate paths for use by nginx

2. **Updated `configure-nginx-service` action** (v0.0.102)
   - Fixed deprecated `listen 443 ssl http2` syntax
   - Added SSL certificate validation
   - Graceful handling of missing certificates

3. **Fixed Installation Issues**
   - v0.0.103: pip3 installation and dependency handling
   - v0.0.104: PEP 668 Ubuntu 24.04+ enforcement (--break-system-packages flag)
   - v0.0.105: Heredoc delimiter fix
   - v0.0.106: YAML parsing error fix
   - v0.0.107: Hetzner credentials property name fix (`dns_hetzner_api_token`)

4. **Verified Hetzner DNS Setup**
   - Domain: `ordus.si`
   - Nameservers correctly delegated to Hetzner:
     - `helium.ns.hetzner.de`
     - `oxygen.ns.hetzner.com`
     - `hydrogen.ns.hetzner.com`
   - Zone created in Hetzner DNS console

### 🔄 In Progress / Blocking Issue

**Problem:** Certbot getting 404 error when trying to find the zone

```
requests.exceptions.HTTPError: 404 Client Error: Not Found
for url: https://dns.hetzner.com/api/v1/zones?name=ordus.si
```

**Current Attempt:**
- Domain: `ordus.si`
- Hetzner Zone: `ordus.si`
- Action: `setup-vps-letsencrypt@v0.0.107`

## Root Cause Analysis

The error indicates that Hetzner's API cannot find the zone `ordus.si`. Possible causes:

1. **DNS Propagation Delay** - Nameservers were recently changed to Hetzner. Full propagation takes 5-30 minutes, sometimes up to 24 hours
2. **API Cache** - Hetzner's API might not have caught up with the zone creation yet
3. **API Token Issue** - Token might not have proper permissions or is incorrect
4. **Zone Name Mismatch** - Zone in console vs. domain being requested

## Next Steps (Tomorrow)

### 1. Verify API Access
Run this command on the VPS to test if Hetzner API can see the zone:

```bash
ssh your-vps
curl -H "Auth-API-Token: YOUR_HETZNER_TOKEN" https://dns.hetzner.com/api/v1/zones
```

**Expected output:** JSON list containing `ordus.si` zone

**If it works:**
- Zone is visible to API
- Proceed to step 2

**If it fails with 404/empty:**
- DNS propagation still in progress
- Wait 10-15 minutes and retry
- Check global DNS propagation: `dig ordus.si NS @8.8.8.8`

**If it fails with 401:**
- API token is incorrect
- Verify token at https://dns.hetzner.com/settings/api-token
- Update GitHub secret `HETZNER_DNS_TOKEN`

### 2. Retry Certificate Provisioning
Once curl command returns the zone, run the deployment workflow again:
- The action should now successfully create the certificate
- Certbot will validate via DNS TXT record
- Certificate will be issued to `/etc/letsencrypt/live/ordus.si/`

### 3. Verify Certificate Creation
After successful provisioning:

```bash
ssh your-vps
sudo ls -la /etc/letsencrypt/live/ordus.si/
sudo openssl x509 -in /etc/letsencrypt/live/ordus.si/fullchain.pem -text -noout | grep -A2 "Subject Alternative Name"
```

### 4. Configure Nginx Service
Once certificate exists, deploy your service:

```yaml
- uses: ./configure-nginx-service
  with:
    host: ${{ secrets.VPS_HOST }}
    user: ${{ secrets.VPS_USER }}
    service_name: your-service
    container_name: your-container
    container_port: 3000
    routing_type: subdomain
    server_name: api.ordus.si  # or your subdomain
    enable_ssl: "true"
    ssl_cert_path: /etc/letsencrypt/live/ordus.si/fullchain.pem
    ssl_key_path: /etc/letsencrypt/live/ordus.si/privkey.pem
```

## GitHub Secrets Required

Make sure these are set in your repository:

```
VPS_HOST              # Your VPS hostname/IP
VPS_USER              # SSH username
VPS_SSH_KEY           # OpenSSH private key
HETZNER_DNS_TOKEN     # From https://dns.hetzner.com/settings/api-token
LETSENCRYPT_EMAIL     # Email for renewal notifications
```

## Action Usage Reference

### Setup Let's Encrypt Certificate

```yaml
- uses: affpro/vps-deploybot/setup-vps-letsencrypt@v0.0.107
  with:
    host: ${{ secrets.VPS_HOST }}
    user: ${{ secrets.VPS_USER }}
    domain: ordus.si
    additional_domains: "www.ordus.si,api.ordus.si"  # Optional
    hetzner_dns_token: ${{ secrets.HETZNER_DNS_TOKEN }}
    email: ${{ secrets.LETSENCRYPT_EMAIL }}
    certificates_dir: /etc/letsencrypt  # Optional, defaults shown
    force_renewal: "false"  # Optional
```

### Outputs

```yaml
steps:
  - id: ssl
    uses: affpro/vps-deploybot/setup-vps-letsencrypt@v0.0.107
    # ...

  - uses: ./configure-nginx-service
    with:
      ssl_cert_path: ${{ steps.ssl.outputs.cert_path }}
      ssl_key_path: ${{ steps.ssl.outputs.key_path }}
```

## Troubleshooting Checklist

- [ ] DNS nameservers point to Hetzner (verify with `nslookup -type=NS ordus.si`)
- [ ] Zone `ordus.si` exists in Hetzner DNS console
- [ ] API token is correct (test with curl command above)
- [ ] API token has permissions to manage zones
- [ ] DNS propagation is complete (wait if recent change)
- [ ] Certbot plugin is installed: `python3 -c "import certbot_dns_hetzner"`
- [ ] Credentials file exists: `ls -la /etc/letsencrypt/hetzner_dns_credentials.ini`

## Related Files

- Action code: `/setup-vps-letsencrypt/action.yml`
- Nginx config action: `/configure-nginx-service/action.yml`
- Project docs: `/CLAUDE.md`

## Version History

- v0.0.107: Fixed Hetzner API token property name (`dns_hetzner_api_token`)
- v0.0.106: Fixed YAML parsing error with printf/tee
- v0.0.105: Fixed heredoc delimiter
- v0.0.104: Fixed PEP 668 Ubuntu 24.04+ enforcement
- v0.0.103: Fixed pip3 installation
- v0.0.102: Initial setup-vps-letsencrypt action
