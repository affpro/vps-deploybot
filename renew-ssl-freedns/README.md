# Renew SSL Certificate (FreeDNS.si)

Automatically renew wildcard SSL certificates from Let's Encrypt using FreeDNS.si DNS validation with certbot.

## Features

- ✅ Supports wildcard certificates (`*.domain.com`)
- ✅ Uses FreeDNS.si DNS-01 challenge for validation
- ✅ Fully automated renewal process
- ✅ No manual DNS updates required
- ✅ Auto-renewal via cron job
- ✅ Optional Nginx Docker container reload
- ✅ ECDSA key type for better performance

## Prerequisites

- VPS with SSH access
- FreeDNS.si account with domain management access
- Domain managed by FreeDNS.si nameservers
- Certbot installed (or will be installed automatically)

## Usage

### GitHub Actions Workflow

```yaml
name: Renew SSL Certificate

on:
  workflow_dispatch:
  schedule:
    - cron: '0 3 1 * *'  # Run monthly at 3 AM

jobs:
  renew-ssl:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Setup SSH Key
        uses: ./setup-vps-connection
        with:
          host: ${{ secrets.VPS_HOST }}
          user: ${{ secrets.VPS_USER }}
          ssh_key: ${{ secrets.VPS_SSH_KEY }}

      - name: Renew SSL Certificate
        uses: ./renew-ssl-freedns
        with:
          host: ${{ secrets.VPS_HOST }}
          user: ${{ secrets.VPS_USER }}
          domain: taxi-laguna.com
          wildcard: "true"
          freedns_username: ${{ secrets.FREEDNS_USERNAME }}
          freedns_password: ${{ secrets.FREEDNS_PASSWORD }}
          email: ${{ secrets.LETSENCRYPT_EMAIL }}
          nginx_container: nginx_proxy
```

### Required GitHub Secrets

Add these secrets to your GitHub repository:

- `VPS_HOST` - VPS hostname or IP address
- `VPS_USER` - SSH username
- `VPS_SSH_KEY` - OpenSSH private key for VPS access
- `FREEDNS_USERNAME` - FreeDNS.si username
- `FREEDNS_PASSWORD` - FreeDNS.si password
- `LETSENCRYPT_EMAIL` - Email for Let's Encrypt notifications

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `host` | VPS hostname or IP | Yes | - |
| `user` | SSH username | Yes | - |
| `port` | SSH port | No | `22` |
| `domain` | Primary domain (e.g., taxi-laguna.com) | Yes | - |
| `wildcard` | Include wildcard certificate | No | `true` |
| `freedns_username` | FreeDNS.si username | Yes | - |
| `freedns_password` | FreeDNS.si password | Yes | - |
| `email` | Let's Encrypt email | Yes | - |
| `certificates_dir` | Certificate storage directory | No | `/etc/letsencrypt` |
| `hook_script_dir` | Hook script directory | No | `/opt/certbot-freedns` |
| `force_renewal` | Force renewal even if valid | No | `false` |
| `nginx_container` | Nginx Docker container name | No | `""` |

## Outputs

| Output | Description |
|--------|-------------|
| `cert_path` | Path to the certificate file |
| `key_path` | Path to the private key file |
| `cert_dir` | Directory containing certificates |

## How It Works

1. **Upload Hook Script**: Uploads the FreeDNS.si hook script to the VPS (if not already present)
2. **Create Temporary Credentials**: Creates credentials file temporarily on the VPS
3. **Renew Certificate**: Runs certbot with DNS-01 challenge using the hook script
4. **Update DNS**: Hook script automatically creates/deletes TXT records in FreeDNS
5. **Clean Up**: Removes temporary credentials file immediately after renewal
6. **Reload Nginx**: Optionally reloads Nginx Docker container

**Security**: Credentials are passed from GitHub Secrets and only exist on the VPS during the renewal process.

## Scheduled Renewal

Use GitHub Actions scheduled workflows to automate renewal:

```yaml
on:
  schedule:
    - cron: '0 3 1 * *'  # Run monthly on the 1st at 3 AM UTC
```

Certificates are renewed only when the GitHub Action runs. **No credentials are stored on the VPS**.

## Troubleshooting

### Check Certificate Status
```bash
ssh admin@your-vps "sudo certbot certificates"
```

### Test Renewal (Dry Run)
Run the GitHub Action with `force_renewal: true` to test the renewal process.

## Security Notes

- ✅ **No persistent credentials on VPS** - Credentials only exist during renewal process
- ✅ **Temporary files cleaned up** - Credentials file deleted immediately after use
- ✅ **GitHub Secrets only** - Credentials stored securely in GitHub, never in code
- ✅ **Root-only access** - All operations run with sudo/root permissions
- ⚠️ Never commit credentials to the repository

## Credits

- FreeDNS hook script by [damir-dezeljin](https://github.com/damir-dezeljin/CertBot-FreeDns.si)
- Based on work by Anthony Wharton for FreeDNS.afraid.org
