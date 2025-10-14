# Deploy Next.js App

A composite GitHub Action for building and deploying Next.js applications to VPS using Docker with zero-downtime deployments.

## Features

- Multi-stage Docker build optimized for Next.js standalone output
- Support for npm, yarn, and pnpm package managers
- Build-time environment variables via build args
- Automatic health checks after deployment
- Zero-downtime deployments with container replacement
- Microservices network integration
- Automatic cleanup of old images
- Security best practices (non-root user, minimal Alpine image)

## Prerequisites

- VPS with Docker installed (use `affpro/vps-deploybot/setup-vps-docker`)
- Next.js app configured for standalone output (see below)
- SSH access to VPS with private key

## Next.js Configuration

**IMPORTANT:** Your Next.js app must be configured for standalone output. Add this to your `next.config.js` or `next.config.mjs`:

```javascript
/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone',
  // ... other config
}

module.exports = nextConfig
```

This enables Next.js to create a minimal production server that includes only the necessary files.

## Usage

### Basic Example

```yaml
- name: Deploy Next.js App
  uses: affpro/vps-deploybot/deploy-nextjs-app@main
  with:
    host: ${{ secrets.VPS_HOST }}
    user: ${{ secrets.VPS_USER }}
    ssh_key: ${{ secrets.VPS_SSH_KEY }}
    service_name: my-nextjs-app
    container_name: nextjs_app
    container_port: 3000
    image_name: my-nextjs-app
    app_directory: ./my-nextjs-app
```

### With Build Arguments

```yaml
- name: Deploy Next.js App with Environment Variables
  uses: affpro/vps-deploybot/deploy-nextjs-app@main
  with:
    host: ${{ secrets.VPS_HOST }}
    user: ${{ secrets.VPS_USER }}
    ssh_key: ${{ secrets.VPS_SSH_KEY }}
    service_name: my-nextjs-app
    container_name: nextjs_app
    container_port: 3000
    image_name: my-nextjs-app
    app_directory: ./my-nextjs-app
    build_args: |
      NEXT_PUBLIC_API_URL=${{ secrets.API_URL }}
      NEXT_PUBLIC_APP_ENV=production
      DATABASE_URL=${{ secrets.DATABASE_URL }}
```

### Complete Deployment Workflow

