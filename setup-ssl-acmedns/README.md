# Setup SSL Certificate with ACME-DNS

Provision and renew wildcard SSL certificates using **acme-dns** for instant DNS validation - perfect for slow DNS providers like FreeDNS.si.

## The Problem

When using DNS-01 challenge with slow DNS providers (FreeDNS.si, GoDaddy, etc.):
- DNS TXT records take **minutes to propagate**
- Let's Encrypt verification **fails** before propagation completes
- Renewals **fail randomly** due to DNS caching
- Manual retries required

## The Solution: ACME-DNS

**acme-dns** is a specialized DNS server designed specifically for ACME challenges:

```
Traditional DNS (FreeDNS):
Update TXT → Wait 5-10 minutes → Let's Encrypt verifies → Success/Fail

ACME-DNS:
Update TXT → Instant (< 1 second) → Let's Encrypt verifies → Success ✅
```

### How It Works

```
1. One-time CNAME setup on FreeDNS:
   _acme-challenge.taxi-laguna.com → abc123.auth.acme-dns.io

2. During certificate validation:
   Let's Encrypt checks: _acme-challenge.taxi-laguna.com
   ↓ Follows CNAME to
   abc123.auth.acme-dns.io (updated instantly by acme-dns)
   ↓ Finds correct TXT record
   ✅ Validation succeeds immediately
```

### Key Benefits

- ✅ **Instant DNS propagation** (no waiting!)
- ✅ **100% success rate** (no random failures)
- ✅ **Keep your DNS provider** (FreeDNS, GoDaddy, etc.)
- ✅ **One-time CNAME setup** (never changes)
- ✅ **Works with any domain**
- ✅ **Free public service** (or self-host)

## Prerequisites

### 1. Register with acme-dns

Run this command once to get your credentials:

```bash
curl -X POST https://auth.acme-dns.io/register
```

**Response** (SAVE THESE!):
```json
{
  "username": "eabcdb41-d89f-4580-826f-3e62e9755ef2",
  "password": "pbkdf2_sha512$100000$...",
  "fulldomain": "d420c923-bbd7-4056-acf4-77ba63c85dd1.auth.acme-dns.io",
  "subdomain": "d420c923-bbd7-4056-acf4-77ba63c85dd1",
  "allowfrom": []
}
```

### 2. Create CNAME on Your DNS Provider

**On FreeDNS.si** (or your DNS provider):

```
Record Type: CNAME
Name: _acme-challenge
Points to: [fulldomain from step 1]
TTL: Any (doesn't matter, CNAME is static)
```

**Example**:
```
_acme-challenge.taxi-laguna.com  CNAME  d420c923-bbd7-4056-acf4-77ba63c85dd1.auth.acme-dns.io
```

**Important**:
- This CNAME is **set once** and **never changes**
- You only need to wait for propagation **this one time**
- All future certificate operations are instant

### 3. Verify CNAME Propagation

Wait a few minutes, then verify:

```bash
dig _acme-challenge.taxi-laguna.com CNAME +short
```

Should return:
```
d420c923-bbd7-4056-acf4-77ba63c85dd1.auth.acme-dns.io.
```

### 4. Add GitHub Secrets

In your repository (Settings → Secrets → Actions), add:

| Secret Name | Value | Example |
|-------------|-------|---------|
| `ACMEDNS_USERNAME` | Username from registration | `eabcdb41-d89f-...` |
| `ACMEDNS_PASSWORD` | Password from registration | `pbkdf2_sha512$...` |
| `ACMEDNS_FULLDOMAIN` | Full domain from registration | `d420c923-bbd7-...auth.acme-dns.io` |
| `ACMEDNS_SUBDOMAIN` | Subdomain from registration | `d420c923-bbd7-...` |

## Usage

### Basic Usage

```yaml
- name: Setup SSL Certificate with ACME-DNS
  uses: affpro/vps-deploybot/setup-ssl-acmedns@v0.0.165
  with:
    host: ${{ secrets.VPS_HOST }}
    user: ${{ secrets.VPS_USER }}
    domain: taxi-laguna.com
    wildcard: "true"
    acmedns_username: ${{ secrets.ACMEDNS_USERNAME }}
    acmedns_password: ${{ secrets.ACMEDNS_PASSWORD }}
    acmedns_fulldomain: ${{ secrets.ACMEDNS_FULLDOMAIN }}
    acmedns_subdomain: ${{ secrets.ACMEDNS_SUBDOMAIN }}
    email: admin@taxi-laguna.com
    nginx_container: nginx_proxy
```

### Complete Workflow Example

