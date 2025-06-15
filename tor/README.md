# Fider Tor Hidden Service Deployment

This directory contains everything needed to deploy Fider as a secure Tor hidden service (.onion site). The setup provides complete anonymity and privacy by routing all traffic through the Tor network.

## 🔒 Security Features

- **Complete Network Isolation**: All traffic routed through Tor
- **DNS Leak Prevention**: No direct DNS queries to clearnet
- **Container Security**: Hardened Docker containers with minimal privileges
- **External Service Blocking**: OAuth and external APIs disabled
- **Secure Configuration**: Tor v3 hidden services with security hardening
- **Local Storage**: No external cloud dependencies

## 📋 Prerequisites

- Docker and Docker Compose installed
- At least 2GB RAM and 10GB disk space
- Linux host system (recommended: Ubuntu 20.04+ or Debian 11+)
- Basic understanding of Tor and hidden services

## 🚀 Quick Start

### 1. Automated Setup (Recommended)

```bash
# Make setup script executable
chmod +x tor/setup-tor-deployment.sh

# Run complete setup
./tor/setup-tor-deployment.sh setup
```

This will:
- Check prerequisites
- Generate secure configuration
- Build Docker images
- Start all services
- Display your .onion address

### 2. Manual Setup

If you prefer manual setup or need customization:

```bash
# 1. Copy and customize environment file
cp .env.tor.example .env.tor
# Edit .env.tor with your preferred settings

# 2. Build Docker images
docker build -t fider-tor:latest ./tor/
docker build -f Dockerfile.tor -t fider-app-tor:latest .

# 3. Start services
docker-compose -f docker-compose.tor.yml --env-file .env.tor up -d

# 4. Get your onion address
docker exec fider_tor cat /var/lib/tor/fider_hidden_service/hostname
```

## 🔧 Configuration

### Environment Variables

Key configuration options in `.env.tor`:

```bash
# Your onion address (auto-generated)
BASE_URL=http://your-address.onion

# Security (CHANGE THESE!)
JWT_SECRET=your-strong-jwt-secret
POSTGRES_PASSWORD=your-strong-db-password

# Tor proxy settings
HTTP_PROXY=socks5://tor:9050
HTTPS_PROXY=socks5://tor:9050

# Security hardening
OAUTH_GOOGLE_CLIENTID=    # Disabled
OAUTH_FACEBOOK_APPID=     # Disabled
OAUTH_GITHUB_CLIENTID=    # Disabled
EMAIL_TYPE=disabled       # No external email
BLOB_STORAGE=sql         # Local storage only
```

### Service Configuration

The deployment includes:

- **Tor Proxy**: SOCKS5 proxy on port 9050
- **Fider App**: Main application on port 3000
- **PostgreSQL**: Database with SSL required
- **Optional MailHog**: Local SMTP for testing

## 🛠️ Management Commands

### Using Setup Script

```bash
# Show service status
./tor/setup-tor-deployment.sh status

# Get onion address
./tor/setup-tor-deployment.sh address

# Stop services
./tor/setup-tor-deployment.sh stop

# Rebuild images
./tor/setup-tor-deployment.sh build
```

### Using Docker Compose

```bash
# View logs
docker-compose -f docker-compose.tor.yml logs -f

# Restart services
docker-compose -f docker-compose.tor.yml restart

# Update configuration
docker-compose -f docker-compose.tor.yml down
# Edit .env.tor
docker-compose -f docker-compose.tor.yml up -d

# Scale services (if needed)
docker-compose -f docker-compose.tor.yml up -d --scale fider=2
```

## 📊 Monitoring

### Health Checks

All services include health checks:

```bash
# Check service health
docker-compose -f docker-compose.tor.yml ps

# View health check logs
docker inspect fider_tor --format='{{.State.Health.Status}}'
```

### Log Monitoring

```bash
# Application logs
docker-compose -f docker-compose.tor.yml logs -f fider

# Tor logs
docker-compose -f docker-compose.tor.yml logs -f tor

# Database logs
docker-compose -f docker-compose.tor.yml logs -f postgres

# All logs
docker-compose -f docker-compose.tor.yml logs -f
```

### Resource Usage

```bash
# Container resource usage
docker stats

# Disk usage
docker system df
```

