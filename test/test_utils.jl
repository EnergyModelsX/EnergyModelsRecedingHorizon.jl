
@testset "Get RH object instances" begin
    T = TS.SimpleTimes([2, 3, 1, 3, 4, 2])
    T_twolevel = TS.TwoLevel(1, 1, T)
    sl = 3:4
    t_rh = collect(T_twolevel)[sl]
    vec1 = [6, 5, 4, 3, 2, 1]
    P1 = TS.OperationalProfile(vec1)
    @test (EMRH.get_property_rh(P1, t_rh)).vals == vec1[sl]

    @test (EMRH.get_property_rh(Dict(:k => P1), t_rh))[:k].vals == vec1[sl]

    t_rh = collect(T)[sl]
    @test (EMRH.get_property_rh(P1, t_rh)).vals == vec1[sl]

    Pf = TS.FixedProfile(7)
    @test (EMRH.get_property_rh(Pf, t_rh)).val == 7

    Tbig = TS.SimpleTimes(8, 2)
    t_rh = collect(Tbig)[7:7]
    @test (EMRH.get_property_rh(P1, t_rh).vals) == [1] # TODO: should this throw a BoundsError error instead?

    t_rh = collect(Tbig)[4]
    @test_throws MethodError EMRH.get_property_rh(P1, t_rh) # only allows t_rh as vector
    t_rh = collect(Tbig)[4:4]
    @test (EMRH.get_property_rh(P1, t_rh)).vals == [3]

    t_rh = collect(Tbig)[1:2]
    @test EMRH.get_property_rh(:something, t_rh) == :something

    T = TS.SimpleTimes([6, 7, 8, 9])
    t_rh = collect(T)[3:4]
    power = ResourceCarrier("power", 0.0)
    n_sink = RefSink(
        "sink", # id
        OperationalProfile([11, 12, 13, 14]), # cap
        Dict(
            :surplus => OperationalProfile([21, 22, 23, 24]),
            :deficit => OperationalProfile([31, 32, 33, 34]),
        ), # penalty
        Dict(power => 1), # input
    )
    n_sink_rh = EMRH.get_object_rh(n_sink, t_rh)
    @test n_sink.cap.vals[3] == n_sink_rh.cap.vals[1]
    @test n_sink.penalty[:surplus].vals[3] == n_sink_rh.penalty[:surplus].vals[1]

    n_av = GenAvailability("av", [power])
    n_av_rh = EMRH.get_object_rh(n_av, t_rh)
    # @test n_av == n_av_rh # same concrete object
    l_orig = Direct("av-source", n_av, n_sink, Linear())
    map_nodes = Dict(n_av => n_av_rh, n_sink => n_sink_rh)
    l_rh = EMRH.get_new_link(l_orig, map_nodes)
    @test l_rh.to == n_sink_rh
end

@testset "Result containers" begin
    power = ResourceCarrier("power", 0.0)
    co2 = ResourceEmit("co2", 1.0)
    products = [power, co2]

    T = TwoLevel(1, 1, SimpleTimes([2, 3, 4, 2, 1]))
    hor = PeriodHorizons([duration(t) for t ∈ T], 2, 1)

    model = RecHorOperationalModel(
        Dict(co2 => FixedProfile(10)), Dict(co2 => FixedProfile(0)), co2,
    )

    nodes = [
        GenAvailability("Availability", products),
        RefSource(
            "electricity source", # id
            FixedProfile(1e12), # cap
            OperationalProfile([1, 10, 1, 10, 1]), # opex_var
            FixedProfile(0), # opex_fixed
            Dict(power => 1), # output
        ),
        RefStorage{RecedingAccumulating}(
            "electricity storage", # id
            StorCapOpexVar(FixedProfile(100), FixedProfile(0.01)), # rate_cap, opex_var
            StorCapOpexFixed(FixedProfile(1.5), FixedProfile(0)), # stor_cap, opex_fixed
            power, # stor_res::T
            Dict(power => 1), # input::Dict{<:Resource, <:Real}
            Dict(power => 1), # output::Dict{<:Resource, <:Real}
            Vector([
                InitStorageData(0),
                EmptyData() # testing multiple data
            ]),
        ),
        RefSink(
            "electricity demand", # id
            OperationalProfile([3, 4, 5, 6, 3]), # cap
            Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e6)), # penalty
            Dict(power => 1), # input
        ),
    ]

    links = [
        Direct("av-source", nodes[1], nodes[2], Linear()),
        Direct("av-storage", nodes[1], nodes[3], Linear()),
        Direct("av-demand", nodes[1], nodes[4], Linear()),
        Direct("source-av", nodes[2], nodes[1], Linear()),
        Direct("storage-av", nodes[3], nodes[1], Linear()),
        Direct("demand-av", nodes[4], nodes[1], Linear()),
    ]

    case = Dict(
        :nodes => nodes, :links => links, :products => products, :T => T,
        :horizons => hor,
    )

    optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)
    hor_test = first(hor)
    case_rh, model_rh = get_rh_case_model(case, model, hor_test)

    m_rh1 = run_model(case_rh, model_rh, optimizer)
    @test termination_status(m_rh1) == MOI.OPTIMAL

    m_EMB = run_model(case, model, optimizer)
    @test termination_status(m_EMB) == MOI.OPTIMAL

    results_EMRH = Dict{Symbol,AbstractArray{Float64}}()
    EMRH.update_results!(results_EMRH, m_rh1, case_rh, case, hor_test)
    results_EMB = Dict(k => value.(m_EMB[k]) for k ∈ keys(object_dictionary(m_EMB)))
    @test Set(keys(results_EMB)) == union(
        keys(results_EMRH),
        [:opex_var, :emissions_strategic, :opex_fixed], # fields for strategic horizons - to be implemented
    )
    dense_containers(cont) =
        filter(kv -> (typeof(kv[2]) <: Containers.DenseAxisArray), cont)
    for (k_EMRH, _) ∈ dense_containers(results_EMRH)
        @test size(results_EMRH[k_EMRH].data) == size(results_EMB[k_EMRH].data)
    end
    sparse_containers(cont) =
        filter(kv -> (typeof(kv[2]) <: Containers.SparseAxisArray), cont)
    for (k_EMRH, _) ∈ sparse_containers(results_EMRH)
        @test Set(results_EMRH[k_EMRH].data.keys) ⊆ Set(results_EMB[k_EMRH].data.keys) # not all values are allocated initially
    end
