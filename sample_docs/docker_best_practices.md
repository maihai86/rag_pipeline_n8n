# Docker Best Practices for AI Applications

## Container Design

### Keep Images Small
- Use multi-stage builds to separate build and runtime dependencies
- Use slim or alpine base images when possible
- Remove package manager caches after installation

### One Process Per Container
Each container should run a single process:
- n8n in one container
- PostgreSQL in another
- Qdrant in its own container

This allows independent scaling and easier debugging.

## Docker Compose for Development

### Service Dependencies
Use `depends_on` with health checks to manage startup order:

```yaml
services:
  n8n:
    depends_on:
      postgres:
        condition: service_healthy
      qdrant:
        condition: service_started
```

Note: Not all images support health checks. Qdrant's minimal Rust binary has no shell tools (wget, curl), so `service_started` is used instead of `service_healthy`.

### Volume Management
- Use named volumes for persistent data (databases, vector stores)
- Use bind mounts for development files that change frequently
- Mark read-only mounts with `:ro` when the container doesn't need write access

```yaml
volumes:
  - n8n_data:/home/node/.n8n          # Named volume (persistent)
  - ./sample_docs:/data/sample_docs:ro # Bind mount (read-only)
```

### Environment Variables
- Store secrets in `.env` files (never commit to git)
- Use `.env.example` as a template with placeholder values
- Reference variables with `${VARIABLE:-default}` syntax

## Networking

### Internal Communication
Services within the same Docker Compose network communicate using service names as hostnames:
- n8n connects to PostgreSQL at `postgres:5432`
- n8n connects to Qdrant at `qdrant:6333`

### External Access
Only expose ports that need external access:
- n8n: Port 5678 (workflow UI and webhooks)
- Qdrant: Port 6333 (for debugging/dashboard access)

## Production Considerations

1. **Resource limits**: Set CPU and memory limits per container
2. **Restart policies**: Use `restart: unless-stopped` for auto-recovery
3. **Logging**: Configure log drivers and rotation
4. **Secrets management**: Use Docker secrets or external vault instead of env vars
5. **Health checks**: Define health checks for all critical services
6. **Backup strategy**: Regular backups of named volumes (database, vector store)
