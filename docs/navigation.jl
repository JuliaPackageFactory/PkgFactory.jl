const DOC_PAGES = [
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
]

function readme_navigation(pages; depth=0)
    lines = String[]
    for (title, target) in pages
        prefix = "  "^depth * "- "
        if target isa AbstractVector
            push!(lines, prefix * title)
            append!(lines, readme_navigation(target; depth=depth + 1))
        else
            isfile(joinpath(@__DIR__, "src", target)) || error("Missing documentation page: $target")
            route = replace(target, r"(^|/)index\.md$" => s"\1")
            endswith(route, ".md") && (route = chop(route; tail=3) * "/")
            push!(lines, prefix * "[$title](https://juliapackagefactory.github.io/PkgFactory.jl/dev/$route)")
        end
    end
    return lines
end

function check_readme_navigation(path=joinpath(@__DIR__, "..", "README.md"))
    readme = replace(read(path, String), "\r\n" => "\n")
    section = match(r"(?ms)^## Documentation\n(.*?)(?=^## |\z)", readme)
    expected = join(readme_navigation(DOC_PAGES), "\n")
    isnothing(section) && error("README.md is missing its Documentation section.")
    strip(section.captures[1]) == expected || error(
        "README documentation navigation differs from docs/navigation.jl. Expected:\n\n" * expected)
    return nothing
end
