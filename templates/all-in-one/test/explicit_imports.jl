using {{{PKG}}}
using ExplicitImports
using Test

@testset "ExplicitImports.jl" begin
    @test check_no_implicit_imports({{{PKG}}}) === nothing
    @test check_no_stale_explicit_imports({{{PKG}}}) === nothing
end
