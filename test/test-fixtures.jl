@testitem "every fixture is present" tags=[:unit, :fast] begin
    dir = joinpath(@__DIR__, "fixtures")
    expected = [
        "minimal.epw",
        "subhourly.epw",
        "dst_spring.epw",
        "dst_autumn.epw",
        "dst_duplicate.epw",
        "gap.epw",
        "closure_good.epw",
        "closure_bad.epw",
        "closure_cosz.csv",
        "minimal_tmy3.csv",
    ]
    for name in expected
        @test isfile(joinpath(dir, name))
    end
end

@testitem "fixtures match their generator" tags=[:unit] begin
    # A committed fixture that has drifted from make_fixtures.jl is a fixture
    # nobody can regenerate or reason about. Regenerate into a scratch directory
    # and compare bytes.
    dir = joinpath(@__DIR__, "fixtures")
    generator = Module(:FixtureGenerator)
    Base.include(generator, joinpath(dir, "make_fixtures.jl"))

    mktempdir() do scratch
        written = Base.invokelatest(generator.make_all, scratch)
        @test !isempty(written)
        for path in written
            name = basename(path)
            @test read(path) == read(joinpath(dir, name))
        end
    end
end
