@testset "Run new node" begin
    optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)
    struct SampleInitNode{T<:Real} <: EMB.Node
        id::Any
        increment::T
        data::Vector{<:Data}
    end

    EMB.has_input(n::SampleInitNode) = false
    EMB.has_output(n::SampleInitNode) = false

    function EMB.variables_node(
        m,
        𝒩ˢᵘᵇ::Vector{<:SampleInitNode},
        𝒯,
        modeltype::EnergyModel,
    )
        @variable(m, state[𝒩ˢᵘᵇ, 𝒯])
    end

    function EMB.create_node(m, n::SampleInitNode, 𝒯, 𝒫, modeltype::EnergyModel)
        for data ∈ node_data(n)
            constraints_data(m, n, 𝒯, 𝒫, modeltype, data)
        end
        constraints_state(m, n, 𝒯, modeltype)
        constraints_extravars(m, n, 𝒯, modeltype)
    end

    function constraints_extravars(
        m,
        n::SampleInitNode,
        𝒯::TimeStructure,
        modeltype::EnergyModel,
    )
        𝒯ᴵⁿᵛ = strategic_periods(𝒯)
        @constraint(m, [t_sp ∈ 𝒯ᴵⁿᵛ], m[:opex_var][n, t_sp] == 0)
        @constraint(m, [t ∈ 𝒯], m[:cap_use][n, t] == 0)
        @constraint(m, [t ∈ 𝒯], m[:cap_inst][n, t] == 0)
        @constraint(m, [t_sp ∈ 𝒯ᴵⁿᵛ], m[:opex_fixed][n, t_sp] == 0)
    end

    function constraints_state(m, n::SampleInitNode, 𝒯, modeltype::EnergyModel)
        for (t_prev, t) ∈ withprev(𝒯)
            isnothing(t_prev) && continue
            @constraint(m, m[:state][n, t] == m[:state][n, t_prev] + n.increment)
        end
    end

    function EMB.constraints_data(
        m,
        n::SampleInitNode,
        𝒯,
        𝒫,
        modeltype::EMRH.RecHorEnergyModel,
        data::InitData,
    )
        @constraint(m, m[:state][n, first(𝒯)] == data.val + n.increment)
    end

    function EMRH.get_init_state(m, n::SampleInitNode, 𝒯_rh, 𝒽)
        t_impl = collect(𝒯_rh)[length(indices_implementation(𝒽))]
        level_t = value.(m[:state][n, t_impl])
        return RefInitData(level_t)
    end

    T = TwoLevel(1, 1, SimpleTimes([1, 2, 1, 4, 1, 3, 1, 3]))
    hor = DurationHorizons([duration(t) for t ∈ T], 8, 4)
    co2 = ResourceEmit("co2", 1.0)
    case = Dict(
        :nodes => [SampleInitNode("init node", 1.5, Vector([RefInitData(1.0)]))],
        :links => Vector{Direct}([]),
        :products => [co2],
        :T => T,
        :horizons => hor,
    )

    model = RecHorOperationalModel(
        Dict(co2 => FixedProfile(10)),
        Dict(co2 => FixedProfile(0)),
        co2,
    )

    m = EMB.create_model(case, model)
    set_optimizer(m, optimizer)
    optimize!(m)

    results_full = Dict(k => value.(m[k]) for k ∈ keys(object_dictionary(m)))
    results_EMRH = run_model_rh(case, model, optimizer)

    @test results_EMRH[:state].data[1] == 2.5
    @test results_EMRH[:state].data[8] == 13.0
    @test results_full[:state].data == results_EMRH[:state].data
end
