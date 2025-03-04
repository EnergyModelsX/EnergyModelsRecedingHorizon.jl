@testset "StorageValueCut" begin
    # Introduce the node type for testing
    Power = ResourceCarrier("Power", 0.0)
    storage = RefStorage{RecedingAccumulating}(
        "storage",  # Node ID
        StorCap(FixedProfile(10)), # Charge
        StorCap(FixedProfile(100)), # level, UnionCap
        Power,              # stor_res, stored resource
        Dict(Power => 1),
        Dict(Power => 1),
        [
            StorageInitData(0)
        ]
    )
    # Create the StorageValueCut type
    svc = StorageValueCut("stor_1", [ElementValue(storage, 1)], 5)

    # Test that the access functions are working
    @test EMRH.cut_rhs(svc) == 5
    @test EMRH.coefficients(svc) == [(storage, 1)]
end

@testset "StorageValueCuts" begin
    @testset "Access functions" begin
        # Create the StorageValueCut type
        Power = ResourceCarrier("Power", 0.0)
        storage = RefStorage{RecedingAccumulating}(
            "storage",  # Node ID
            StorCap(FixedProfile(10)), # Charge
            StorCap(FixedProfile(100)), # level, UnionCap
            Power,              # stor_res, stored resource
            Dict(Power => 1),
            Dict(Power => 1),
            [StorageInitData(0)],
        )
        storage_value_cut = StorageValueCut("stor_1", [ElementValue(storage, 1)], 5)

        # Function for creating different StorageValueCuts
        stor_val_cuts(svc::StorageValueCut, time_profile::Vector) =
            [StorageValueCuts(j, k, j, j, [svc]) for (j, k) ∈ enumerate(time_profile)]

        time_vec = [0, 10, 10, 40, 70]
        𝒱 = stor_val_cuts(storage_value_cut, time_vec)

        # Test that the access functions are working
        @test all(EMRH.weight(𝒱[k]) == k for k ∈ eachindex(𝒱))
        @test all(EMRH.time_weight(𝒱[k]) == k for k ∈ eachindex(𝒱))
        @test all(EMRH.cuts_time(𝒱[k]) == time_vec[k] for k ∈ eachindex(𝒱))
        @test all(EMRH.cuts(𝒱[k]) == [storage_value_cut] for k ∈ eachindex(𝒱))
    end

    function stor_val_cuts(time_profile::Vector)
        # Create the StorageValueCuts type
        Power = ResourceCarrier("Power", 0.0)
        CO2 = ResourceEmit("CO2", 1.0)
        stor_a = RefStorage{RecedingAccumulating}(
            "stor_a",
            StorCap(FixedProfile(10)),
            StorCap(FixedProfile(100)),
            Power,
            Dict(Power => 1),
            Dict(Power => 1),
            [StorageInitData(0)],
        )
        stor_b = RefStorage{RecedingAccumulating}(
            "stor_b",
            StorCap(FixedProfile(10)),
            StorCap(FixedProfile(100)),
            Power,
            Dict(Power => 1),
            Dict(Power => 1),
            [StorageInitData(0)],
        )
        𝒩 = [stor_a, stor_b]

        model = RecHorOperationalModel(
            Dict(CO2 => FixedProfile(10)), #upper bound for CO2 in t/8h
            Dict(CO2 => FixedProfile(0)), # emission price for CO2 in EUR/t
            CO2,
        )

        𝒱 = [
            StorageValueCuts(j, k, j, j,
                [
                    StorageValueCut(1, Dict(stor_a => -j*2, stor_b => -j*5), 0),
                    StorageValueCut(1, Dict(stor_a => -j*2, stor_b => -j*5), 0),
                ]
            )
        for (j, k) ∈ enumerate(time_profile)]
        return 𝒱, 𝒩, model
    end

    @testset "Resetting of values" begin
        # Create the cuts
        time_vec = [0, 10, 10, 40, 70]
        𝒱, 𝒩, model = stor_val_cuts(time_vec)

        # Test that the path is correctly created
        # - _find_update_paths(x::StorageValueCuts)
        @test all(issetequal(
            EMRH._find_update_paths(v),
            Any[
                [:time_weight, EMRH.TimeWeightPath()],
                [:cuts, "[1]", :coeffs, "[1]", :element, EMRH.ElementPath()],
                [:cuts, "[1]", :coeffs, "[2]", :element, EMRH.ElementPath()],
                [:cuts, "[2]", :coeffs, "[1]", :element, EMRH.ElementPath()],
                [:cuts, "[2]", :coeffs, "[2]", :element, EMRH.ElementPath()],
            ],
        ) for v ∈ 𝒱)

        # Create the Update type
        𝒰 = EMRH._create_updatetype(model)
        EMRH._add_elements!(𝒰, 𝒩)
        EMRH._add_elements!(𝒰, 𝒱)
        𝒮ⁿ = EMRH.get_sub_elements_vec(𝒰)[1]
        𝒮ᵛ = EMRH.get_sub_elements_vec(𝒰)[2]

        # Test that the correct types are created
        # - Substitution(new::T, org::T, resets::Vector{<:AbstractReset}) where {T<:AbstractElement}
        # - ResetType(field_path::Vector, _::TimeWeightPath, x)
        @test all(typeof(s) == EMRH.FutureValueSub{EMRH.StorageValueCuts} for s ∈ 𝒮ᵛ)
        @test all(typeof(EMRH.resets(s)[1]) == EMRH.TimeWeightReset for s ∈ 𝒮ᵛ)

        # Test that the updates of the values are correctly calculated
        # - _update_future_value!(𝒱::Vector{FutureValueSub{T}}, time::Real) where {T<:StorageValueCuts}
        𝒮ᵛ = convert(Vector{EMRH.FutureValueSub{EMRH.StorageValueCuts}}, 𝒮ᵛ)
        EMRH._update_future_value!(𝒮ᵛ, 0)
        time_weights = [EMRH.resets(s)[1].val for s ∈ 𝒮ᵛ]
        @test all(iszero(tw) for (i, tw) ∈ enumerate(time_weights) if i ∉ [1])
        @test time_weights[1] == 1
        EMRH._update_future_value!(𝒮ᵛ, 80)
        time_weights = [EMRH.resets(s)[1].val for s ∈ 𝒮ᵛ]
        @test all(iszero(tw) for (i, tw) ∈ enumerate(time_weights) if i ∈ [1, 2, 3, 4])
        @test time_weights[5] ≈ 1.0
        EMRH._update_future_value!(𝒮ᵛ, 3)
        time_weights = [EMRH.resets(s)[1].val for s ∈ 𝒮ᵛ]
        @test all(iszero(tw) for (i, tw) ∈ enumerate(time_weights) if i ∉ [1, 2, 3])
        @test time_weights[1] ≈ 0.7
        @test time_weights[2] ≈ 0.3
        @test time_weights[3] ≈ time_weights[2]

        # Test that the `StorageValueCut`s are correctly reset
        # - _update_case_types!(𝒮ᵛ::Vector{<:AbstractSub}, 𝒰::UpdateCase, opers::Vector{<:TS.TimePeriod})
        opers = collect(TwoLevel(1, 12, SimpleTimes(12,1)))
        EMRH._update_case_types!(𝒮ⁿ, 𝒰, opers)
        EMRH._update_case_types!(𝒮ᵛ, 𝒰, opers)
        𝒱ᵣₕ = EMRH.get_future_value(𝒰)
        𝒩ᵣₕ = get_nodes(𝒰)

        # - reset_field(x_rh, res_type::Union{InitReset, TimeWeightReset}, 𝒰::UpdateCase, opers::Vector{<:TS.TimePeriod})
        @test all(iszero(EMRH.time_weight(v)) for v ∈ 𝒱ᵣₕ if v.id ∉ [1,2,3])
        @test EMRH.time_weight(𝒱ᵣₕ[1]) ≈ 0.7
        @test EMRH.time_weight(𝒱ᵣₕ[2]) ≈ 0.3
        @test EMRH.time_weight(𝒱ᵣₕ[3]) ≈ EMRH.time_weight(𝒱ᵣₕ[2])

        # - reset_field(x_rh, res_type::ElementReset, 𝒰::UpdateCase, opers::Vector{<:TS.TimePeriod})
        @test all(rsv ∈ 𝒩ᵣₕ for v ∈ 𝒱ᵣₕ for c ∈ EMRH.cuts(v) for (rsv, coeff) ∈ EMRH.coefficients(c))
        @test all(rsv ∉ 𝒩 for v ∈ 𝒱ᵣₕ for c ∈ EMRH.cuts(v) for (rsv, coeff) ∈ EMRH.coefficients(c))
    end

    @testset "Resetting of values - POI" begin
        # Create the cuts
        time_vec = [0, 10, 10, 40, 70]
        𝒱, 𝒩, model = stor_val_cuts(time_vec)

        # Create the Update type
        𝒰 = EMRH._create_updatetype(model)
        EMRH._add_elements!(𝒰, 𝒩)
        EMRH._add_elements!(𝒰, 𝒱)
        𝒮ⁿ = EMRH.get_sub_elements_vec(𝒰)[1]
        𝒮ᵛ = EMRH.get_sub_elements_vec(𝒰)[2]
        𝒮ᵛ = convert(Vector{EMRH.FutureValueSub{EMRH.StorageValueCuts}}, 𝒮ᵛ)

        # Test that the `StorageValueCut`s are correctly reset
        # - _update_case_types!(m, 𝒮ᵛ::Vector{<:AbstractSub}, 𝒰::UpdateCase, opers::Vector{<:TS.TimePeriod})
        𝒯ᵣₕ = TwoLevel(1,12, SimpleTimes(12,1))
        m = Model(() -> POI.Optimizer(HiGHS.Optimizer()))
        set_optimizer_attribute(m, MOI.Silent(), true)
        EMRH._update_case_types!(m, EMRH.get_sub_model(𝒰), 𝒰, 𝒯ᵣₕ)
        EMRH._update_case_types!(m, 𝒮ᵛ, 𝒰, 𝒯ᵣₕ)
        𝒱ᵣₕ = EMRH.get_future_value(𝒰)

        # - _reset_field(m, x_rh, res_type::Union{InitReset{EMRH.InitDataPath},TimeWeightReset}, 𝒰::UpdateCase, 𝒯ᴿᴴ::TimeStructure)
        @test all(isa(EMRH.time_weight(v), VariableRef) for v ∈ 𝒱ᵣₕ)

        # - _update_parameter!(m, res_type::TimeWeightReset, opers::Vector)
        EMRH._update_future_value!(𝒮ᵛ, 3)
        POIExt._update_parameter_values!(m, 𝒮ᵛ, collect(𝒯ᵣₕ))
        @test all(iszero(parameter_value(EMRH.time_weight(v))) for v ∈ 𝒱ᵣₕ if v.id ∉ [1,2,3])
        @test parameter_value(EMRH.time_weight(𝒱ᵣₕ[1])) ≈ 0.7
        @test parameter_value(EMRH.time_weight(𝒱ᵣₕ[2])) ≈ 0.3
        @test parameter_value(EMRH.time_weight(𝒱ᵣₕ[3])) ≈
            parameter_value(EMRH.time_weight(𝒱ᵣₕ[2]))
    end
