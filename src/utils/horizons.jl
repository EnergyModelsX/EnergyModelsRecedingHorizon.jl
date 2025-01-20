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
