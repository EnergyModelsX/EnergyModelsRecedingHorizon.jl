# Function for calculating the individual ranges
_take_range(itr::PeriodHorizons, _::Integer, _::Nothing) = (1:(itr.optim), 1:(itr.impl), 1)
function _take_range(itr::PeriodHorizons, _::Integer, state)
    rng_optim =
        ((state*itr.impl)+1):minimum([(state * itr.impl) + itr.optim, length(itr.dur)])
    rng_impl =
        ((state*itr.impl)+1):minimum([(state * itr.impl) + itr.impl, length(itr.dur)])
    return rng_optim, rng_impl, state + 1
end

function _take_range(itr::DurationHorizons, _::Integer, _::Nothing)
    rng_optim = collect(take_horizon(itr.dur, itr.optim))
    rng_impl = collect(take_horizon(itr.dur, itr.impl))
    return rng_optim, rng_impl, 1
end
function _take_range(itr::DurationHorizons, init::Integer, state)
    rng_optim = collect(take_horizon(Iterators.rest(itr.dur, init...), itr.optim))
    rng_impl = collect(take_horizon(Iterators.rest(itr.dur, init...), itr.impl))
    return rng_optim, rng_impl, state + 1
end

# Function for defining the individual SingleHorizon when interating through an AbstractHorizons
function Base.iterate(itr::AbstractHorizons, state = (1, nothing))
    state[2] === length(itr) && return nothing
    rng_optim, rng_impl, next = _take_range(itr, state[1], state[2])
    horizon = SingleHorizon(next, itr.dur[rng_optim], collect(rng_optim), collect(rng_impl))
    return horizon, (rng_impl[end] + 1, next)
end

"""
    optimization_time_ref(𝒯, 𝒽)

Returns an array of time references for the receding horizon optimization problem. The full
problem is defined by `𝒯`, and the horizon is defined by `𝒽`.
"""
function optimization_time_ref(𝒯, 𝒽)
    # TODO: not optimal to create array according to Julian, but a better solution was not found
    𝒯_vec = collect(𝒯)
    return 𝒯_vec[indices_optimization(𝒽)]
end
