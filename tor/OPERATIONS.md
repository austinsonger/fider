# Fider Tor Hidden Service Operations Guide

This guide covers day-to-day operations, maintenance, and troubleshooting for your Fider Tor hidden service deployment.

## 🚀 Daily Operations

### Starting the Service

```bash
# Start all services
docker-compose -f docker-compose.tor.yml --env-file .env.tor up -d

# Start with monitoring (optional)
docker-compose -f docker-compose.tor.yml -f tor/monitoring.yml --env-file .env.tor up -d --profile monitoring

# Check service status
docker-compose -f docker-compose.tor.yml ps
```

### Stopping the Service

```bash
# Stop all services
docker-compose -f docker-compose.tor.yml down

# Stop and remove volumes (CAUTION: This deletes all data!)
docker-compose -f docker-compose.tor.yml down -v
```

### Getting Your Onion Address

```bash
# Get the onion address
docker exec fider_tor cat /var/lib/tor/fider_hidden_service/hostname

# Or use the setup script
./tor/setup-tor-deployment.sh address
```

## 📊 Monitoring and Health Checks

### Service Health

```bash
# Check all services
docker-compose -f docker-compose.tor.yml ps

# Check specific service health
docker inspect fider_tor --format='{{.State.Health.Status}}'
docker inspect fider_app_tor --format='{{.State.Health.Status}}'
docker inspect fider_postgres_tor --format='{{.State.Health.Status}}'

# Manual health check
docker exec fider_app_tor ./fider ping
```

### Log Monitoring

```bash
# View all logs
docker-compose -f docker-compose.tor.yml logs -f

# View specific service logs
docker-compose -f docker-compose.tor.yml logs -f tor
docker-compose -f docker-compose.tor.yml logs -f fider
docker-compose -f docker-compose.tor.yml logs -f postgres

# View recent logs only
docker-compose -f docker-compose.tor.yml logs --tail=100 fider

# Search logs for errors
docker-compose -f docker-compose.tor.yml logs fider | grep -i error
```

### Resource Monitoring

```bash
# Container resource usage
docker stats

# System resource usage
htop
df -h
free -h

# Docker system usage
docker system df
```

## 🔧 Maintenance Tasks

### Regular Updates

```bash
# Update Docker images
docker-compose -f docker-compose.tor.yml pull

# Rebuild custom images
docker build -t fider-tor:latest ./tor/
docker build -f Dockerfile.tor -t fider-app-tor:latest .

# Restart with new images
docker-compose -f docker-compose.tor.yml down
docker-compose -f docker-compose.tor.yml up -d
```

### Database Maintenance

```bash
# Connect to database
docker-compose -f docker-compose.tor.yml exec postgres psql -U fider -d fider

# Database backup
docker-compose -f docker-compose.tor.yml exec postgres pg_dump -U fider fider > backup.sql

# Database vacuum (maintenance)
docker-compose -f docker-compose.tor.yml exec postgres psql -U fider -d fider -c "VACUUM ANALYZE;"

# Check database size
docker-compose -f docker-compose.tor.yml exec postgres psql -U fider -d fider -c "SELECT pg_size_pretty(pg_database_size('fider'));"
```

### Log Rotation

```bash
# Configure Docker log rotation (add to /etc/docker/daemon.json)
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}

# Restart Docker daemon after configuration change
sudo systemctl restart docker
```

### Cleanup

```bash
# Remove unused Docker resources
docker system prune -f

# Remove unused images
docker image prune -f

# Remove unused volumes (CAUTION!)
docker volume prune -f
```

## 🔄 Backup and Recovery

### Automated Backup Script

Create `/usr/local/bin/backup-fider-tor.sh`:

```bash
#!/bin/bash
set -e

BACKUP_DIR="/opt/backups/fider-tor"
DATE=$(date +%Y%m%d_%H%M%S)
COMPOSE_FILE="/opt/fider/docker-compose.tor.yml"

mkdir -p "$BACKUP_DIR"

# Stop services
docker-compose -f "$COMPOSE_FILE" stop

# Backup PostgreSQL
docker run --rm \
  -v fider_postgres_data:/data \
  -v "$BACKUP_DIR":/backup \
  alpine tar czf "/backup/postgres_$DATE.tar.gz" -C /data .

# Backup Tor data (includes private keys)
docker run --rm \
  -v fider_tor_data:/data \
  -v "$BACKUP_DIR":/backup \
  alpine tar czf "/backup/tor_$DATE.tar.gz" -C /data .

# Backup application data
docker run --rm \
  -v fider_fider_data:/data \
  -v "$BACKUP_DIR":/backup \
  alpine tar czf "/backup/fider_$DATE.tar.gz" -C /data .

# Start services
docker-compose -f "$COMPOSE_FILE" start

# Cleanup old backups (keep 7 days)
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +7 -delete

echo "Backup completed: $DATE"
```

### Schedule Backups

```bash
# Add to crontab
crontab -e

# Add this line for daily backups at 2 AM
0 2 * * * /usr/local/bin/backup-fider-tor.sh >> /var/log/fider-backup.log 2>&1
```

### Recovery Process