```yaml
name: Deploy Next.js to VPS

on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Deploy Next.js Application
        uses: affpro/vps-deploybot/deploy-nextjs-app@main
        with:
          host: ${{ secrets.VPS_HOST }}
          user: ${{ secrets.VPS_USER }}
          ssh_key: ${{ secrets.VPS_SSH_KEY }}
          service_name: nextjs-app
          container_name: nextjs_app_container
          container_port: 3000
          image_name: nextjs-app
          app_directory: .
          node_version: 22
          docker_network: microservices
          health_check_enabled: true
          health_check_timeout: 60
          build_args: |
            NEXT_PUBLIC_API_URL=${{ secrets.API_URL }}
            DATABASE_URL=${{ secrets.DATABASE_URL }}

      - name: Configure Nginx Reverse Proxy
        uses: affpro/vps-deploybot/configure-nginx-service@main
        with:
          host: ${{ secrets.VPS_HOST }}
          user: ${{ secrets.VPS_USER }}
          ssh_key: ${{ secrets.VPS_SSH_KEY }}
          service_name: nextjs-app
          container_name: nextjs_app_container
          container_port: 3000
          routing_type: subdomain
          server_name: app.example.com
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `host` | VPS hostname or IP address | Yes | - |
| `user` | SSH username | Yes | - |
| `ssh_key` | SSH private key content | Yes | - |
| `port` | SSH port | No | `22` |
| `service_name` | Service name (used for identification) | Yes | - |
| `container_name` | Docker container name | Yes | - |
| `container_port` | Internal port for the Next.js app | Yes | - |
| `image_name` | Docker image name | Yes | - |
| `app_directory` | Directory containing Next.js app | Yes | - |
| `build_command` | Build command | No | `npm run build` |
| `start_command` | Start command (not used in standalone mode) | No | `npm start` |
| `node_version` | Node.js version | No | `22` |
| `build_args` | Docker build arguments (multiline) | No | - |
| `docker_network` | Docker network to use | No | `microservices` |
| `health_check_enabled` | Enable health check | No | `true` |
| `health_check_timeout` | Health check timeout (seconds) | No | `60` |

## How It Works

1. **SSH Setup**: Establishes SSH connection to VPS
2. **Docker Build**: Creates optimized multi-stage Docker image:
   - **deps stage**: Installs dependencies
   - **builder stage**: Builds Next.js app
   - **runner stage**: Production image with standalone output
3. **Image Transfer**: Saves and transfers Docker image to VPS
4. **Deployment**:
   - Loads image on VPS
   - Stops old container if exists
   - Starts new container with zero downtime
   - Connects to microservices network
5. **Health Check**: Verifies app is responding (optional)
6. **Cleanup**: Removes old images and temporary files

## Multi-Stage Docker Build

The action creates an optimized Dockerfile with three stages:

1. **Dependencies Stage**: Installs production dependencies
2. **Builder Stage**: Builds the Next.js application
3. **Runner Stage**: Minimal production image with:
   - Alpine Linux (small footprint)
   - Non-root user (security)
   - Only standalone output (no source code)
   - Pre-configured environment variables

## Environment Variables

Build arguments are passed as Docker build args and converted to environment variables. This allows you to use them in:

- Next.js public runtime config (`NEXT_PUBLIC_*` variables)
- Server-side code (all variables)
- Build-time configuration

**Note**: Public environment variables must be prefixed with `NEXT_PUBLIC_` to be accessible in the browser.

## Security Considerations

- Container runs as non-root user (`nextjs:nodejs`)
- Only binds to localhost (`127.0.0.1`) - use nginx for public access
- Minimal Alpine image reduces attack surface
- No source code in production image (only compiled output)
- Restart policy: `unless-stopped`

## Troubleshooting

### Build Failures

If the build fails, check:
1. Next.js config has `output: 'standalone'`
2. All required dependencies are in `package.json`
3. Build args are correctly formatted (one per line)

### Container Exits Immediately

Check container logs:
```bash
sudo docker logs <container_name>
```

Common issues:
- Port already in use
- Missing environment variables
- Next.js build errors

### Health Check Fails

The health check attempts to reach `http://127.0.0.1:<port>/`. Ensure:
1. Container is actually running (`docker ps`)
2. Port is correctly configured
3. Next.js app is listening on the specified port

## Next Steps

After deployment:

1. **Configure Nginx** (required for public access):
   ```yaml
   - uses: affpro/vps-deploybot/configure-nginx-service@main
   ```

2. **Set up SSL** (recommended for production):
   ```yaml
   - uses: affpro/vps-deploybot/setup-ssl-certificates@main
   ```

3. **Configure UFW firewall**:
   ```yaml
   - uses: affpro/vps-deploybot/setup-vps-firewall@main
   ```

## Related Actions

- [setup-vps-docker](../setup-vps-docker) - Install Docker on VPS
- [configure-nginx-service](../configure-nginx-service) - Set up nginx reverse proxy
- [setup-ssl-certificates](../setup-ssl-certificates) - Configure SSL/TLS
- [setup-vps-firewall](../setup-vps-firewall) - Configure UFW firewall

## Example Project Structure

```
my-nextjs-app/
├── app/                    # Next.js app directory
├── public/                 # Static assets
├── next.config.js          # Next.js config (with output: 'standalone')
├── package.json
├── package-lock.json       # or yarn.lock / pnpm-lock.yaml
└── ...
```

## Performance Tips

1. Use `.dockerignore` to exclude unnecessary files
2. Enable Next.js image optimization if needed
3. Consider adding a CDN for static assets
4. Use environment variables for API URLs to avoid rebuilds

## Limitations

- Requires Next.js 12.2+ for standalone output
- Does not support custom server.js (uses Next.js built-in server)
- Static exports (`output: 'export'`) are not supported (use `deploy-vite-app` instead)