end

@testset "Check nodes for OperationalProfile" begin
    el = ResourceCarrier("el", 0.2)
    heat = ResourceCarrier("heat", 0.0)
    co2 = ResourceEmit("co2", 1.0)
    resources = [el, heat, co2]

    profile = [1, 2, 3]
    dim_t = length(profile)

    em_process_oper = EmissionsProcess(Dict(co2 => OperationalProfile(profile)))
    em_process_fixed = EmissionsProcess(Dict(co2 => FixedProfile(2)))

    data = [
        EmissionsEnergy(OperationalProfile(profile)),
        EmissionsProcess(Dict(co2 => OperationalProfile(profile))),
        EmissionsProcess(Dict(co2 => FixedProfile(2))),
    ]

    #create individual nodes of the system
    av = GenAvailability("Availability", resources)
    source_fixed = RefSource(
        "electricity source", #Node id or name
        FixedProfile(1e12), #Capacity
        FixedProfile(100), #variable OPEX
        FixedProfile(0), #Fixed OPEN in EUR/8h
        Dict(el => 1), #output from the node
    )
    source_oper = RefSource(
        "electricity source", #Node id or name
        FixedProfile(1e12), #Capacity
        OperationalProfile(profile), #variable OPEX
        FixedProfile(0), #Fixed OPEN in EUR/8h
        Dict(el => 1), #output from the node
    )
    network = RefNetworkNode(
        "el_to_heat",
        FixedProfile(1e12), #cap - This can be OperationalProfile
        OperationalProfile(profile), #opex variable
        FixedProfile(0),
        Dict(el => 1), #input
        Dict(heat => 1), #output
        data,
    )
    storage = RefStorage{RecedingAccumulating}(
        "electricity storage",
        StorCapOpexVar(FixedProfile(100), FixedProfile(100)), # rate_cap, opex_var
        StorCapOpexFixed(FixedProfile(10), FixedProfile(0)), # stor_cap, opex_fixed
        el, # stor_res::T
        Dict(el => 1), # input::Dict{<:Resource, <:Real}
        Dict(el => 1), # output::Dict{<:Resource, <:Real}
    )
    storage_data = RefStorage{RecedingAccumulating}(
        "electricity storage",
        StorCapOpexVar(FixedProfile(100), FixedProfile(100)), # rate_cap, opex_var
        StorCapOpexFixed(FixedProfile(10), FixedProfile(0)), # stor_cap, opex_fixed
        el, # stor_res::T
        Dict(el => 1), # input::Dict{<:Resource, <:Real}
        Dict(el => 1), # output::Dict{<:Resource, <:Real}
        data,
    )
    storage_charge_oper = RefStorage{RecedingAccumulating}(
        "electricity storage",
        StorCapOpexVar(OperationalProfile(profile), FixedProfile(100)), # rate_cap, opex_var
        StorCapOpexFixed(FixedProfile(10), FixedProfile(0)), # stor_cap, opex_fixed
        el, # stor_res::T
        Dict(el => 1), # input::Dict{<:Resource, <:Real}
        Dict(el => 1), # output::Dict{<:Resource, <:Real}
    )
    storage_level_oper = RefStorage{RecedingAccumulating}(
        "electricity storage",
        StorCapOpexVar(FixedProfile(100), FixedProfile(100)), # rate_cap, opex_var
        StorCapOpexFixed(OperationalProfile(profile), FixedProfile(0)), # stor_cap, opex_fixed
        el, # stor_res::T
        Dict(el => 1), # input::Dict{<:Resource, <:Real}
        Dict(el => 1), # output::Dict{<:Resource, <:Real}
    )
    storage_charge_level_data_oper = RefStorage{RecedingAccumulating}(
        "electricity storage",
        StorCapOpexVar(OperationalProfile(profile), FixedProfile(100)), # rate_cap, opex_var
        StorCapOpexFixed(OperationalProfile(profile), FixedProfile(0)), # stor_cap, opex_fixed
        el, # stor_res::T
        Dict(el => 1), # input::Dict{<:Resource, <:Real}
        Dict(el => 1), # output::Dict{<:Resource, <:Real}
        data,
    )
    sink = RefSink(
        "heat demand", #node ID or name
        OperationalProfile(profile), #demand in MW (time profile)
        Dict(
            :surplus => FixedProfile(0),
            :deficit => OperationalProfile(1e6 * ones(dim_t)),
        ), #surplus and deficit penalty
        Dict(heat => 1), #energy demand and corresponding ratio
    )

    @test all(EMRH._fields_with_operational_profile(network) .== [:opex_var, :data])
    @test all(EMRH._fields_with_operational_profile(source_oper) .== [:opex_var])
    @test all(EMRH._fields_with_operational_profile(source_fixed) .== Symbol[])
    @test all(EMRH._fields_with_operational_profile(av) .== Symbol[])
    @test all(EMRH._fields_with_operational_profile(storage) .== Symbol[])
    @test all(EMRH._fields_with_operational_profile(storage_data) .== [:data])
    @test all(EMRH._fields_with_operational_profile(storage_charge_oper) .== [:charge])
    @test all(EMRH._fields_with_operational_profile(storage_level_oper) .== [:level])
    @test all(
        EMRH._fields_with_operational_profile(storage_charge_level_data_oper) .==
        [:charge, :level, :data],
    )
