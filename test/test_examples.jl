
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
                InitStorageData(0.5),
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

    m_EMB = run_model(case, model, optimizer)
    @test termination_status(m_EMB) == MOI.OPTIMAL

    results_EMRH = run_model_rh(case, model, optimizer)
    @test results_EMRH[:stor_level][case[:nodes][3], :].data == [1.5, 0, 1.5, 0, 0]
    @test results_EMRH[:flow_in][case[:nodes][4], :, power].data.vals ==
          [3.0, 4.0, 5.0, 6.0, 3.0]
    @test results_EMRH[:flow_out][case[:nodes][2], :, power].data.vals ==
          [3.5, 3.5, 5.375, 5.25, 3.0]

    results_EMB = EMRH.get_results(m_EMB)
    @test results_EMB[:flow_out][case[:nodes][2], :, power].data.vals ==
          results_EMRH[:flow_out][case[:nodes][2], :, power].data.vals
    @test results_EMB[:stor_level][case[:nodes][3], :].data ==
          results_EMRH[:stor_level][case[:nodes][3], :].data
    @test results_EMB[:flow_in][case[:nodes][4], :, power].data.vals ==
          results_EMRH[:flow_in][case[:nodes][4], :, power].data.vals

    @test case[:nodes][3].data[1].val == 0.5 # InitStorageData object unchanged
end

ENV["EMX_TEST"] = true # Set flag for example scripts to check if they are run as part of the tests
@testset "Run examples folder" begin
    exdir = joinpath(@__DIR__, "..", "examples")
    files = filter(endswith(".jl"), readdir(exdir))
    for file ∈ files
        if file != "mwe_storage_user.jl" #not relevant to test other files
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
