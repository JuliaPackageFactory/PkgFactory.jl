using PkgFactory
using Documenter
using DocumenterMermaid

DocMeta.setdocmeta!(PkgFactory, :DocTestSetup, :(using PkgFactory); recursive = true)

makedocs(;
    checkdocs = :public,
    modules = [PkgFactory],
    authors = "Shuhei Ohno",
    sitename = "PkgFactory.jl",
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical = "https://juliapackagefactory.github.io/PkgFactory.jl",
        edit_link = "main",
        assets = [
            "assets/logo.ico",
            "assets/custom.css",
            # Mermaid 11.17 fails with Documenter's RequireJS loader.
            # Pin the module imported by DocumenterMermaid until this is resolved:
            # https://github.com/mermaid-js/mermaid/issues/8095
            RawHTMLHeadContent("""
            <script type="importmap">
            {"imports": {
                "https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs":
                "https://cdn.jsdelivr.net/npm/mermaid@11.16.1/dist/mermaid.esm.min.mjs"
            }}
            </script>
            """),
        ],
    ),
    pages = [
        "Home" => "index.md",
        "User Guide" => "user.md",
        "MCP Guide" => "mcp.md",
        "Developer Guide" => [
            "Development Workflow" => "developer.md",
            "Authentication Design" => "authentication-design.md",
            "Template Design" => "developer/templates.md",
            "Template Repository Tests" => "developer/template-tests.md",
        ],
        "Deployment" => [
            "Deployment Overview" => "deployment/index.md",
            "Standalone Web" => "deployment/web.md",
            "Cloudflare" => "deployment/cloudflare.md",
            "Render" => "deployment/render.md",
        ],
        "API Reference" => "api.md",
    ],
)

deploydocs(;
    repo = "github.com/JuliaPackageFactory/PkgFactory.jl",
    devbranch = "main",
)
