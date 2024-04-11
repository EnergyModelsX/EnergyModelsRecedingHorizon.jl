using CSV
using DataFrames
using FileIO
using JLD2
using Statistics

"""
    create_transmission_mode(mode_type::Type{TransmissionMode}, corr_id::String, data, resource::EMB.Resource, power::EMB.Resource, T, multiplier::Dict)

Creates the instances for the transmission modes depending on the chosen Type.
The function is currently limited to the types `PipeSimple`, `RefDynamic`, and `RefStatic`.
"""
function create_transmission_mode(mode_type::Type{PipeSimple},
    corr_id::String,
    data,
    resource::EMB.Resource,
    power::EMB.Resource,
    T,
    multiplier::Dict,
)

    if haskey(data, "trans_max_add") && data["trans_max_add"] > 0
        inv_data = create_transmission_invest(data, multiplier, T)
    else
        inv_data = []
    end

    tmp = PipeSimple(
        id = corr_id*"_"*data["name"],
        inlet = resource,
        outlet = resource,
        consuming = power,
        consumption_rate = time_profile(data["consumption_rate"], T),
        trans_cap = time_profile(data["trans_capacity"], T),
        trans_loss = time_profile(data["trans_loss"], T),
        opex_var = time_profile(data["trans_OPEX_variable"]*multiplier["dist"], T),
        opex_fixed = time_profile(data["trans_OPEX_fixed"]*multiplier["dist"], T),
        data = inv_data,
    )

    return [tmp]
end

function create_transmission_mode(mode_type::Type{RefStatic},
    corr_id::String,
    data,
    resource::EMB.Resource,
    power::EMB.Resource,
    T,
    multiplier::Dict,
)
    if haskey(data, "trans_max_add") && data["trans_max_add"] > 0
        inv_data = create_transmission_invest(data, multiplier, T)
    else
        inv_data = []
    end

    tmp = RefStatic(
        corr_id*"_"*data["name"],
        resource,
        time_profile(data["trans_capacity"], T),
        time_profile(data["trans_loss"], T),
        time_profile(data["trans_OPEX_variable"]*multiplier["dist"], T),
        time_profile(data["trans_OPEX_fixed"]*multiplier["dist"], T),
        data["direction"],
        inv_data,
    )

    return [tmp]
end

function create_transmission_mode(mode_type::Type{RefDynamic},
    corr_id::String,
    data,
    resource::EMB.Resource,
    power::EMB.Resource,
    T,
    multiplier::Dict,
)

    if haskey(data, "trans_max_add") && data["trans_max_add"] > 0
        inv_data = create_transmission_invest(data, multiplier, T)
    else
        inv_data = []
    end

    tmp = RefDynamic(
        corr_id*"_"*data["name"],
        resource,
        time_profile(data["trans_capacity"], T),
        time_profile(data["trans_loss"], T),
        time_profile(data["trans_OPEX_variable"]*multiplier["dist"], T),
        time_profile(data["trans_OPEX_fixed"]*multiplier["dist"], T),
        data["direction"],
        inv_data,
    )

    return [tmp]
end

"""
    create_transmission_invest(data, multiplier)

Creates the transmission investment data based on the provided input data.
"""
function create_transmission_invest(data, multiplier, T)

    if haskey(data, "investment_mode")
        inv_mode = map_inv_mode(data["investment_mode"])
    else
        inv_mode = ContinuousInvestment()
    end
    inv_data = [TransInvData(
                capex_trans     = time_profile(data["trans_CAPEX"]*multiplier["capex"]*multiplier["dist"], T), # CAPEX [€/kW]
                capex_trans_offset = time_profile(data["trans_CAPEX_offset"]*multiplier["capex_offset"]*multiplier["dist"], T), # CAPEX [€]
                trans_max_inst  = time_profile(data["trans_max_installed"], T),    # max installed capacity [kW]
                trans_max_add   = time_profile(data["trans_max_add"], T),          # max_add [kW]
                trans_min_add   = time_profile(data["trans_min_add"], T),          # min_add [kW]
                inv_mode        = inv_mode,
                trans_increment = time_profile(data["trans_increment"], T),
                trans_start     = data["trans_start"],
    )]

    return inv_data
