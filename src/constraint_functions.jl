

function EMB.constraints_capacity_installed(m,
    n::EMB.Node,
    𝒯::TimeStructure,
    modeltype::RecHorOperationalModel)

    # println("EMRH.CONSTRAINTS CAPACITY INSTALLED RUNNING \n\n")

    # May optimize code for speed (this does not create any extra rows in the optimization problem).
    # However, e.g. print(model) does not work with this. Set optimize_speed = false "for users that just want everything to work"
    optimize_speed = false
    if optimize_speed
        MOI.set(model, POI.ConstraintsInterpretation(), POI.ONLY_BOUNDS)
    end

    # Fix the installed capacity to the upper bound
    for t ∈ 𝒯
        # fix(m[:cap_inst][n, t], capacity(n, t); force=true) #fix does not work with POI
        @constraint(m, m[:cap_inst][n, t] == capacity(n, t))
        # @constraint(m, m[:cap_inst][n, t] == EMB.capacity(m,n, t))
        # @constraint(m, m[:cap_use][n, t] <= EMB.capacity(n,t))

        # println("For $t we have capacity(n, t) = $(capacity(n, t)) for n $(n)")
    end

    if optimize_speed
        MOI.set(model, POI.ConstraintsInterpretation(), POI.ONLY_CONSTRAINTS) #can set other constraints again now
    end
    # println("EMRH.CONSTRAINTS CAPACITY INSTALLED FINISHED \n\n")
end

function EMB.constraints_capacity_installed(m, n::Storage, 𝒯::TimeStructure, modeltype::RecHorOperationalModel)
    #dummy "fix" until we generalize EMRH with POI to include Storage.
    dummy_modeltype_dispatch = OperationalModel(
        modeltype.emission_limit,
        modeltype.emission_price,
        modeltype.co2_instance,
    )
    EMB.constraints_capacity_installed(m, n, 𝒯, dummy_modeltype_dispatch)
end
