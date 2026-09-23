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

end
