# Ensure SSL Certificate (FreeDNS.si)

Intelligently checks if an SSL certificate exists for a domain and creates it if missing. Optionally renews if expiring soon.

## Features

- ✅ **Smart Detection**: Checks if certificate already exists
- ✅ **Auto-Create**: Creates certificate if missing
- ✅ **Auto-Renew**: Optionally renews if expiring within threshold
- ✅ **Wildcard Support**: Supports `*.domain.com` certificates
- ✅ **Zero Credentials on VPS**: Temporary credentials only
- ✅ **FreeDNS.si Integration**: Automatic DNS validation

## Difference from renew-ssl-freedns

| Feature | ensure-ssl-certificate | renew-ssl-freedns |
|---------|------------------------|-------------------|
| **Use Case** | Initial setup + renewal | Renewal only |
| **Checks Existence** | ✅ Yes | ❌ No |
| **Creates if Missing** | ✅ Yes | ❌ No |
| **Auto-Renew Threshold** | ✅ Configurable | ❌ Always renews |
| **When to Use** | Service deployment workflows | Dedicated renewal workflows |

## Usage

### In Deployment Workflow

```yaml
- name: Ensure SSL Certificate
  uses: affpro/vps-deploybot/ensure-ssl-certificate@v0.0.163
  with:
    host: ${{ secrets.VPS_HOST }}
    user: ${{ secrets.VPS_USER }}
    domain: taxi-laguna.com
    wildcard: "true"
    freedns_username: ${{ secrets.FREEDNS_USERNAME }}
    freedns_password: ${{ secrets.FREEDNS_PASSWORD }}
    email: ${{ secrets.LETSENCRYPT_EMAIL }}
    renew_days_before_expiry: "30"  # Renew if < 30 days left
    nginx_container: nginx_proxy
```

### Check Action Output

```yaml
- name: Ensure SSL Certificate
  id: ssl
  uses: affpro/vps-deploybot/ensure-ssl-certificate@v0.0.163
  with:
    # ... inputs ...

- name: Show What Happened
  run: |
    echo "Action taken: ${{ steps.ssl.outputs.action_taken }}"
    echo "Days until expiry: ${{ steps.ssl.outputs.days_until_expiry }}"
    echo "Certificate path: ${{ steps.ssl.outputs.cert_path }}"
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `host` | VPS hostname or IP | Yes | - |
| `user` | SSH username | Yes | - |
| `port` | SSH port | No | `22` |
| `domain` | Domain name | Yes | - |
| `wildcard` | Include wildcard cert | No | `true` |
| `freedns_username` | FreeDNS.si username | Yes | - |
| `freedns_password` | FreeDNS.si password | Yes | - |
| `email` | Let's Encrypt email | Yes | - |
| `certificates_dir` | Cert directory on VPS | No | `/etc/letsencrypt` |
| `hook_script_dir` | Hook scripts directory | No | `/opt/certbot-freedns` |
| `renew_days_before_expiry` | Auto-renew threshold (0 = never) | No | `30` |
| `nginx_container` | Nginx container to reload | No | `""` |

## Outputs

| Output | Description |
|--------|-------------|
| `cert_path` | Path to certificate file |
| `key_path` | Path to private key file |
| `cert_dir` | Certificate directory |
| `action_taken` | `created`, `renewed`, or `skipped` |
| `days_until_expiry` | Days until expiry (if exists) |

## Behavior

### Certificate Doesn't Exist
```
ℹ️  No certificate found, creating new certificate...
🚀 Created certificate from Let's Encrypt...
✅ Certificate successfully created
```

### Certificate Exists, Not Expiring Soon
```
📋 Certificate already exists
   Expires: 2025-03-15
   Days remaining: 95
✅ Certificate is valid for 95 more days (threshold: 30 days)
ℹ️  Skipping renewal
```

### Certificate Exists, Expiring Soon
```
📋 Certificate already exists
   Expires: 2025-01-05
   Days remaining: 25
⚠️  Certificate expires in 25 days (threshold: 30 days)
🔄 Renewing certificate...
✅ Certificate successfully renewed
```

## Example: Integration in Service Deployment

```yaml
name: Deploy to Production

on:
  push:
    branches: [master]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup SSH
        uses: affpro/vps-deploybot/setup-vps-connection@v0.0.163
        with:
          host: ${{ secrets.VPS_HOST }}
          user: ${{ secrets.VPS_USER }}
          private_key: ${{ secrets.VPS_SSH_KEY }}

      # Ensure SSL cert exists before deploying
      - name: Ensure SSL Certificate
        id: ssl
        uses: affpro/vps-deploybot/ensure-ssl-certificate@v0.0.163
        with:
          host: ${{ secrets.VPS_HOST }}
          user: ${{ secrets.VPS_USER }}
          domain: api.example.com
          wildcard: "false"
          freedns_username: ${{ secrets.FREEDNS_USERNAME }}
          freedns_password: ${{ secrets.FREEDNS_PASSWORD }}
          email: ${{ secrets.LETSENCRYPT_EMAIL }}
          nginx_container: nginx_proxy

      - name: Deploy Application
        run: echo "Deploy app knowing SSL is ready"

      - name: Show SSL Status
        run: |
          echo "SSL Action: ${{ steps.ssl.outputs.action_taken }}"
          if [ "${{ steps.ssl.outputs.action_taken }}" = "created" ]; then
            echo "🎉 New certificate was created!"
          fi
```

## Security Notes

- ✅ No persistent credentials on VPS
- ✅ Credentials created temporarily, deleted immediately
- ✅ Hook script persists, but contains no credentials
- ✅ All secrets stored in GitHub only
