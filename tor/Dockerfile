FROM alpine:3.18

# Install Tor and required packages
RUN apk add --no-cache \
    tor \
    curl \
    tini \
    && adduser -D -s /bin/sh tor

# Create necessary directories
RUN mkdir -p /var/lib/tor /var/log/tor /var/run/tor \
    && chown -R tor:tor /var/lib/tor /var/log/tor /var/run/tor \
    && chmod 700 /var/lib/tor \
    && chmod 755 /var/log/tor /var/run/tor

# Copy Tor configuration
COPY torrc /etc/tor/torrc
RUN chown tor:tor /etc/tor/torrc && chmod 644 /etc/tor/torrc

# Create entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Switch to tor user
USER tor

# Expose SOCKS and control ports
EXPOSE 9050 9051

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl --socks5 127.0.0.1:9050 --connect-timeout 10 http://3g2upl4pq6kufc4m.onion || exit 1

# Use tini as init system
ENTRYPOINT ["/sbin/tini", "--", "/entrypoint.sh"]
CMD ["tor", "-f", "/etc/tor/torrc"]