end

@testset "Complete modelruns" begin

    init_state = 50
    op_dur_vec = ones(Int64, 24)
    price_profile = [
        10, 20, 20, 50, 95, 100, 105, 100, 50, 40, 40,
        40, 20, 70, 65, 65, 10, 5, 5, 90, 42, 42, 42, 42
    ]
    CO2 = ResourceEmit("CO2", 1.0)
    Power = ResourceCarrier("Power", 0.0)
    products = [CO2, Power]

    𝒯 = TwoLevel(1, 24, SimpleTimes(op_dur_vec))
    hor = PeriodHorizons([duration(t) for t ∈ 𝒯], 8, 4)

    # Create a hydro reservoir
    rsv = RefStorage{RecedingAccumulating}(
        "storage",  # Node ID
        StorCap(FixedProfile(10)), # Charge
        StorCap(FixedProfile(100)), # level, UnionCap
        Power,              # stor_res, stored resource
        Dict(Power => 1),
        Dict(Power => 1),
        [
            StorageInitData(init_state)
        ]
    )
    snk = RefSink(
        "market_sale",
        FixedProfile(0),
        Dict(
            :surplus => OperationalProfile(-price_profile),
            :deficit => FixedProfile(1000)
        ),
        Dict(Power => 1),
        Data[]
    )
    src = RefSource(
        "market_buy",
        FixedProfile(10),
        OperationalProfile(price_profile.+0.01),
        FixedProfile(0),
        Dict(Power => 1),
        Data[]
    )
    𝒩 = [rsv, src, snk]

    # Connect the 𝒩 with ℒ
    ℒ = [
        Direct("rsv-gen", rsv, snk),
        Direct("gen-ocean", src, rsv),
    ]


    𝒱 = [
        StorageValueCuts("wv0", 0, 1, 0,
            [
                StorageValueCut(1, Dict(rsv => -50), 0),
                StorageValueCut(2, Dict(rsv => -40), 250),
                StorageValueCut(3, Dict(rsv => -30), 750),
                StorageValueCut(4, Dict(rsv => -20), 1400),
                StorageValueCut(5, Dict(rsv => -10), 2150),
                StorageValueCut(6, Dict(rsv => -5), 2600),
                StorageValueCut(7, Dict(rsv => 0), 3100),
            ]
        ),
        StorageValueCuts("wv24", 24, 1, 1,
            [
                StorageValueCut(1, Dict(rsv => -100), 0),
                StorageValueCut(2, Dict(rsv => -80), 500),
                StorageValueCut(3, Dict(rsv => -60), 1500),
                StorageValueCut(4, Dict(rsv => -40), 2800),
                StorageValueCut(5, Dict(rsv => -20), 4300),
                StorageValueCut(6, Dict(rsv => -10), 5200),
                StorageValueCut(7, Dict(rsv => 0), 6200),
            ]
        )
    ]

    case = Case(
        𝒯,
        products,
        [𝒩, ℒ, 𝒱],
        [[get_nodes, get_links], [get_future_value]],
        Dict(:horizons => hor)
    )

    model = RecHorOperationalModel(
        Dict(CO2 => FixedProfile(10)), #upper bound for CO2 in t/8h
        Dict(CO2 => FixedProfile(0)), # emission price for CO2 in EUR/t
        CO2,
    )

    # Function for calculating the results in a common format
    function ext_res(res)
        use_src = abs.(round.(filter(r -> r.x1 == src, res[:cap_use])[!, :y]'))
        use_snk = abs.(round.(filter(r -> r.x1 == snk, res[:cap_use])[!, :y]'))
        charge = abs.(round.(
            filter(r -> r.x1 == rsv && r.x3 ==Power, res[:flow_in])[!, :y]'
        ))
        discharge = abs.(round.(
            filter(r -> r.x1 == rsv && r.x3 ==Power, res[:flow_out])[!, :y]'
        ))
        lvl = abs.(round.(filter(r -> r.x1 == rsv, res[:stor_level])[!, :y]'))
        (use_src, use_snk, charge, discharge, lvl)
    end

    # Calculate the results from the complete run to check the future value calculations
    optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)
    m_comp = run_model(case, model, optimizer)
    @test objective_value(m_comp) ≈ 16168.1

    # Test that the value is correctly restricted
    # - create_future_value_couple(m, v::StorageValueCuts, 𝒯, modeltype::RecHorOperationalModel)
    @test all(
        value.(m_comp[:future_value][v]) +
        sum(value.(m_comp[:stor_level][rsv, last(𝒯)]) * coeff for (rsv, coeff) ∈ EMRH.coefficients(svc))
            ≤ value.(EMRH.cut_rhs(svc))
    for v ∈ 𝒱 for svc ∈ EMRH.cuts(v))

    # Test that the objective value is correctly calculated
    # - get_future_value_expression(m, 𝒱::Vector{StorageValueCuts}, 𝒯ᴵⁿᵛ::TS.AbstractStratPers, modeltype::EnergyModel)
    t_inv = first(strat_periods(𝒯))
    @test objective_value(m_comp) ≈
        -sum(value.(m_comp[:opex_var][n, t_inv]) for n ∈ 𝒩) * duration_strat(t_inv) +
        sum(value.(m_comp[:future_value][v]) * EMRH.weight(v) * EMRH.time_weight(v) for v ∈ 𝒱)

    # Extract the results in DataFrames format
    res_full_df = EMRH.get_results_df(m_comp)
    res_full = ext_res(res_full_df)

    # Run the model with the standard framework and test that we get the same results
    res_emrh_org_df = run_model_rh(case, model, optimizer);
    res_emrh_org = ext_res(res_emrh_org_df)
    @test all(all(r_f .≈ r_emrh) for (r_f, r_emrh) ∈ zip(res_full, res_emrh_org))

    # Run the model with the POI framework and test that we get the same results
    optimizer = POI.Optimizer(HiGHS.Optimizer())
    res_emrh_poi_df = run_model_rh(case, model, optimizer);
    res_emrh_poi = ext_res(res_emrh_poi_df)
    @test all(all(r_f .≈ r_emrh) for (r_f, r_emrh) ∈ zip(res_full, res_emrh_poi))

end
