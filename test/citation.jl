module CitationTests

using PkgFactory
using Test

include(joinpath(PkgFactory.Templates.get_template_path("all-in-one"), "docs", "citation.jl"))

@testset "CFF citation and BibTeX generation" begin
    authors = ["Alice \"A\" Smith", "山田 太郎", "Team: #1"]
    files = PkgFactory.Templates.generate_template_files_dict(
        "example", "CitationPkg.jl", authors, "Citation tests", "all-in-one",
    )
    mktempdir() do dir
        path = joinpath(dir, "CITATION.cff")
        cff = replace(
            files["CITATION.cff"],
            "version: \"0.0.1\"" => "version: \"2.3.4\"",
            r"date-released: \"[^\"]+\"" => "date-released: \"2025-03-08\"",
        )
        write(path, cff)
        document = Bibliography.read_bibliography(path; format = :CFF)
        entry = only(values(Bibliography.bibliography_entries(document)))
        @test [name.last for name in entry.authors] == authors

        bibtex = citation_bibtex(path)
        citation = only(values(Bibliography.import_bibtex(bibtex)))
        @test citation.title == "CitationPkg.jl"
        @test citation.access.url == "https://github.com/example/CitationPkg.jl"
        @test citation.fields["version"] == "2.3.4"
        @test citation.date.year == "2025"
        @test citation.date.month == "3"
        @test citation.date.day == "8"
        @test length(citation.authors) == length(authors)
        @test all(occursin(author, bibtex) for author in authors)
        @test !occursin("cff-version", bibtex)
        @test !occursin("Dict{", bibtex)
        @test read(path, String) == cff

        write(path, replace(cff, "2.3.4" => "2.3.5"))
        updated = only(values(Bibliography.import_bibtex(citation_bibtex(path))))
        @test updated.fields["version"] == "2.3.5"

        write(path, "cff-version: 1.2.0\n")
        @test_throws ErrorException citation_bibtex(path)
    end
end

@testset "explicit CFF author names" begin
    authors = ["Shuhei Ohno", "山田 太郎", "María de la Cruz"]
    citation_authors = [
        (family_names = "Ohno", given_names = "Shuhei"),
        (family_names = "山田", given_names = "太郎"),
        (family_names = "de la Cruz", given_names = "María", orcid = "https://orcid.org/0000-0002-1825-0097"),
    ]
    render(; kwargs...) = PkgFactory.Templates.generate_template_files_dict(
        "example", "CitationPkg.jl", authors, "Citation tests", "all-in-one"; kwargs...,
    )
    files = render(; citation_authors)
    cff = files["CITATION.cff"]
    @test occursin("  - family-names: \"Ohno\"\n    given-names: \"Shuhei\"", cff)
    @test occursin("    orcid: \"https://orcid.org/0000-0002-1825-0097\"", cff)
    @test occursin("message: \"If you use this software, please cite it as below.\"", cff)
    mktempdir() do dir
        path = joinpath(dir, "CITATION.cff")
        write(path, cff)
        citation = only(values(Bibliography.import_bibtex(citation_bibtex(path))))
        @test [(join(filter(!isempty, [name.particle, name.last]), " "), name.first) for name in citation.authors] == [
            ("Ohno", "Shuhei"), ("山田", "太郎"), ("de la Cruz", "María"),
        ]
        @test citation.access.url == "https://github.com/example/CitationPkg.jl"
    end
    @test_throws ArgumentError render(; citation_authors = citation_authors[1:1])
    @test_throws ArgumentError render(; citation_authors = [(given_names = "Name",) for _ in authors])
    @test_throws ArgumentError render(; citation_authors = [(family_names = " ",) for _ in authors])
end

end
