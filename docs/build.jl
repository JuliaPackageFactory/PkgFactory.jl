using PkgFactory
using Documenter
using DocumenterMermaid

DocMeta.setdocmeta!(PkgFactory, :DocTestSetup, :(using PkgFactory); recursive=true)

makedocs(;
    modules=[PkgFactory],
    authors="Shuhei Ohno",
    sitename="PkgFactory.jl",
    format=Documenter.HTML(;
        canonical="https://juliapackagefactory.github.io/PkgFactory.jl",
        edit_link="main",
        assets=["assets/logo.ico", "assets/custom.css"],
    ),
    pages=[
        "Home" => "index.md",
        "User Guide" => "user.md",
        "API Reference" => "api.md",
        "Web UI Hosting" => "hosting.md",
        "Developer Guide" => "developer.md",
        "Updating Older Scripts" => "migration.md",
    ],
)
