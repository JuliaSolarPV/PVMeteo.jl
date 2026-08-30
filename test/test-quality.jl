@testitem "Aqua" tags=[:quality] begin
    using Aqua
    Aqua.test_all(PVMeteo)
end

@testitem "JET" tags=[:quality] begin
    using JET
    JET.test_package(PVMeteo)
end