```bash
# Stop services
docker-compose -f docker-compose.tor.yml down

# Remove old volumes
docker volume rm fider_postgres_data fider_tor_data fider_fider_data

# Restore from backup
docker run --rm \
  -v fider_postgres_data:/data \
  -v /opt/backups/fider-tor:/backup \
  alpine tar xzf /backup/postgres_YYYYMMDD_HHMMSS.tar.gz -C /data

docker run --rm \
  -v fider_tor_data:/data \
  -v /opt/backups/fider-tor:/backup \
  alpine tar xzf /backup/tor_YYYYMMDD_HHMMSS.tar.gz -C /data

docker run --rm \
  -v fider_fider_data:/data \
  -v /opt/backups/fider-tor:/backup \
  alpine tar xzf /backup/fider_YYYYMMDD_HHMMSS.tar.gz -C /data

# Start services
docker-compose -f docker-compose.tor.yml up -d
```

## 🐛 Troubleshooting

### Common Issues

#### Service Won't Start

```bash
# Check Docker daemon
sudo systemctl status docker

# Check system resources
df -h
free -h

# Check for port conflicts
sudo netstat -tulpn | grep :3000
sudo netstat -tulpn | grep :9050

# Check Docker logs
docker-compose -f docker-compose.tor.yml logs
```

#### Can't Access Hidden Service

```bash
# Verify Tor is working
docker exec fider_tor curl --socks5 127.0.0.1:9050 http://3g2upl4pq6kufc4m.onion

# Check onion address
docker exec fider_tor cat /var/lib/tor/fider_hidden_service/hostname

# Test Fider directly
docker exec fider_app_tor ./fider ping

# Check Tor logs for errors
docker-compose -f docker-compose.tor.yml logs tor | grep -i error
```

#### Database Connection Issues

```bash
# Test database connection
docker-compose -f docker-compose.tor.yml exec postgres pg_isready -U fider

# Check database logs
docker-compose -f docker-compose.tor.yml logs postgres

# Connect to database manually
docker-compose -f docker-compose.tor.yml exec postgres psql -U fider -d fider
```

#### High Resource Usage

```bash
# Check container resource usage
docker stats --no-stream

# Check system load
uptime
iostat 1 5

# Check for memory leaks
docker-compose -f docker-compose.tor.yml exec fider ps aux
```

### Performance Optimization

#### Database Optimization

```sql
-- Connect to database and run these queries
-- docker-compose -f docker-compose.tor.yml exec postgres psql -U fider -d fider

-- Check database statistics
SELECT schemaname, tablename, n_tup_ins, n_tup_upd, n_tup_del 
FROM pg_stat_user_tables;

-- Analyze query performance
SELECT query, calls, total_time, mean_time 
FROM pg_stat_statements 
ORDER BY total_time DESC LIMIT 10;

-- Update table statistics
ANALYZE;
```

#### Tor Optimization

```bash
# Check Tor circuit status
docker exec fider_tor cat /var/log/tor/tor.log | grep -i circuit

# Monitor Tor bandwidth
docker exec fider_tor cat /var/log/tor/tor.log | grep -i bandwidth
```

## 🔐 Security Operations

### Security Monitoring

```bash
# Check for failed authentication attempts
docker-compose -f docker-compose.tor.yml logs fider | grep -i "auth\|login\|fail"

# Monitor unusual network activity
docker exec fider_tor netstat -an | grep :9050

# Check for suspicious processes
docker-compose -f docker-compose.tor.yml exec fider ps aux
```

### Security Updates

```bash
# Update base images
docker pull debian:bookworm-slim
docker pull postgres:15-alpine
docker pull alpine:3.18

# Rebuild images with updates
docker build --no-cache -t fider-tor:latest ./tor/
docker build --no-cache -f Dockerfile.tor -t fider-app-tor:latest .

# Update and restart services
docker-compose -f docker-compose.tor.yml down
docker-compose -f docker-compose.tor.yml up -d
```

### Incident Response

#### Suspected Compromise

1. **Immediate Actions**
   ```bash
   # Stop all services
   docker-compose -f docker-compose.tor.yml down
   
   # Preserve logs
   docker-compose -f docker-compose.tor.yml logs > incident-logs-$(date +%Y%m%d_%H%M%S).txt
   ```

2. **Investigation**
   ```bash
   # Check system logs
   sudo journalctl -u docker --since "1 hour ago"
   
   # Check for unauthorized access
   sudo last
   sudo lastlog
   ```

3. **Recovery**
   ```bash
   # Restore from clean backup
   # (Follow recovery process above)
   
   # Regenerate secrets
   # (Update .env.tor with new JWT_SECRET and POSTGRES_PASSWORD)
   ```

## 📈 Performance Monitoring

### Key Metrics to Monitor

- **Service Availability**: All services up and responding
- **Response Time**: Application response time < 2 seconds
- **Resource Usage**: CPU < 80%, Memory < 85%, Disk < 90%
- **Database Performance**: Query time, connection count
- **Tor Circuit Health**: Circuit build success rate
- **Network Traffic**: Unusual traffic patterns

### Alerting Setup

If using the monitoring stack:

```bash
# Start with monitoring
docker-compose -f docker-compose.tor.yml -f tor/monitoring.yml --env-file .env.tor up -d --profile monitoring

# Access Grafana (localhost only)
# http://localhost:3001
# Default: admin/admin

# Access Prometheus (localhost only)
# http://localhost:9090

# Access Alertmanager (localhost only)
# http://localhost:9093
```

## 📞 Emergency Contacts

Document your emergency procedures:

- **System Administrator**: [Contact Info]
- **Security Team**: [Contact Info]
- **Backup Administrator**: [Contact Info]
- **Escalation Procedures**: [Document procedures]

## 📝 Change Log

Keep a record of all changes:

```
YYYY-MM-DD: [Change description] - [Person responsible]
```

This helps with troubleshooting and compliance.
