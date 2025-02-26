@testset "New node with two fields" begin
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
