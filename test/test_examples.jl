
@testset "Dummy numerical examples" begin
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
            StorCapOpexVar(FixedProfile(100), FixedProfile(0)), # rate_cap, opex_var
            StorCapOpexFixed(FixedProfile(1.5), FixedProfile(0)), # stor_cap, opex_fixed
            power, # stor_res::T
            Dict(power => 1), # input::Dict{<:Resource, <:Real}
            Dict(power => 1), # output::Dict{<:Resource, <:Real}
            Vector([
                StorageInitData(0.5),
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
        Direct("av-storage", nodes[1], nodes[3], Linear()),
        Direct("av-demand", nodes[1], nodes[4], Linear()),
        Direct("source-av", nodes[2], nodes[1], Linear()),
        Direct("storage-av", nodes[3], nodes[1], Linear()),
    ]

    case = Dict(
        :nodes => nodes, :links => links, :products => products, :T => T,
        :horizons => hor,
    )

    optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)

    m_EMB = run_model(case, model, optimizer)
    @test termination_status(m_EMB) == MOI.OPTIMAL

    results_EMRH = run_model_rh(case, model, optimizer)
    @test filter(r -> r.x1 == case[:nodes][3], results_EMRH[:stor_level])[!, :y] ==
          [1.5, 0, 1.5, 0, 0]
    @test filter(r -> r.x1 == case[:nodes][4] && r.x3 == power,
        results_EMRH[:flow_in])[!,:y] ==
          [3.0, 4.0, 5.0, 6.0, 3.0]
    @test filter(r -> r.x1 == case[:nodes][2] && r.x3 == power,
        results_EMRH[:flow_out])[!,:y] == [3.5, 3.5, 5.375, 5.25, 3.0]

    results_EMB = EMRH.get_results_df(m_EMB)
    @test filter(r -> r.x1 == case[:nodes][2] && r.x3 == power,
        results_EMB[:flow_out])[!,:y] ==
          filter(r -> r.x1 == case[:nodes][2] && r.x3 == power,
        results_EMRH[:flow_out])[!,:y]
    @test filter(r -> r.x1 == case[:nodes][3], results_EMB[:stor_level])[!, :y] ==
          filter(r -> r.x1 == case[:nodes][3], results_EMRH[:stor_level])[!, :y]
    @test filter(r -> r.x1 == case[:nodes][4] && r.x3 == power,
        results_EMB[:flow_in])[!,:y] ==
          filter(r -> r.x1 == case[:nodes][4] && r.x3 == power,
        results_EMRH[:flow_in])[!,:y]

    @test case[:nodes][3].data[1].init_val_dict[:stor_level] == 0.5 # StorageInitData object unchanged

    @testset "Save JuMP model as csv" begin
        save_dir = mktempdir(pwd())
        EMRH.save_results(m_EMB; directory = save_dir)
        @test all(
            isfile(joinpath(save_dir, "$var.csv")) for
            var ∈ keys(object_dictionary(m_EMB)) if
            !isempty(m_EMB[var]) && !isa(m_EMB[var], VariableRef)
        )
    end
    @testset "Save EMRH results as csv" begin
        save_dir = mktempdir(pwd())
        EMRH.save_results(results_EMRH; directory = save_dir)
        @test all(
            isfile(joinpath(save_dir, "$var.csv")) for
            var ∈ keys(results_EMRH) if !isempty(results_EMRH[var])
        )
    end
end

ENV["EMX_TEST"] = true # Set flag for example scripts to check if they are run as part of the tests
@testset "Run examples folder" begin
    exdir = joinpath(@__DIR__, "..", "examples")
    files = filter(endswith(".jl"), readdir(exdir))
    for file ∈ files
        if file != "mwe_storage_user.jl"  #mwe_new_node.jl does not work due to EMB version
            continue
        end
        @testset "Example $file" begin
            redirect_stdio(stdout = devnull, stderr = devnull) do
                include(joinpath(exdir, file))
            end
            @test termination_status(m) == MOI.OPTIMAL # not a good test flag for EMRH
        end
    end
    Pkg.activate(@__DIR__)
end
