# Setup SSL Certificates Action

Generate and manage SSL/TLS certificates using Let's Encrypt certbot. Supports both wildcard (DNS-01) and individual (HTTP-01) certificates.

## Features

- 🌐 **Wildcard certificates** (`*.example.com`) using DNS-01 challenge
- 📋 **Individual certificates** for specific subdomains using HTTP-01 challenge
- 🔄 **Auto-renewal** with systemd timer and nginx reload hook
- 🧪 **Staging mode** to test without hitting rate limits
- 📦 **Host installation** for persistent certificates
- ✅ **Idempotent** - safely runs in automated workflows, skips if cert exists and is valid
- 🔁 **Smart renewal** - automatically renews certs within 30 days of expiry

## Prerequisites

- VPS with nginx already set up (using `setup-vps-nginx` action)
- Domain name with DNS access (for wildcard certs)
- Email address for Let's Encrypt notifications

## Important: Idempotent Behavior

This action is **idempotent** and safe to include in automated workflows:

- ✅ **Skips generation** if valid certificate exists (>30 days until expiry)
- 🔄 **Auto-renews** if certificate expires within 30 days
- 🚀 **No manual intervention** needed after first-time setup
- ⚠️ **First-time DNS-01**: Requires manual DNS TXT record (run separately)

**For automated workflows**: Run DNS-01 setup once manually, then include action in CI/CD - it will skip if cert is valid or auto-renew when needed.

## Usage

### Wildcard Certificate (Recommended for Multiple Subdomains)

```yaml
- name: Generate Wildcard SSL Certificate
  uses: affpro/vps-deploybot/setup-ssl-certificates@v0.0.83
  with:
    host: ${{ secrets.VPS_HOST }}
    user: ${{ secrets.VPS_USER }}
    cert_type: wildcard
    domain: taxi-laguna.com
    email: admin@taxi-laguna.com
    challenge_type: dns
    skip_if_exists: true  # Default: skips if cert valid
```

**First-time setup (requires manual DNS TXT record):**
1. Action installs certbot on VPS
2. Certbot prompts you to add a DNS TXT record
3. Add `_acme-challenge.taxi-laguna.com` TXT record with provided value
4. Certificate generated for `taxi-laguna.com` and `*.taxi-laguna.com`
5. Certificates stored at `/etc/letsencrypt/live/taxi-laguna.com/`

**Subsequent runs:**
- Action checks existing certificate
- Skips if valid (>30 days until expiry)
- Auto-renews if <30 days until expiry

### Individual Certificate (Specific Subdomains)

```yaml
- name: Generate Individual SSL Certificate
  uses: affpro/vps-deploybot/setup-ssl-certificates@v0.0.82
  with:
    host: ${{ secrets.VPS_HOST }}
    user: ${{ secrets.VPS_USER }}
    cert_type: individual
    domain: taxi-laguna.com
    subdomains: api,admin,www
    email: admin@taxi-laguna.com
    challenge_type: http
    webroot_path: /var/www/certbot
```

**Note:** HTTP-01 challenge requires domain DNS already pointing to your VPS.

### Testing with Staging (Avoid Rate Limits)

```yaml
- name: Test SSL Certificate Generation
  uses: affpro/vps-deploybot/setup-ssl-certificates@v0.0.82
  with:
    host: ${{ secrets.VPS_HOST }}
    user: ${{ secrets.VPS_USER }}
    cert_type: wildcard
    domain: taxi-laguna.com
    email: admin@taxi-laguna.com
    challenge_type: dns
    staging: "true"  # Use staging server
```

## Using Certificates with Nginx

After generating certificates, configure your services with SSL:

```yaml
- name: Configure Service with SSL
  uses: affpro/vps-deploybot/configure-nginx-service@v0.0.80
  with:
    host: ${{ secrets.VPS_HOST }}
    user: ${{ secrets.VPS_USER }}
    service_name: api
    container_name: my-api
    container_port: 3000
    routing_type: subdomain
    server_name: api.taxi-laguna.com
    enable_ssl: "true"
    ssl_cert_path: /etc/nginx/letsencrypt/live/taxi-laguna.com/fullchain.pem
    ssl_key_path: /etc/nginx/letsencrypt/live/taxi-laguna.com/privkey.pem
```

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `host` | Yes | - | VPS hostname or IP |
| `user` | Yes | - | SSH username |
| `port` | No | `22` | SSH port |
| `cert_type` | Yes | - | `wildcard` or `individual` |
| `domain` | Yes | - | Primary domain (e.g., `taxi-laguna.com`) |
| `subdomains` | No | `""` | Comma-separated subdomains for individual certs |
| `email` | Yes | - | Email for Let's Encrypt notifications |
| `challenge_type` | No | `dns` | `dns` or `http` (wildcard requires `dns`) |
| `webroot_path` | No | `/var/www/certbot` | Webroot path for HTTP-01 challenge |
| `nginx_container_name` | No | `nginx_proxy` | Nginx container name for reload hook |
| `staging` | No | `false` | Use staging server for testing |
| `skip_if_exists` | No | `true` | Skip if valid cert exists (>30 days until expiry) |
| `force_renewal` | No | `false` | Force renewal even if cert is valid |

