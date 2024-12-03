# Docker Swarm Multi-Node Setup Guide

## Prerequisites
- Multiple Linux servers/VMs (Proxmox or other)
- Docker installed on all nodes
- Open ports: 2377/tcp (swarm management), 7946/tcp/udp (container networking), 4789/udp (overlay networking)

## Architecture Overview
![Docker Swarm Architecture](https://docs.docker.com/engine/swarm/images/swarm-diagram.png)

## 1. Initialize Swarm

### Manager Node Setup
```bash
# Initialize swarm on first manager node
docker swarm init --advertise-addr <MANAGER-IP>

# Save the join token for workers
docker swarm join-token worker
```

### Worker Node Setup
```bash
# Run on each worker node
docker swarm join --token <WORKER-TOKEN> <MANAGER-IP>:2377
```

## 2. Deploy External Secrets Operator

Create `external-secrets.yml`:
```yaml
version: '3.8'
services:
  external-secrets:
    image: ghcr.io/external-secrets/external-secrets:v0.9.11
    deploy:
      mode: global
      placement:
        constraints:
          - node.role == manager
    environment:
      - KUBERNETES_CLUSTER_DOMAIN=cluster.local
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
```

Deploy:
```bash
docker stack deploy -c external-secrets.yml secrets
```

## 3. Deploy Traefik

Create `traefik.yml`:
```yaml
version: '3.8'
services:
  traefik:
    image: traefik:v2.10
    command:
      - "--api.dashboard=true"
      - "--providers.docker.swarm=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--certificatesresolvers.letsencrypt.acme.email=your@email.com"
      - "--certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json"
      - "--certificatesresolvers.letsencrypt.acme.httpchallenge.entrypoint=web"
    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - traefik-certificates:/letsencrypt
    deploy:
      placement:
        constraints:
          - node.role == manager
      labels:
        - "traefik.enable=true"
        - "traefik.http.routers.dashboard.rule=Host(`traefik.yourdomain.com`)"
        - "traefik.http.routers.dashboard.service=api@internal"
        - "traefik.http.routers.dashboard.middlewares=auth"
        - "traefik.http.middlewares.auth.basicauth.users=admin:$$apr1$$xyz123"

volumes:
  traefik-certificates:
```

Deploy:
```bash
docker stack deploy -c traefik.yml proxy
```

## 4. Verify Setup

```bash
# Check node status
docker node ls

# Check service status
docker service ls

# View logs
docker service logs proxy_traefik
```

## Useful Resources
- [Docker Swarm Documentation](https://docs.docker.com/engine/swarm/)
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [External Secrets Operator](https://external-secrets.io/latest/)

## Next Steps
1. Configure DNS records for your services
2. Set up monitoring (Prometheus/Grafana recommended)
3. Implement backup strategy
4. Deploy your first service