using Test, PkgFactoryCLI
import PkgFactory

@testset "CLI collects input and uses core validation" begin
    reject = (args...; kwargs...) -> error("Preview must not contact GitHub")
    output = IOBuffer()
    plan = main(["--owner", "ohno", "--name", "Example.jl", "--author", "Alice", "--preview"];
        output, input=IOBuffer(), requester=reject)
    @test plan isa PkgFactory.PackagePlan
    @test plan.spec.template == PkgFactory.DEFAULT_TEMPLATE
    @test plan.spec.visibility == PkgFactory.DEFAULT_VISIBILITY
    @test plan.repository == "ohno/Example.jl"
    interactive = main(["--preview"]; input=IOBuffer("ohno\nExample\nAlice, Bob\n"), output=IOBuffer(), requester=reject)
    @test interactive.spec.authors == ("Alice", "Bob")
    @test_throws PkgFactory.InputError main(["--owner", "ohno", "--name", "../Bad", "--author", "Alice", "--preview"];
        output=IOBuffer(), requester=reject)
    @test_throws ArgumentError main(["--unknown"])
    @test_throws ArgumentError main(["--owner"])
    @test_throws ArgumentError main(["--preview"]; input=IOBuffer(), output=IOBuffer())
    @test isnothing(main(["--help"]; output=IOBuffer()))
    @test isnothing(main(["--owner", "ohno", "--name", "Example", "--author", "Alice"];
        input=IOBuffer("n\n"), output=IOBuffer(), requester=reject))
end

include("auth.jl")

include(joinpath(@__DIR__, "..", "..", "..", "test", "fixtures", "github.jl"))
include("creation.jl")