end

"""
    map_inv_mode(string)

Provides a map from string to investment mode
"""
function map_inv_mode(string)
    inv_mode = Dict(
        "SemiContinuous" => SemiContinuousInvestment(),
        "SemiContinuousOffset" => SemiContinuousOffsetInvestment(),
        "Continuous"     => ContinuousInvestment(),
    )
    return inv_mode[string]
end

"""
    map_trans_mode(string)

Provides a map from string to reference transmission mode
"""
function map_trans_mode(string)
    trans_mode = Dict(
        "El" => "power_line",
        "NG" => "natural_gas_pipe",
    )
    return trans_mode[string]
end

"""
    map_trans_type(string)

Provides a mapping of the transmission mode type names to the technology julia
types necessary to create the correct instances when reading input data.
"""
function map_trans_type(string)
    trans_type = Dict(
        "PipeSimple" => PipeSimple,
        "RefStatic"  => RefStatic,
        "RefDynamic"  => RefDynamic,
    )
    return trans_type[string]
end

"""
    map_multiplier(corr_p, offshore)

Returns the multipliers used in the calculation of the pipeline investments
"""
function map_multiplier(corr_p, dist, offshore)

    # Initiate the dictionary
    multiplier = Dict()
    multiplier["capex"] = 1
    multiplier["capex_offset"] = 1

    # Multiplier for the distance
    if corr_p["full"]
        multiplier["dist"] = 1
    elseif haskey(corr_p, "distance")
        multiplier["dist"] = corr_p["distance"]
    else
        multiplier["dist"] = dist
    end

    # Multiplier for onshore vs. offshore
    if offshore
        multiplier["capex"] = corr_p["multiplier_CAPEX"]
        multiplier["capex_offset"] = corr_p["multiplier_CAPEX_offset"]
    end

    return multiplier
end

"""
    nodes_sub(𝒩, string::String)

Returns all nodes that include in the name the `string`
"""
function nodes_sub(𝒩, string::String)

    sub_nodes = Array{EMB.Node}([])
    for n ∈ 𝒩
        if occursin(string, n.id)
            append!(sub_nodes, [n])
        end
    end
    sub_nodes = convert(Array{typejoin(typeof.(sub_nodes)...)}, sub_nodes)

    return sub_nodes
end
"""
    link_sub(ℒ, string::String)

Returns all links that include in the name the `string`.
"""
function link_sub(ℒ, string::String)

    sub_links = Array{EMB.Link}([])
    for l ∈ ℒ
        if occursin(string, l.id)
            append!(sub_links, [l])
        end
    end

    return sub_links
end

"""
    unique_resources(nodes)

Returns all resources in the array `nodes` that are either an `input` or `output`.
These `unique` resources can then be used as input to the availability node.
"""
function unique_resources(nodes)

    products = []
    for n ∈ nodes
        try
            append!(products, inputs(n))
        catch
            nothing
        end
        try
            append!(products, outputs(n))
        catch
            nothing
        end
    end
    products = unique(products)

    return products
end


"""
    time_profile(x,T::TimeStructure)

Transform a given input x into a Timeprofile as defines in the Timestructures package.
The type of time_profile returned depends on the form of x

- Real                      -> FixedProfile
- Array{<:Real,1}           -> StrategicProfile or OperationalProfile; based on length of array
- Array{<:Real,2}           -> DynamicProfile
- AbstractArray{<:Real,2}   -> DynamicProfile
- AbstractMatrix            -> DynamicProfile
- Nothing                   -> FixedProfile(0)

The new design is based on reading `DataFrame`. It automatically iterates through the provided
data frame. This implies however, that the `DataFrame` has to be loaded beforehand and has
the following columns (all, except for val, are optional)
 - sp --> strategic period
 - op --> operational period
 - rp --> representative period
 - scp --> scenario period

 All values have to be provided as integers for the the above columns. The value in the
column `val` has to be a number corresponding to the value.

Depending on the input, different `TimeProfile`s are created.
"""
function time_profile()
    return FixedProfile(0)
