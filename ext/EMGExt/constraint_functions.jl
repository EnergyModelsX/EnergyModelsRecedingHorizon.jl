function EMG.constraints_trans_balance(m, tm::PipeLinepackSimple, 𝒯::TimeStructure, modeltype::RecHorEnergyModel)
    init_data = EMRH.data_init(tm)
    for (t_prev, t) ∈ withprev(𝒯)
        # Periodicity constraint
        if isnothing(t_prev)
            @constraint(m, m[:linepack_stor_level][tm, t] ==
                           init_data.init_val_dict[:linepack_stor_level] +
                           (m[:trans_in][tm, t] - m[:trans_loss][tm, t] - m[:trans_out][tm, t])
                           * duration(t)
            )
        else # From one operational period to next
            @constraint(m, m[:linepack_stor_level][tm, t] ==
                           m[:linepack_stor_level][tm, t_prev] +
                           (m[:trans_in][tm, t] - m[:trans_loss][tm, t] - m[:trans_out][tm, t])
                           * duration(t)
            )
        end
    end
end
