using PkgFactory
using Documenter
using DocumenterMermaid

include("navigation.jl")
check_readme_navigation()

DocMeta.setdocmeta!(PkgFactory, :DocTestSetup, :(using PkgFactory); recursive=true)

makedocs(;
    modules=[PkgFactory],
    authors="Shuhei Ohno",
    sitename="PkgFactory.jl",
    format=Documenter.HTML(;
        canonical="https://juliapackagefactory.github.io/PkgFactory.jl",
        edit_link="main",
        assets=[
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
    pages=DOC_PAGES,
)
