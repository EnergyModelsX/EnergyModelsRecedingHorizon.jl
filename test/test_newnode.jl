@testset "New node with two fields" begin
    optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)
    struct SampleInitNode{T<:Real} <: EMB.Node
        id::Any
        increment::T
        increment2::T
        data::Vector{<:Data}
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

    function EMB.constraints_data(
        m,
        n::SampleInitNode,
        𝒯,
        𝒫,
        modeltype::EMRH.RecHorEnergyModel,
        data::AbstractInitData,
    )
        @constraint(m, m[:state][n, first(𝒯)] == data.init_val_dict[:state] + n.increment)
        @constraint(
            m,
            m[:state2][n, first(𝒯)] == data.init_val_dict[:state2] + n.increment2
        )
    end

    function EMRH.get_init_state(m, n::SampleInitNode, 𝒯_rh, 𝒽)
        t_impl = collect(𝒯_rh)[length(indices_implementation(𝒽))]
        level_t = value.(m[:state][n, t_impl])
        level_t2 = value.(m[:state2][n, t_impl])
        return InitData(Dict(:state => level_t, :state2 => level_t2))
    end

    𝒯 = TwoLevel(1, 1, SimpleTimes([1, 2, 1, 4, 1, 3, 1, 3]))
    ℋ = DurationHorizons([duration(t) for t ∈ 𝒯], 8, 4)
    𝒩 = [SampleInitNode("init node", 1.5, 0.6, [InitData(Dict(:state => 1.0, :state2 => 1.3))])]
    co2 = ResourceEmit("co2", 1.0)
    𝒫 = [co2]

    case = Case(𝒯, 𝒫, Vector{Vector}([𝒩]), [Function[]], Dict(:horizons => ℋ))

    model = RecHorOperationalModel(
        Dict(co2 => FixedProfile(10)),
        Dict(co2 => FixedProfile(0)),
        co2,
    )

    m = EMB.create_model(case, model)
    set_optimizer(m, optimizer)
    optimize!(m)

    results_full = EMRH.get_results_df(m)
    results_EMRH = run_model_rh(case, model, optimizer)

    @test results_EMRH[:state].y[1] ≈ 2.5
    @test results_EMRH[:state].y[8] ≈ 13.0
    @test results_full[:state].y ≈ results_EMRH[:state].y
    @test results_EMRH[:state2].y[1] ≈ 1.9
    @test results_EMRH[:state2].y[8] ≈ 6.1
    @test results_full[:state2].y ≈ results_EMRH[:state2].y
end