end
function time_profile(x::Nothing, T::TimeStructure)
    return FixedProfile(0)
end

function time_profile(x::Real, T::TimeStructure)
    return FixedProfile(x)
end

function time_profile(x::Array{<:Real,1}, T::TimeStructure)
    if length(x) == T.len
        return StrategicProfile(x)
    else
        return OperationalProfile(x)
    end
end

function time_profile(df::DataFrame, ts::TwoLevel)

    profile = []
    𝒯ᴵⁿᵛ = strategic_periods(ts)
    sort!(df)
    if any("sp" .== names(df))
        for t_inv ∈ 𝒯ᴵⁿᵛ
            df_sp = select!(df[in.(df.sp, t_inv.sp), :], Not(:sp))
            push!(profile, time_profile(df_sp, t_inv.operational))
        end
        profile = convert(Array{typejoin(typeof.(profile)...)}, profile)
        return StrategicProfile(profile)
    else
        return time_profile(df, ts.operational[1])
    end
end

function time_profile(df::DataFrame, ts::RepresentativePeriods)

    𝒯ʳᵖ = repr_periods(ts)
    if any("rp" .== names(df))
        profile = []
        for t_rp ∈ 𝒯ʳᵖ
            df_rp = select(df[in.(df.rp, t_rp.rper), :], Not(:rp))
            push!(profile, time_profile(df_rp, t_rp.operational))
        end
        profile = convert(Array{typejoin(typeof.(profile)...)}, profile)
        return RepresentativeProfile(profile)
    else
        return time_profile(df, ts.rep_periods[1])
    end
end

function time_profile(df::DataFrame, ts::OperationalScenarios)

    𝒯ˢᶜ = opscenarios(ts)
    if any("scp" .== names(df))
        profile = []
        for t_scp ∈ 𝒯ˢᶜ
            df_scp = select(df[in.(df.scp, t_scp.scen), :], Not(:scp))
            push!(profile, time_profile(df_scp, t_scp.operational))
        end
        profile = convert(Array{typejoin(typeof.(profile)...)}, profile)
        return ScenarioProfile(profile)
    else
        return time_profile(df, ts.rep_periods[1])
    end
end

function time_profile(df::DataFrame, ts::SimpleTimes)

    vals = df[!, :val]
    if any("op" .== names(df))
        return OperationalProfile(vals)
    else
        return FixedProfile(vals[1])
    end
end

function time_profile(x::AbstractMatrix, T::TimeStructure)
    profile = []
    if T.len != size(x)[1]
        x = x'
    end
    for k ∈ range(1, T.len)
        push!(profile, OperationalProfile(x[k,:]))
    end
    profile = convert(Array{typejoin(typeof.(profile)...)}, profile)
    return StrategicProfile(profile)
end

"""
    save_case_modeltype(case::Dict, modeltype::EnergyModel; filename=joinpath(pwd(),"case.JLD2"))

Saves both the `case` dictionary and `modeltype` in a JLD2 format in the file case.JLD2.
If no `directory` is specified, it saves it as `case` in in the current working directory.
"""
function save_case_modeltype(case::Dict, modeltype::EnergyModel; directory=pwd())
    jldopen(joinpath(directory,"case.JLD2"), "w") do file
        file["case"] = case
        file["modeltype"] = modeltype
    end
end

"""
    save_results(model::Model; directory=joinpath(pwd(),"csv_files"))

Saves the model results of all variables as CSV files. The model results are saved in a new directory.
If no directory is specified, it will create, if necessary, a new directory "csv_files" in the current
working directory and save the files in said directory.
"""
function save_results(model::Model; directory=joinpath(pwd(),"csv_files"))
    vars = collect(keys(object_dictionary(model)))

    if !ispath(directory)
        mkpath(directory)
    end

    Threads.@threads for v ∈ vars
        if !isempty(model[v])
            fn = joinpath(directory, string(v) * ".csv")
            CSV.write(fn, JuMP.Containers.rowtable(value, model[v]))
        end
    end
end
