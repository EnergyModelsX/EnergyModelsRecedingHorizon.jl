# Runs all examples in the examples environment. This file is started in a separate process
# by `test_examples.jl` and is not part of the test environment.
using Test
using Pkg

# Prepare the examples environment before loading DataFrames and JuMP from it
exdir = joinpath(@__DIR__, "..", "examples")
Pkg.develop(path = joinpath(@__DIR__, ".."))
Pkg.instantiate()

using DataFrames
using JuMP

@testset "Run examples" begin
    files = filter(endswith(".jl"), readdir(exdir))
    for file ∈ files
        @testset "Example $file" begin
            @info "Run example $file"
            include(joinpath(exdir, file))
            @test all(res_emrh[:opt_status].y .== MOI.OPTIMAL)
        end
    end
end
