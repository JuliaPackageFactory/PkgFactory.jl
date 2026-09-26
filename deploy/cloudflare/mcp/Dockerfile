FROM julia:1.12.3-bookworm
WORKDIR /app
ENV JULIA_DEPOT_PATH=/opt/julia-depot JULIA_NUM_THREADS=1 JULIA_CPU_TARGET=generic
COPY Project.toml ./
COPY src ./src
COPY templates ./templates
COPY apps/shared ./apps/shared
COPY apps/mcp ./apps/mcp
RUN julia --project=apps/mcp --startup-file=no -e 'using Pkg; Pkg.instantiate(); using PkgFactoryMCP; PkgFactoryMCP.build_server()'
RUN useradd --create-home --uid 10001 pkgfactory && chown -R pkgfactory:pkgfactory /app /opt/julia-depot
USER pkgfactory
EXPOSE 8080
CMD ["julia", "--compile=min", "--heap-size-hint=600M", "--project=/app/apps/mcp", "--startup-file=no", "/app/apps/mcp/bin/cloudflare-server.jl"]