end

@testset "EMRH._has_field_operational_profile" begin
    @test EMRH._has_field_operational_profile(OperationalProfile([1]))
    @test EMRH._has_field_operational_profile(
        Dict(:a => Dict(:b => Dict(:c => OperationalProfile([1])))),
    ) # true
    @test !EMRH._has_field_operational_profile(
        Dict(:a => Dict(:b => Dict(:c => FixedProfile(1)))),
    ) # false
    @test_throws ErrorException EMRH._has_field_operational_profile(
        Dict(:a => StrategicProfile([1, 2])),
    ) # raises Error. EMRH should not be used with StrategicProfile

    #test for various Data
    @test !EMRH._has_field_operational_profile(EmissionsEnergy(OperationalProfile([1]))) #EmissionsEnergy accepts any input arguments, but does not use it.
    @test EMRH._has_field_operational_profile(
        EmissionsProcess(Dict(co2 => OperationalProfile([1]))),
    )
    @test !EMRH._has_field_operational_profile(
        EmissionsProcess(Dict(co2 => FixedProfile(2))),
    )
    @test !EMRH._has_field_operational_profile(EmptyData())
    @test !EMRH._has_field_operational_profile(InitStorageData(4.0))

    #test for various AbstractStorageParameters
    @test EMRH._has_field_operational_profile(
        StorCapOpexFixed(OperationalProfile([1]), FixedProfile(0)),
    )
    @test !EMRH._has_field_operational_profile(
        StorCapOpexFixed(FixedProfile(1), FixedProfile(0)),
    )
    @test EMRH._has_field_operational_profile(
        StorCapOpexVar(OperationalProfile([1]), FixedProfile(0)),
    )
    @test !EMRH._has_field_operational_profile(
        StorCapOpexVar(FixedProfile(1), FixedProfile(0)),
    )
    @test EMRH._has_field_operational_profile(StorOpexVar(OperationalProfile([1])))
    @test !EMRH._has_field_operational_profile(StorOpexVar(FixedProfile(1)))
    @test EMRH._has_field_operational_profile(StorCap(OperationalProfile([1])))
    @test !EMRH._has_field_operational_profile(StorCap(FixedProfile(1)))
end
