using {{{PKG}}}
using Documenter

DocMeta.setdocmeta!({{{PKG}}}, :DocTestSetup, :(using {{{PKG}}}); recursive = true)

makedocs(;
    checkdocs = :public,
    modules = [{{{PKG}}}],
    authors = "{{{LICENSOR}}}",
    sitename = "{{{PKG}}}.jl",
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical = "https://{{{OWNER}}}.github.io/{{{PKG}}}.jl",
        edit_link = "main",
        assets = ["assets/custom.css"],
    ),
    pages = [
        "Home" => "index.md",
        "Examples" => "examples.md",
        "API Reference" => "api.md",
    ],
)

deploydocs(;
    repo = "github.com/{{{OWNER}}}/{{{PKG}}}.jl",
    devbranch = "main",
)
