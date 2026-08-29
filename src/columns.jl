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
    columns(md::MeteoData) -> Tuple{Vararg{Symbol}}

The column names carried by `md`, in storage order.
"""
columns(::MeteoData{T,N}) where {T,N} = N

"""
    hascolumn(md::MeteoData, name::Symbol) -> Bool

Whether `md` carries a column called `name`.

This is the hook for trait validation upstream: a model stage that needs beam
components can check for them at construction rather than failing at hour 4317.
"""
hascolumn(md::MeteoData, name::Symbol) = name in columns(md)

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
                    "Available columns: $(columns(md))",
                ),
            )
            return @view md.data[$(QuoteNode(name))][:]
        end
    end
end
