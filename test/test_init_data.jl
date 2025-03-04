@testset "Initial data functionality" begin
    # Create a node with and without initial data
    co2 = ResourceEmit("co2", 1.0)
    el = ResourceCarrier("el", 0.2)
    𝒫 = [el, co2]
    init_data = StorageInitData(10)
    src = RefSource(
        "electricity source",
        FixedProfile(1e12),
        OperationalProfile([10, 40, 60, 10, 50, 20, 5, 60]),
        FixedProfile(0),
        Dict(el => 1),
    )
    stor = RefStorage{RecedingAccumulating}(
        "electricity storage",
        StorCapOpexVar(FixedProfile(40), FixedProfile(0.01)),
        StorCapOpexFixed(FixedProfile(200), FixedProfile(0)),
        el,
        Dict(el => 1),
        Dict(el => 1),
        [init_data],
    )
    snk =  RefSink(
        "electricity demand",
        OperationalProfile([20, 30, 40, 30, 10, 50, 35, 20]),
        Dict(:surplus => FixedProfile(0), :deficit => FixedProfile(1e6)),
        Dict(el => 1),
    )
    𝒩 = [src, stor, snk]
    ℒ = [
        Direct("source-storage", src, stor, Linear()),
        Direct("source-demand", src, snk, Linear()),
        Direct("storage-demand", stor, snk, Linear()),
    ]

    # Test that the functions for init data work
    # - is_init_data(data)
    @test is_init_data(init_data)

    # - has_init(n::EMB.Node)
    @test has_init(stor)
    @test !has_init(src)

    # - has_init(;::Link)
    @test !has_init(ℒ[1])

    # - model_key(idp::InitDataPath)
    field_path = EMRH._find_update_paths(stor)
    @test EMRH.model_key(field_path[1][end]) == :stor_level

    # Create an operational modeltype and the time structure
    modeltype = RecHorOperationalModel(
        Dict(co2 => FixedProfile(100)),
        Dict(co2 => FixedProfile(60)),
        co2,
    )

    # Create the update type
    𝒰 = EMRH._create_updatetype(modeltype)
    EMRH._add_elements!(𝒰, 𝒫)
    EMRH._add_elements!(𝒰, 𝒩)
    EMRH._add_elements!(𝒰, ℒ)
    𝒮ᵛᵉᶜ = EMRH.get_sub_elements_vec(𝒰)
    𝒮ᵛᵉᶜᵢₙ = [filter(has_init, 𝒮) for 𝒮 ∈ 𝒮ᵛᵉᶜ]

    # Explicit test
    # - has_init(n::AbstractSub)
    𝒮ⁿ = 𝒮ᵛᵉᶜ[1]
    @test has_init(𝒮ⁿ[2])
    @test 𝒮ᵛᵉᶜᵢₙ == [[𝒮ⁿ[2]], EMRH.LinkSub[]]
    @test all(!has_init(s_n) for s_n ∈ 𝒮ⁿ[[1, 3]])

    # Create all time related parameters
    𝒯 = TwoLevel(1, 1, SimpleTimes(8, 1))
    opers = collect(𝒯)
    ℋ = PeriodHorizons(ones(8), 4, 2)
    𝒽 = first(ℋ)
    𝒯ᵣₕ = TwoLevel(1, sum(durations(𝒽)), SimpleTimes(durations(𝒽)))
    ind_impl = indices_implementation(𝒽)
    opers_opt = opers[indices_optimization(𝒽)]
    opers_impl = opers[ind_impl]
    opers_implᵣₕ = collect(𝒯ᵣₕ)[1:length(ind_impl)]

    # Update the `UpdateCase` with the new values
    EMRH._update_update_case!(𝒰, opers_opt, 𝒯ᵣₕ)

    # Extract the case and the model from the `UpdateCase`
    caseᵣₕ = Case(𝒯ᵣₕ, get_products(𝒰), get_elements_vec(𝒰))
    modelᵣₕ = EMRH.updated(EMRH.get_sub_model(𝒰))

    # Create and solve model
    m = create_model(caseᵣₕ, modelᵣₕ; check_timeprofiles=true)
    set_optimizer(m, HiGHS.Optimizer)
    set_optimizer_attribute(m, MOI.Silent(), true)
    optimize!(m)

    # Update the value for the initial data
    for 𝒮ᵢₙ ∈ 𝒮ᵛᵉᶜᵢₙ, s_in ∈ 𝒮ᵢₙ
        reset_init = filter(EMRH.is_init_reset, EMRH.resets(s_in))
        for ri ∈ reset_init
            EMRH.update_init_data!(m, ri, EMRH.updated(s_in), ri.path, opers_implᵣₕ)
        end
    end

    # Test that the correct value is replaced in the ResetType
    # - update_init_data!(m, ri::AbstractReset, x::AbstractElement, idp::InitDataPath, opers_implᵣₕ)
    @test 𝒰.elements[1][2].resets[1].val ==
        value.(m[:stor_level][EMRH.updated(𝒰, stor), last(opers_implᵣₕ)])
    @test 𝒰.elements[1][2].resets[1].val ≈ 40.0
end

