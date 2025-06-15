# Fider Tor Hidden Service Security Hardening Guide

This document outlines security measures implemented and additional hardening recommendations for running Fider as a Tor hidden service.

## Implemented Security Measures

### 1. Network Isolation
- **Docker Network Isolation**: All services run in an isolated Docker network
- **Tor Proxy Routing**: All outbound connections routed through Tor SOCKS proxy
- **No Direct Internet Access**: Application cannot make direct clearnet connections
- **Internal Service Communication**: Services communicate only within the Docker network

### 2. Container Security
- **Non-root Execution**: All containers run as non-root users
- **Read-only Filesystems**: Containers use read-only root filesystems where possible
- **Capability Dropping**: Unnecessary Linux capabilities are dropped
- **Security Options**: `no-new-privileges` and other security options enabled
- **Resource Limits**: Memory and CPU limits to prevent resource exhaustion

### 3. Tor Configuration Security
- **Hidden Service v3**: Uses latest Tor hidden service protocol (v3)
- **Client Isolation**: Different types of traffic are isolated
- **No Exit Relay**: Configured as client-only, no exit traffic
- **Safe Logging**: Sensitive information excluded from logs
- **Circuit Isolation**: Separate circuits for different connection types

### 4. Application Security
- **External Services Disabled**: OAuth providers and external APIs disabled
- **Local Storage Only**: Uses SQL blob storage instead of external S3
- **Secure Headers**: Security headers and CSP policies enabled
- **JWT Security**: Strong JWT secrets required
- **Database Encryption**: SSL/TLS required for database connections

### 5. Data Protection
- **Volume Encryption**: Consider encrypting Docker volumes
- **Secure Secrets**: Environment variables for sensitive data
- **Log Sanitization**: Sensitive data excluded from application logs
- **Backup Security**: Encrypted backups recommended

## Additional Hardening Recommendations

### 1. Host System Security

#### Operating System Hardening
```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install security updates automatically
sudo apt install unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades

# Configure firewall (UFW example)
sudo ufw default deny incoming
sudo ufw default deny outgoing
sudo ufw allow out 53/udp  # DNS
sudo ufw allow out 80/tcp  # HTTP
sudo ufw allow out 443/tcp # HTTPS
sudo ufw allow out 9001:9030/tcp # Tor directory authorities
sudo ufw enable
```

#### Disable Unnecessary Services
```bash
# Disable unnecessary services
sudo systemctl disable bluetooth
sudo systemctl disable cups
sudo systemctl disable avahi-daemon
sudo systemctl disable NetworkManager-wait-online
```

### 2. Docker Security

#### Docker Daemon Configuration
Create `/etc/docker/daemon.json`:
```json
{
  "live-restore": true,
  "userland-proxy": false,
  "no-new-privileges": true,
  "seccomp-profile": "/etc/docker/seccomp.json",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

#### Docker Compose Security
```yaml
# Add to docker-compose.tor.yml services
security_opt:
  - no-new-privileges:true
  - seccomp:unconfined  # Only if needed
cap_drop:
  - ALL
cap_add:
  - SETUID  # Only required capabilities
  - SETGID
```

### 3. Monitoring and Logging

#### Log Monitoring
```bash
# Monitor Tor logs
docker-compose -f docker-compose.tor.yml logs -f tor

# Monitor application logs
docker-compose -f docker-compose.tor.yml logs -f fider

# Check for suspicious activity
grep -i "warn\|error\|fail" /var/log/tor/tor.log
```

#### Health Monitoring
```bash
# Check service health
docker-compose -f docker-compose.tor.yml ps
docker stats

# Monitor resource usage
htop
iotop
```

### 4. Backup and Recovery

#### Secure Backup Script
```bash
#!/bin/bash
# backup-fider-tor.sh

BACKUP_DIR="/secure/backups"
DATE=$(date +%Y%m%d_%H%M%S)

# Stop services
docker-compose -f docker-compose.tor.yml stop

# Backup volumes
docker run --rm -v fider_postgres_data:/data -v $BACKUP_DIR:/backup \
  alpine tar czf /backup/postgres_$DATE.tar.gz -C /data .

docker run --rm -v fider_tor_data:/data -v $BACKUP_DIR:/backup \
  alpine tar czf /backup/tor_$DATE.tar.gz -C /data .

# Encrypt backups
gpg --cipher-algo AES256 --compress-algo 1 --s2k-mode 3 \
  --s2k-digest-algo SHA512 --s2k-count 65536 --symmetric \
  $BACKUP_DIR/postgres_$DATE.tar.gz

gpg --cipher-algo AES256 --compress-algo 1 --s2k-mode 3 \
  --s2k-digest-algo SHA512 --s2k-count 65536 --symmetric \
  $BACKUP_DIR/tor_$DATE.tar.gz

# Remove unencrypted backups
rm $BACKUP_DIR/postgres_$DATE.tar.gz
rm $BACKUP_DIR/tor_$DATE.tar.gz

# Start services
docker-compose -f docker-compose.tor.yml start
```

### 5. Operational Security

#### Regular Maintenance
- **Update Schedule**: Regular updates of all components
- **Security Patches**: Monitor and apply security patches promptly
- **Log Review**: Regular review of logs for suspicious activity
- **Backup Testing**: Regular testing of backup and recovery procedures

#### Access Control
- **SSH Keys**: Use SSH keys instead of passwords
- **Multi-factor Authentication**: Enable MFA where possible
- **Principle of Least Privilege**: Minimal necessary permissions
- **Regular Audits**: Regular review of access permissions

#### Incident Response
- **Monitoring Alerts**: Set up alerts for suspicious activity
- **Response Plan**: Have a documented incident response plan
- **Forensics**: Preserve logs and evidence if compromise suspected
- **Recovery Procedures**: Documented recovery procedures

### 6. Advanced Security Measures

#### AppArmor/SELinux Profiles
Consider creating custom security profiles for additional containment.

#### Network Segmentation
```bash
# Create additional isolated networks
docker network create --driver bridge --internal tor-internal
docker network create --driver bridge --internal db-internal
```

#### Secrets Management
```bash
# Use Docker secrets for sensitive data
echo "your-jwt-secret" | docker secret create jwt_secret -
echo "your-db-password" | docker secret create db_password -
```

#### Resource Monitoring
```bash
# Set up resource monitoring
docker stats --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"
```

## Security Checklist

- [ ] Host system fully updated and hardened
- [ ] Firewall configured to block unnecessary traffic
- [ ] Docker daemon secured with appropriate configuration
- [ ] All containers running as non-root users
- [ ] Tor configuration reviewed and hardened
- [ ] External services disabled or properly configured
- [ ] Strong secrets generated and properly stored
- [ ] Logging configured and monitored
- [ ] Backup procedures implemented and tested
- [ ] Incident response plan documented
- [ ] Regular security updates scheduled

## Warning Signs to Monitor

- Unusual network traffic patterns
- High CPU or memory usage
- Failed authentication attempts
- Tor circuit build failures
- Database connection errors
- Unexpected service restarts
- Disk space issues
- Log file anomalies

## Emergency Procedures

### Service Compromise
1. Immediately stop all services
2. Preserve logs and evidence
3. Assess scope of compromise
4. Restore from clean backups
5. Regenerate all secrets
6. Review and update security measures

### Data Breach
1. Stop services to prevent further access
2. Assess what data may have been accessed
3. Notify relevant parties if required
4. Implement additional security measures
5. Monitor for misuse of compromised data

Remember: Security is an ongoing process, not a one-time setup. Regular review and updates of these measures are essential for maintaining a secure Tor hidden service.
