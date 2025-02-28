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
