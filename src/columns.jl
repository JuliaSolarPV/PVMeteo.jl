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

Units are not carried in the type. `Unitful` composes badly with the dual and
uncertainty numbers threaded through a model chain, so units are documented here
and asserted in the test suite instead.
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
The canonical columns that measure irradiance. These share bounds, share a unit,
and are zero every night, so several checks treat them together.
"""
const IRRADIANCE = (:ghi, :dni, :dhi)

"""
    hascolumn(md::MeteoData, name::Symbol) -> Bool

Whether `md` carries a column called `name`, including `:time`.

This is the hook for trait validation upstream. A model stage that needs beam
components can check for them before it runs.
"""
hascolumn(md::MeteoData, name::Symbol) = name in Tables.columnnames(md)

"""
    time(md::MeteoData)

A view of the timestamps, always UTC. This is a method on `Base.time`, so it needs
no import and does not shadow `time()`.
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
