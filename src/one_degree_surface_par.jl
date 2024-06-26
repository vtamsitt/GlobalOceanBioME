using JLD2
using Oceananigans.Architectures: arch_array, AbstractArchitecture

@inline current_time_index(time, tot_months) = mod(unsafe_trunc(Int32, time / (30*day)), tot_months) + 1
@inline next_time_index(time, tot_months) = mod(unsafe_trunc(Int32, time / (30*day)) + 1, tot_months) + 1
@inline cyclic_interpolate(u₁::Number, u₂, time) = u₁ + mod(time / (30*day), 1) * (u₂ - u₁)

import Adapt: adapt_structure, adapt

struct OneDegreeSurfacePAR{D}
    data::D

    OneDegreeSurfacePAR(data::D) where D = new{D}(data)
end

adapt_structure(to, PAR::OneDegreeSurfacePAR) = OneDegreeSurfacePAR(adapt(to, PAR.data))

@inline function (PAR::OneDegreeSurfacePAR)(x, y, t)
    # bit silly since in the PAR integraiton were going `x = xnode ...`, maybe I should make a discrete version of this
    i, j = unsafe_trunc(Int, x + 180.5), unsafe_trunc(Int, y + 75.5)
    i, j = max(1, i), max(1, j)
    i, j = min(360, i), min(150, j)

    n1 = current_time_index(t, 12)
    n2 = next_time_index(t, 12)

    PAR1 = @inbounds PAR.data[i, j, n1]
    PAR2 = @inbounds PAR.data[i, j, n2]

    return cyclic_interpolate(PAR1, PAR2, t)
end

# required for boundary conditions
@inline function (PAR::OneDegreeSurfacePAR)(i, j, grid, clock, fields)
    t = clock.time
    i, j = max(1, i), max(1, j)
    i, j = min(360, i), min(150, j)

    n₁ = current_time_index(t, 12)
    n₂ = next_time_index(t, 12)

    @inbounds begin
        PAR₁ = PAR.data[i, j, n₁]
        PAR₂ = PAR.data[i, j, n₂]
    end

    return cyclic_interpolate(PAR₁, PAR₂, t)
end

# one degree data origionally from NASA MODIS-Aqua 2010 monthly mean (https://oceandata.sci.gsfc.nasa.gov)
function OneDegreeSurfacePAR(architecture::AbstractArchitecture; data_path = datadep"2010_near_global_bgc/PAR.jld2")
    surfac_PAR_file = jldopen(data_path)

    surfac_PAR_data = surfac_PAR_file["one_degree_climatology"] # shoul dbe mean not climatology
    surfac_PAR_data[isnan.(surfac_PAR_data)] .= 0.0

    surfac_PAR_data = arch_array(architecture, surfac_PAR_data)

    close(surfac_PAR_file)

    return OneDegreeSurfacePAR(surfac_PAR_data)
end

