# Build from the monorepo root: docker build -f apps/mcp/Dockerfile .
FROM julia:1.12.3-bookworm
WORKDIR /app
ENV JULIA_DEPOT_PATH=/opt/julia-depot
RUN apt-get update && apt-get install -y --no-install-recommends openssh-client \
    && rm -rf /var/lib/apt/lists/*
COPY Project.toml ./
COPY src ./src
COPY templates ./templates
COPY apps/mcp ./apps/mcp
COPY apps/shared ./apps/shared
RUN julia --project=apps/mcp --startup-file=no -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'
RUN useradd --create-home --uid 10001 mcp \
    && chown -R mcp:mcp /app /opt/julia-depot
USER mcp
EXPOSE 8080
CMD ["julia", "--project=/app/apps/mcp", "--startup-file=no", "/app/apps/mcp/bin/pkgfactory-mcp.jl", "--transport", "http", "--host", "0.0.0.0"]