```yaml
name: Deploy to Production

on:
  push:
    branches: [master]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Setup SSH Connection
        uses: affpro/vps-deploybot/setup-vps-connection@v0.0.165
        with:
          host: ${{ secrets.VPS_HOST }}
          user: ${{ secrets.VPS_USER }}
          private_key: ${{ secrets.VPS_SSH_KEY }}

      - name: Setup SSL Certificate
        uses: affpro/vps-deploybot/setup-ssl-acmedns@v0.0.165
        with:
          host: ${{ secrets.VPS_HOST }}
          user: ${{ secrets.VPS_USER }}
          domain: taxi-laguna.com
          wildcard: "true"
          acmedns_username: ${{ secrets.ACMEDNS_USERNAME }}
          acmedns_password: ${{ secrets.ACMEDNS_PASSWORD }}
          acmedns_fulldomain: ${{ secrets.ACMEDNS_FULLDOMAIN }}
          acmedns_subdomain: ${{ secrets.ACMEDNS_SUBDOMAIN }}
          email: ${{ secrets.LETSENCRYPT_EMAIL }}
          nginx_container: nginx_proxy
          force_renewal: "false"

      # ... rest of deployment steps
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `host` | VPS hostname or IP | Yes | - |
| `user` | SSH username | Yes | - |
| `port` | SSH port | No | `22` |
| `domain` | Domain name | Yes | - |
| `wildcard` | Include wildcard cert | No | `true` |
| `acmedns_username` | ACME-DNS username | Yes | - |
| `acmedns_password` | ACME-DNS password | Yes | - |
| `acmedns_fulldomain` | ACME-DNS full domain | Yes | - |
| `acmedns_subdomain` | ACME-DNS subdomain | Yes | - |
| `email` | Let's Encrypt email | Yes | - |
| `certificates_dir` | Certificate directory | No | `/etc/letsencrypt` |
| `force_renewal` | Force renewal | No | `false` |
| `nginx_container` | Nginx container name | No | `""` |

## Outputs

| Output | Description |
|--------|-------------|
| `cert_path` | Path to certificate file |
| `key_path` | Path to private key file |
| `cert_dir` | Certificate directory |

## How ACME-DNS Works Internally

### Registration Process

When you register with acme-dns:

1. **Server generates** a unique subdomain: `abc123.auth.acme-dns.io`
2. **Server creates** DNS zone for this subdomain
3. **You receive** credentials to update TXT records in this zone
4. **You create** CNAME from your domain to this subdomain

### Validation Process

When certbot requests a certificate:

1. **Certbot** generates a challenge token
2. **certbot-dns-acmedns** sends token to acme-dns API using your credentials
3. **acme-dns** updates TXT record for your subdomain (instant)
4. **Let's Encrypt** queries `_acme-challenge.taxi-laguna.com`
5. **DNS follows** CNAME to `abc123.auth.acme-dns.io`
6. **Let's Encrypt** finds correct TXT record (< 1 second)
7. **Validation succeeds** ✅

### Security

- ✅ **Isolated subdomain** - acme-dns can ONLY update TXT records for `_acme-challenge`
- ✅ **Cannot modify** your main domain DNS
- ✅ **Credentials** are domain-specific (one per domain)
- ✅ **API authentication** required for all updates
- ✅ **No access** to your DNS provider

## Comparison with Other Methods

| Method | DNS Provider | Propagation Time | Success Rate | Setup Complexity |
|--------|--------------|------------------|--------------|------------------|
| **Manual DNS** | Any | 5-10 minutes | ~50% | Easy |
| **FreeDNS Hook** | FreeDNS.si | 5-10 minutes | ~60% | Medium |
| **ACME-DNS** | Any | < 1 second | ~100% | Easy (one-time) |
| **Cloudflare Plugin** | Cloudflare only | ~10 seconds | ~95% | Easy |
| **Route53 Plugin** | AWS only | ~30 seconds | ~98% | Medium |

## Troubleshooting

### CNAME Not Found

**Error**: `CNAME not found for _acme-challenge.taxi-laguna.com`

**Solution**: Wait for DNS propagation (up to 48 hours, usually <1 hour)

```bash
# Check propagation
dig _acme-challenge.taxi-laguna.com CNAME +short
```

### Wrong Credentials

**Error**: `401 Unauthorized`

**Solution**: Double-check your GitHub Secrets match the registration response

### Can't Reach acme-dns

**Error**: `Connection refused to auth.acme-dns.io`

**Solution**: Check VPS firewall allows outbound HTTPS (port 443)

```bash
curl -I https://auth.acme-dns.io
```

## Self-Hosting ACME-DNS (Optional)

Instead of using the public `auth.acme-dns.io`, you can self-host:

### Docker Setup

```bash
docker run -d \
  --name acme-dns \
  -p 53:53/udp \
  -p 8053:8053 \
  -v /var/lib/acme-dns:/var/lib/acme-dns \
  joohoi/acme-dns:latest
```

### Register with Your Server

```bash
curl -X POST http://your-server:8053/register
```

### Update CNAME

```
_acme-challenge.taxi-laguna.com  CNAME  abc123.your-server.com
```

## Migration from FreeDNS Hook

If you're currently using `ensure-ssl-certificate` or `renew-ssl-freedns`:

### 1. Register with acme-dns
```bash
curl -X POST https://auth.acme-dns.io/register
```

### 2. Create CNAME on FreeDNS
```
_acme-challenge.taxi-laguna.com → [fulldomain from step 1]
```

### 3. Add Secrets to GitHub

### 4. Update Workflow
Replace `ensure-ssl-certificate` with `setup-ssl-acmedns`

### 5. Test
Run workflow - should complete in ~30 seconds vs 5-10 minutes!

## FAQ

**Q: Do I need to keep FreeDNS?**
A: Yes! You only delegate `_acme-challenge` subdomain. All other DNS stays on FreeDNS.

**Q: Is auth.acme-dns.io reliable?**
A: Yes, it's a public service maintained by the acme-dns project. 99.9%+ uptime.

**Q: Can I use multiple domains?**
A: Yes, register once per domain and create a CNAME for each.

**Q: What if auth.acme-dns.io goes down?**
A: Very rare, but you can self-host or use a different acme-dns instance.

**Q: Does this work for non-wildcard certs?**
A: Yes! Works for both wildcard and regular certificates.

**Q: Cost?**
A: Free for the public service. Self-hosting costs whatever your server costs.

## Resources

- **ACME-DNS GitHub**: https://github.com/joohoi/acme-dns
- **Public Service**: https://auth.acme-dns.io
- **Certbot Plugin**: https://github.com/joohoi/certbot-dns-acmedns
- **Let's Encrypt Docs**: https://letsencrypt.org/docs/challenge-types/

## Credits

- **acme-dns** by Joona Hoikkala (joohoi)
- **certbot-dns-acmedns** plugin
- Solves DNS propagation issues for slow DNS providers
