using {{{PKG}}}
using Documenter

include("citation.jl")
citation_path = joinpath(@__DIR__, "src", "assets", "citation.bib")
mkpath(dirname(citation_path))
write(citation_path, citation_bibtex(joinpath(@__DIR__, "..", "CITATION.cff")))

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
        "User Guide" => "user.md",
        "Developer Guide" => "developer.md",
        "API Reference" => "api.md",
    ],
)

deploydocs(;
    repo = "github.com/{{{OWNER}}}/{{{PKG}}}.jl",
    devbranch = "main",
)