## Certificate Paths

After successful generation:

- **Certificate**: `/etc/letsencrypt/live/{domain}/fullchain.pem`
- **Private Key**: `/etc/letsencrypt/live/{domain}/privkey.pem`

These are automatically mounted into nginx container at:
- `/etc/nginx/letsencrypt/live/{domain}/fullchain.pem`
- `/etc/nginx/letsencrypt/live/{domain}/privkey.pem`

## Auto-Renewal

Certificates are automatically configured for renewal:

- **Method**: systemd timer (certbot.timer)
- **Frequency**: Checks twice daily
- **Hook**: Automatically reloads nginx container after renewal
- **Test renewal**: `sudo certbot renew --dry-run`

## Workflow Integration Strategies

### Strategy 1: Automated (Recommended)

Include SSL action in your main deployment workflow. It will:
- ✅ Skip if cert exists and valid
- 🔄 Auto-renew if expiring soon (<30 days)
- ⚠️ **First run only**: Manual DNS TXT record required (run workflow manually once)

```yaml
name: Deploy with HTTPS
on:
  push:
    branches: [master]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Setup SSH
        run: |
          mkdir -p ~/.ssh && chmod 700 ~/.ssh
          printf '%s' "${{ secrets.VPS_SSH_KEY }}" > ~/.ssh/id_rsa
          chmod 600 ~/.ssh/id_rsa

      - uses: actions/checkout@v4

      # Setup infrastructure (idempotent)
      - name: Setup Nginx
        uses: affpro/vps-deploybot/setup-vps-nginx@v0.0.83
        with:
          host: ${{ secrets.VPS_HOST }}
          user: ${{ secrets.VPS_USER }}

      # SSL cert check (idempotent - skips if valid, renews if needed)
      - name: Ensure SSL Certificate
        uses: affpro/vps-deploybot/setup-ssl-certificates@v0.0.83
        with:
          host: ${{ secrets.VPS_HOST }}
          user: ${{ secrets.VPS_USER }}
          cert_type: wildcard
          domain: taxi-laguna.com
          email: admin@taxi-laguna.com
          challenge_type: dns
          skip_if_exists: true  # Safe for automation

      # Deploy and configure service
      - name: Configure API Service
        uses: affpro/vps-deploybot/configure-nginx-service@v0.0.80
        with:
          host: ${{ secrets.VPS_HOST }}
          user: ${{ secrets.VPS_USER }}
          service_name: api
          container_name: api-container
          container_port: 3000
          routing_type: subdomain
          server_name: api.taxi-laguna.com
          enable_ssl: "true"
          ssl_cert_path: /etc/nginx/letsencrypt/live/taxi-laguna.com/fullchain.pem
          ssl_key_path: /etc/nginx/letsencrypt/live/taxi-laguna.com/privkey.pem
```

**How to use:**
1. First deployment: Run workflow manually via GitHub UI (you'll need to add DNS TXT record)
2. Subsequent deployments: Workflow runs automatically on push, skips cert generation if valid

### Strategy 2: Separate One-time Setup

Run SSL setup once manually, exclude from main workflow:

```yaml
# .github/workflows/setup-ssl-once.yml
name: One-time SSL Setup
on:
  workflow_dispatch:  # Manual trigger only

jobs:
  ssl-setup:
    runs-on: ubuntu-latest
    steps:
      - name: Setup SSL Certificate
        uses: affpro/vps-deploybot/setup-ssl-certificates@v0.0.83
        with:
          host: ${{ secrets.VPS_HOST }}
          user: ${{ secrets.VPS_USER }}
          cert_type: wildcard
          domain: taxi-laguna.com
          email: admin@taxi-laguna.com
          challenge_type: dns
          force_renewal: false  # Only generate if missing
```

Then use certs in your main workflow without SSL generation step.

## Troubleshooting

### DNS-01 Challenge Not Working
- Ensure you added the exact TXT record value provided by certbot
- Wait a few minutes for DNS propagation
- Verify with: `dig _acme-challenge.taxi-laguna.com TXT`

### HTTP-01 Challenge Fails
- Ensure domain DNS points to your VPS
- Check nginx is running and port 80 is accessible
- Verify webroot path exists and is accessible

### Certificate Already Exists
- The action will prompt you to renew if certificate exists
- To force renewal: `sudo certbot renew --cert-name taxi-laguna.com --force-renewal`

### Rate Limits
- Let's Encrypt has rate limits (50 certs per domain per week)
- Use `staging: "true"` for testing
- See: https://letsencrypt.org/docs/rate-limits/

## Migration Workflow

When migrating to a new VPS before DNS change:

1. **Generate certs on new VPS** using DNS-01 challenge (works before DNS change)
2. **Test services** with HTTPS using Host header: `curl -H "Host: api.taxi-laguna.com" https://144.91.88.1/`
3. **Update DNS** to point to new VPS when ready
4. **Auto-renewal** continues working after DNS change

## Security Notes

- Certificates are stored on host at `/etc/letsencrypt/`
- Mounted read-only into nginx container
- Auto-renewal hook reloads nginx without manual intervention
- Private keys are protected with proper file permissions (600)
