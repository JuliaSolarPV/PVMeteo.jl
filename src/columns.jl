"""
    CANONICAL

The canonical column names, in SI units throughout.

| Name                  | Unit  |
|:----------------------|:------|
| `:ghi`                | W/m²  |
| `:dni`                | W/m²  |
| `:dhi`                | W/m²  |
| `:temp_air`           | °C    |
| `:wind_speed`         | m/s   |
| `:wind_direction`     | °     |
| `:pressure`           | Pa    |
| `:relative_humidity`  | %     |
| `:albedo`             | none  |
| `:precipitable_water` | cm    |

Units live in this table and are asserted in the test suite.
"""
const CANONICAL = (
    :ghi,
    :dni,
    :dhi,
    :temp_air,
    :wind_speed,
    :wind_direction,
    :pressure,
    :relative_humidity,
    :albedo,
    :precipitable_water,
)

"""
The canonical columns that measure irradiance. Several checks treat them
together.
"""
const IRRADIANCE = (:ghi, :dni, :dhi)

"""
    hascolumn(md::MeteoData, name::Symbol) -> Bool

Whether `md` carries a column called `name`, including `:time`. A model stage can
check for the columns it needs before it runs.
"""
hascolumn(md::MeteoData, name::Symbol) = name in Tables.columnnames(md)

"""
    time(md::MeteoData)

A view of the timestamps, always UTC. This is a method on `Base.time`, so it needs
no import.
"""
Base.time(md::MeteoData) = @view md.time[:]

for name in CANONICAL
    @eval begin
        """
            $($(QuoteNode(name)))(md::MeteoData)

        A view of the `$($(QuoteNode(name)))` column. Throws if `md` does not carry it.
        """
        function $(name)(md::MeteoData)
            hascolumn(md, $(QuoteNode(name))) || throw(
                ArgumentError(
                    "this MeteoData has no :$($(QuoteNode(name))) column. " *
                    "Available columns: $(keys(md.data))",
                ),
            )
            return @view md.data[$(QuoteNode(name))][:]
        end
    end
end