## 🔐 Security Considerations

### Network Security
- All outbound connections go through Tor
- No direct internet access from containers
- Internal network isolation between services
- Firewall rules to block clearnet access

### Application Security
- External OAuth providers disabled
- No external API calls that could leak information
- Local blob storage only (no S3/cloud storage)
- Strong JWT secrets required
- Database connections use SSL

### Container Security
- Non-root users in all containers
- Read-only filesystems where possible
- Minimal Linux capabilities
- Security options enabled (`no-new-privileges`)

### Operational Security
- Regular security updates required
- Log monitoring for suspicious activity
- Secure backup procedures
- Incident response planning

See [security-hardening.md](security-hardening.md) for detailed security measures.

## 🔄 Backup and Recovery

### Backup

```bash
# Stop services
docker-compose -f docker-compose.tor.yml stop

# Backup data volumes
docker run --rm -v fider_postgres_data:/data -v $(pwd)/backups:/backup \
  alpine tar czf /backup/postgres-$(date +%Y%m%d).tar.gz -C /data .

docker run --rm -v fider_tor_data:/data -v $(pwd)/backups:/backup \
  alpine tar czf /backup/tor-$(date +%Y%m%d).tar.gz -C /data .

# Start services
docker-compose -f docker-compose.tor.yml start
```

### Recovery

```bash
# Stop services
docker-compose -f docker-compose.tor.yml down

# Remove old volumes
docker volume rm fider_postgres_data fider_tor_data

# Restore from backup
docker run --rm -v fider_postgres_data:/data -v $(pwd)/backups:/backup \
  alpine tar xzf /backup/postgres-YYYYMMDD.tar.gz -C /data

docker run --rm -v fider_tor_data:/data -v $(pwd)/backups:/backup \
  alpine tar xzf /backup/tor-YYYYMMDD.tar.gz -C /data

# Start services
docker-compose -f docker-compose.tor.yml up -d
```

## 🐛 Troubleshooting

### Common Issues

#### Services Won't Start
```bash
# Check logs for errors
docker-compose -f docker-compose.tor.yml logs

# Check system resources
docker system df
free -h
df -h
```

#### Can't Access Onion Site
```bash
# Verify Tor is running
docker exec fider_tor curl --socks5 127.0.0.1:9050 http://3g2upl4pq6kufc4m.onion

# Check onion address
docker exec fider_tor cat /var/lib/tor/fider_hidden_service/hostname

# Verify Fider is responding
docker exec fider_app_tor ./fider ping
```

#### Database Connection Issues
```bash
# Check database status
docker-compose -f docker-compose.tor.yml exec postgres pg_isready -U fider

# Check database logs
docker-compose -f docker-compose.tor.yml logs postgres

# Test connection
docker-compose -f docker-compose.tor.yml exec fider ./fider ping
```

### Performance Issues

#### High Memory Usage
```bash
# Check container memory usage
docker stats --no-stream

# Adjust memory limits in docker-compose.tor.yml
```

#### Slow Response Times
```bash
# Check Tor circuit status
docker exec fider_tor cat /var/log/tor/tor.log | grep -i circuit

# Monitor database performance
docker-compose -f docker-compose.tor.yml exec postgres \
  psql -U fider -c "SELECT * FROM pg_stat_activity;"
```

## 📚 Additional Resources

- [Tor Hidden Service Documentation](https://community.torproject.org/onion-services/)
- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [Fider Documentation](https://github.com/getfider/fider)
- [PostgreSQL Security](https://www.postgresql.org/docs/current/security.html)

## ⚠️ Important Notes

1. **First Run**: Your .onion address is generated on first startup and should be kept secure
2. **Backup Keys**: Always backup your Tor private keys (`/var/lib/tor/fider_hidden_service/`)
3. **Security Updates**: Regularly update all components for security patches
4. **Monitoring**: Monitor logs for suspicious activity or errors
5. **Testing**: Test backup and recovery procedures regularly

## 🆘 Support

If you encounter issues:

1. Check the troubleshooting section above
2. Review logs for error messages
3. Ensure all prerequisites are met
4. Verify network connectivity and firewall settings
5. Check Docker and system resources

For additional help, consult the Fider community or Tor Project documentation.