@testset "Dynamic node with two dynamic states" begin
    optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)
    struct SampleInitNode{T<:Real} <: EMB.Node
        id::Any
        increment::T
        increment2::T
        data::Vector{<:Data}
    end

    function create_case_newnode(init_data)
        𝒯 = TwoLevel(1, 1, SimpleTimes([1, 2, 1, 4, 1, 3, 1, 3]))
        ℋ = DurationHorizons([duration(t) for t ∈ 𝒯], 8, 4)
        𝒩 = [SampleInitNode("init node", 1.5, 0.6, [init_data])]
        co2 = ResourceEmit("co2", 1.0)
        𝒫 = [co2]

        case = Case(𝒯, 𝒫, Vector{Vector}([𝒩]), [Function[]], Dict(:horizons => ℋ))

        model = RecHorOperationalModel(
            Dict(co2 => FixedProfile(10)),
            Dict(co2 => FixedProfile(0)),
            co2,
        )

        return case, model
    end

    EMB.has_input(n::SampleInitNode) = false
    EMB.has_output(n::SampleInitNode) = false
    EMB.has_opex(n::SampleInitNode) = false
    EMB.has_capacity(n::SampleInitNode) = false

    function EMB.variables_node(
        m,
        𝒩ˢᵘᵇ::Vector{<:SampleInitNode},
        𝒯,
        modeltype::EnergyModel,
    )
        @variable(m, state[𝒩ˢᵘᵇ, 𝒯])
        @variable(m, state2[𝒩ˢᵘᵇ, 𝒯])
    end

    function EMB.create_node(m, n::SampleInitNode, 𝒯, 𝒫, modeltype::EnergyModel)
        for data ∈ node_data(n)
            constraints_data(m, n, 𝒯, 𝒫, modeltype, data)
        end
        constraints_state(m, n, 𝒯, modeltype)
    end
    EMB.constraints_couple(m, 𝒫, 𝒯, modeltype::EMRH.RecHorEnergyModel) = nothing

    function constraints_state(m, n::SampleInitNode, 𝒯, modeltype::EnergyModel)
        for (t_prev, t) ∈ withprev(𝒯)
            isnothing(t_prev) && continue
            @constraint(m, m[:state][n, t] == m[:state][n, t_prev] + n.increment)
            @constraint(m, m[:state2][n, t] == m[:state2][n, t_prev] + n.increment2)
        end
    end

    # TODO: should system throw an error if model is run without initialization data?
    case, model = create_case_newnode(InitData(Dict(:state => 1.0, :state2 => 1.3)))
    results_bad = run_model_rh(case, model, optimizer)

    function EMB.constraints_data(
        m,
        n::SampleInitNode,
        𝒯,
        𝒫,
        modeltype::EMRH.RecHorEnergyModel,
        data::InitData,
    )
        @constraint(m, m[:state][n, first(𝒯)] == data.init_val_dict[:state] + n.increment)
        @constraint(
            m,
            m[:state2][n, first(𝒯)] == data.init_val_dict[:state2] + n.increment2
        )
    end

    m = EMB.create_model(case, model)
    set_optimizer(m, optimizer)
    optimize!(m)
    results_full = EMRH.get_results_df(m)

    results_1 = run_model_rh(case, model, optimizer)

    @test results_1[:state].y[1] ≈ 2.5
    @test results_1[:state].y[8] ≈ 13.0
    @test results_full[:state].y ≈ results_1[:state].y
    @test results_1[:state2].y[1] ≈ 1.9
    @test results_1[:state2].y[8] ≈ 6.1
    @test results_full[:state2].y ≈ results_1[:state2].y

    struct CustomInitData <: EMRH.AbstractInitData
        state::Real
        state2::Real
    end

    function EMB.constraints_data(
        m,
        n::SampleInitNode,
        𝒯,
        𝒫,
        modeltype::EMRH.RecHorEnergyModel,
        data::CustomInitData,
    )
        @constraint(m, m[:state][n, first(𝒯)] == data.state + n.increment)
        @constraint(
            m,
            m[:state2][n, first(𝒯)] == data.state2 + n.increment2
        )
    end

    case, model = create_case_newnode(CustomInitData(1.0, 1.3))

    # Following test should throw before the definitions below it
    @test_throws "function `_find_update_paths(field, current_path, all_path)`" bad_results =
        run_model_rh(case, model, optimizer)

    struct CustomInitDataPath <: EMRH.AbstractInitDataPath
        key::Any
    end

    function EMRH._find_update_paths(
        field::CustomInitData,
        current_path::Vector{Any},
        all_paths::Vector{Any},
    )
        for var_key ∈ [:state, :state2]
            new_path = vcat(current_path, var_key)
            append!(new_path, [CustomInitDataPath(var_key)])
            push!(all_paths, new_path)
        end
    end

    # Following test should throw before the definition below it
    @test_throws MethodError bad_results = run_model_rh(case, model, optimizer)

    function EMRH.update_init_data!(
        m,
        ri::EMRH.AbstractReset,
        x::SampleInitNode,
        idp::CustomInitDataPath,
        opers_implᵣₕ,
    )
        t_last = last(opers_implᵣₕ)
        ri.val = value.(m[idp.key][x, t_last])
    end

    case, model = create_case_newnode(CustomInitData(1.0, 1.3))

    results_2 = run_model_rh(case, model, optimizer)

    @test results_2[:state].y[1] ≈ 2.5
    @test results_2[:state].y[8] ≈ 13.0
    @test results_full[:state].y ≈ results_2[:state].y
    @test results_2[:state2].y[1] ≈ 1.9
    @test results_2[:state2].y[8] ≈ 6.1
    @test results_full[:state2].y ≈ results_2[:state2].y
end
