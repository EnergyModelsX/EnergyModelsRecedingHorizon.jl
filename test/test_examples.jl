
@testset "Dummy numerical examples" begin
    power = ResourceCarrier("power", 0.0)
    co2 = ResourceEmit("co2", 1.0)
    𝒫 = [power, co2]

    𝒯 = TwoLevel(1, 1, SimpleTimes([2, 3, 4, 2, 1]))
    ℋ = PeriodHorizons([duration(t) for t ∈ 𝒯], 2, 1)

    model = RecHorOperationalModel(
        Dict(co2 => FixedProfile(10)), Dict(co2 => FixedProfile(0)), co2,
    )

    𝒩 = [
        GenAvailability("Availability", 𝒫),
        RefSource(
            "electricity source", # id
            FixedProfile(1e12), # cap
            OperationalProfile([10, 100, 10, 100, 10]), # opex_var
            FixedProfile(0), # opex_fixed
            Dict(power => 1), # output
        ),
        RefStorage{RecedingAccumulating}(
            "electricity storage", # id
            StorCapOpexVar(FixedProfile(1.5), FixedProfile(1)), # rate_cap, opex_var
            StorCapOpexFixed(FixedProfile(5), FixedProfile(0)), # stor_cap, opex_fixed
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

    ℒ = [
        Direct("av-storage", 𝒩[1], 𝒩[3], Linear()),
        Direct("av-demand", 𝒩[1], 𝒩[4], Linear()),
        Direct("source-av", 𝒩[2], 𝒩[1], Linear()),
        Direct("storage-av", 𝒩[3], 𝒩[1], Linear()),
    ]

    case = Case(𝒯, 𝒫, [𝒩, ℒ], [[get_nodes, get_links]], Dict(:horizons => ℋ))

    optimizer = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)

    m_EMB = run_model(case, model, optimizer)
    @test termination_status(m_EMB) == MOI.OPTIMAL

    results_EMRH = run_model_rh(case, model, optimizer)
    @test filter(r -> r.x1 == 𝒩[3], results_EMRH[:stor_level])[!, :y] ==
        [3.5, 0, 5.0, 0, 0]
    @test filter(r -> r.x1 == 𝒩[4] && r.x3 == power, results_EMRH[:flow_in])[!,:y] ==
        [3.0, 4.0, 5.0, 6.0, 3.0]
    @test filter(r -> r.x1 == 𝒩[2] && r.x3 == power, results_EMRH[:flow_out])[!,:y] ≈
        [4.5, 17/6, 6.25, 3.5, 3.0]

    results_EMB = EMRH.get_results_df(m_EMB)
    @test filter(r -> r.x1 == 𝒩[2] && r.x3 == power, results_EMB[:flow_out])[!,:y] ≈
        filter(r -> r.x1 == 𝒩[2] && r.x3 == power, results_EMRH[:flow_out])[!,:y]
    @test filter(r -> r.x1 == 𝒩[3], results_EMB[:stor_level])[!, :y] ≈
        filter(r -> r.x1 == 𝒩[3], results_EMRH[:stor_level])[!, :y]
    @test filter(r -> r.x1 == 𝒩[4] && r.x3 == power, results_EMB[:flow_in])[!,:y] ≈
        filter(r -> r.x1 == 𝒩[4] && r.x3 == power, results_EMRH[:flow_in])[!,:y]

    @test 𝒩[3].data[1].init_val_dict[:stor_level] == 0.5 # StorageInitData object unchanged

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
        @testset "Example $file" begin
            redirect_stdio(stdout = devnull, stderr = devnull) do
                include(joinpath(exdir, file))
            end
            @test true # not a good test flag for EMRH
        end
    end
    Pkg.activate(@__DIR__)
end
