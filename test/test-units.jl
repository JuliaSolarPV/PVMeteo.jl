@testsnippet UnitFixture begin
    using Dates
    fixture(name) = joinpath(@__DIR__, "fixtures", name)
    minimal() = PVMeteo.read_epw(fixture("minimal.epw"))
end

@testitem "pressure is Pa not mbar" tags=[:unit, :fast] setup=[UnitFixture] begin
    p = PVMeteo.pressure(minimal())
    @test all(90_000 .< p .< 110_000)
end

@testitem "irradiance is W/m2 not Wh/m2" tags=[:unit, :fast] setup=[UnitFixture] begin
    hourly = maximum(PVMeteo.ghi(minimal()))
    quarterly = maximum(PVMeteo.ghi(PVMeteo.read_epw(fixture("subhourly.epw"))))
    @test 600 < hourly < 1000
    @test isapprox(hourly, quarterly; rtol = 0.05)
end

@testitem "precipitable water is cm" tags=[:unit, :fast] setup=[UnitFixture] begin
    # The fixture writes 15 mm, which is 1.5 cm.
    @test all(PVMeteo.precipitable_water(minimal()) .== 1.5)
end

@testitem "temperature is degrees Celsius" tags=[:unit, :fast] setup=[UnitFixture] begin
    t = PVMeteo.temp_air(minimal())
    @test all(-60 .< t .< 60)
end

@testitem "wind is m/s and degrees" tags=[:unit, :fast] setup=[UnitFixture] begin
    md = minimal()
    @test all(0 .<= PVMeteo.wind_speed(md) .< 60)
    @test all(0 .<= PVMeteo.wind_direction(md) .<= 360)
end

@testitem "fractions are not percentages" tags=[:unit, :fast] setup=[UnitFixture] begin
    md = minimal()
    @test all(0 .<= PVMeteo.relative_humidity(md) .<= 100)
    @test maximum(PVMeteo.relative_humidity(md)) > 1
    @test all(0 .<= PVMeteo.albedo(md) .<= 1)
end

@testitem "TMY3 agrees with EPW on units" tags=[:unit, :fast] setup=[UnitFixture] begin
    md = PVMeteo.read_tmy3(fixture("minimal_tmy3.csv"))
    @test all(90_000 .< PVMeteo.pressure(md) .< 110_000)
    @test 600 < maximum(PVMeteo.ghi(md)) < 1000
    @test all(0 .< PVMeteo.precipitable_water(md) .< 10)
end
