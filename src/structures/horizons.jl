struct TakeHorizon{I}
    xs::I
    duration::Int64
end
take_horizon(xs, dur) = TakeHorizon(xs, dur)

Base.IteratorSize(::Type{<:TakeHorizon}) = Base.SizeUnknown()
Base.eltype(::Type{TakeHorizon{I}}) where {I} = Int64
Base.IteratorEltype(::Type{TakeHorizon{I}}) where {I} = Base.IteratorEltype(I)

function Base.iterate(it::TakeHorizon, state = (it.duration,))
    dur, rest = state[1], Base.tail(state)
    dur <= 0 && return nothing
    y = iterate(it.xs, rest...)
    y === nothing && return nothing
    return y[2] - 1, (dur - y[1], y[2])
end

"""
    AbstractHorizons{T<:Real}

Abstract supertype for the individual composite types that can be used for passing the
required parameters for a receding horizon optimization.
"""
abstract type AbstractHorizons{T<:Real} end
Base.show(io::IO, w::AbstractHorizons) = print(io, "horizons_$(w.len)_$(w.optim)_$(w.impl)")

"""
    PeriodHorizons{T} <: AbstractHorizons{T}

Type used for specifiying the optimization and implementation horizon of a receding horizon
model as multiples of the number of periods.

Iterating a `PeriodHorizons` results in `SingleHorizon` which includes all information
required for a single run.

# Fields
- **`len::Int64`** is the total length of the investigated timeframe as a multiple of the
  duration of 1 of an operational period.
- **`dur::Vector{T}`** is a vector of the duration of each individual operational period.
- **`optim::Int64`** is the **_number_** of operational periods that are used in the
  **_optimization_** horizon.
- **`impl::Int64`** is the **_number_** of operational periods that are used in the
  **_implementation_** horizon.

!!! note "Optimization and implementation horizon"
    The optimization horizon corresponds to the horizon used in each individual optimization
    run while the implementation horizon must be shorter than the optimization horizon.
    This is enforced through an inner constructor.
    It corresponds to the operational periods extracted from the model run.
"""
struct PeriodHorizons{T} <: AbstractHorizons{T}
    len::Int64
    dur::Vector{T}
    optim::Int64
    impl::Int64
    function PeriodHorizons(
        len::Int64, dur::Vector{T}, optim::Int64, impl::Int64,
    ) where {T<:Real}
        if optim < impl
            throw(
                ArgumentError(
                    "The optimization horizon ($(optim)) cannot be shorter than the " *
                    "implementation horizon ($(impl)).",
                ),
            )
        elseif length(dur) < impl
            throw(
                ArgumentError(
                    "The duration vector ($(length(dur))) cannot be shorter than the " *
                    "implementation horizon ($(impl)).",
                ),
            )
        else
            new{T}(len, dur, optim, impl)
        end
    end
end
"""
    PeriodHorizons(len::Int64, dur::Real, optim::Int64, impl::Int64)

Constructor for a `PeriodHorizons{T}` in which the duration is the same in all operational
periods. The field `len` mmust be a multiple of the field `dur`.
"""
function PeriodHorizons(len::Int64, dur::Real, optim::Int64, impl::Int64)
    if len % dur == 0
        return PeriodHorizons(len, fill(dur, Integer(len / dur)), optim, impl)
    else
        throw(ArgumentError("The field `len` must be a multiple of the field `dur`"))
    end
end
"""
    PeriodHorizons(dur::Vector{T}, optim::Int64, impl::Int64) where {T<:Real}

Constructor for a `PeriodHorizons{T}` in which the field `len` is calculated from the sum
of the vector `dur{T}`.
"""
function PeriodHorizons(dur::Vector{T}, optim::Int64, impl::Int64) where {T<:Real}
    if sum(dur) % 1 ≠ 0
        throw(ArgumentError("The vector `dur` must sum up to an integer."))
    else
        return PeriodHorizons(Integer(sum(dur)), dur, optim, impl)
    end
end

Base.length(w::PeriodHorizons) = Integer(ceil(length(w.dur) / w.impl))
Base.eltype(::Type{PeriodHorizons{T}}) where {T} = SingleHorizon{T}

"""
    DurationHorizons{T} <: AbstractHorizons{T}

Type used for specifiying the optimization and implementation horizon of a receding horizon
model as the duration of the horizons. This implies that the number of operational periods
in the different iterations can vary.

Iterating a `DurationHorizons` results in `SingleHorizon` which includes all information
required for a single run.

# Fields
- **`len::Int64`** is the total length of the investigated timeframe as a multiple of the
  duration of 1 of an operational period.
- **`dur::Vector{T}`** is a vector of the duration of each individual operational period.
- **`optim::Int64`** is the sum of the **_duration_** of the operational periods that are
  used in the **_optimization_** horizon.
- **`impl::Int64`** is the sum of the **_duration_** of the operational periods that are
  used in the **_implementation_** horizon.

!!! note "Optimization and implementation horizon"
    The optimization horizon corresponds to the horizon used in each individual optimization
    run while the implementation horizon must be shorter than the optimization horizon.
    This is enforced through an inner constructor.
    It corresponds to the operational periods extracted from the model run.
"""
struct DurationHorizons{T} <: AbstractHorizons{T}
    len::Int64
    dur::Vector{T}
    optim::Int64
    impl::Int64
    function DurationHorizons(
        len::Int64, dur::Vector{T}, optim::Int64, impl::Int64,
    ) where {T<:Real}
        if optim < impl
            throw(
                ArgumentError(
                    "The optimization horizon ($(optim)) cannot be shorter than the " *
                    "implementation horizon ($(impl)).",
                ),
            )
        elseif length(dur) < impl
            throw(
                ArgumentError(
                    "The duration vector ($(length(dur))) cannot be shorter than the " *
                    "implementation horizon ($(impl)).",
                ),
            )
        else
            new{T}(len, dur, optim, impl)
        end
    end
end
"""
    DurationHorizons(len::Int64, dur::Real, optim::Int64, impl::Int64)

Constructor for a `DurationHorizons{T}` in which the duration is the same in all operational
periods. The field `len` mmust be a multiple of the field `dur`.
"""
function DurationHorizons(len::Int64, dur::Real, optim::Int64, impl::Int64)
    if len % dur == 0
        return DurationHorizons(len, fill(dur, Integer(ceil(len / dur))), optim, impl)
    else
        throw(ArgumentError("The field `len` must be a multiple of the field `dur`"))
    end
end
"""
    DurationHorizons(dur::Vector{T}, optim::Int64, impl::Int64) where {T<:Real}

Constructor for a `DurationHorizons{T}` in which the field `len` is calculated from the sum
of the vector `dur{T}`.
"""
function DurationHorizons(dur::Vector{T}, optim::Int64, impl::Int64) where {T<:Real}
    if sum(dur) % 1 ≠ 0
        throw(ArgumentError("The vector `dur` must sum up to an integer."))
    else
        return DurationHorizons(Integer(sum(dur)), dur, optim, impl)
    end
end

# Base.length(w::DurationHorizons) = Integer(ceil(w.len/w.impl))
function Base.length(w::DurationHorizons)
    tmp = 0
    rng = collect(take_horizon(w.dur, w.impl))
    while sum(w.dur[rng]) ≥ w.impl
        rng = collect(take_horizon(Iterators.rest(w.dur, rng[end] + 1...), w.impl))
        tmp += 1
    end
    return tmp
end
Base.eltype(::Type{DurationHorizons{T}}) where {T} = SingleHorizon{T}

"""
    SingleHorizon{T}

Type created as a result of iterating through an `AbstractHorizons` type. It stores the
required information of each individual optimization.

# Fields
- **`id::Int64`** is an integer corresponding to the number of the type from the iterator.
- **`dur::Vector{T}`** is a vector of the duration of the operational period included in
  the horizon.
- **`idx_optim::Vector{Int64}`** is a vector containing the indices used in the
  **_optimization_** horizon.
- **`idx_impl::Vector{Int64}`** is a vector containing the indices used in the
  **_implementation_** horizon.
  """
struct SingleHorizon{T}
    id::Int64
    dur::Vector{T}
    idx_optim::Vector{Int64}
    idx_impl::Vector{Int64}
    function SingleHorizon(
        ind::Int64, dur::Vector{T}, idx_optim::Vector{Int64}, idx_impl::Vector{Int64},
    ) where {T<:Real}
        if length(dur) ≠ length(idx_optim)
            throw(
                ArgumentError(
                    "The duration vector length ($(length(dur))) has to be equal to the " *
                    "optimization horizon vector length ($(length(idx_optim))).",
                ),
            )
        elseif length(idx_optim) < length(idx_impl)
            throw(
                ArgumentError(
                    "The optimization horizon ($(length(idx_optim))) cannot be shorter than " *
                    "the implementation horizon ($(length(idx_impl))).",
                ),
            )
        elseif !isempty(setdiff(idx_impl, idx_optim))
            throw(
                ArgumentError(
                    "The indices in the implementation horizon have to be included in the " *
                    "indices of the optimization horizon.",
                ),
            )
        else
            new{T}(ind, dur, idx_optim, idx_impl)
        end
    end
end
TS.isfirst(sh::SingleHorizon) = sh.id == 1
Base.length(sh::SingleHorizon) = length(sh.dur)

"""
    durations(single_hor::SingleHorizon)

Extracts the fiels `dur` from the `SingleHorizon` `single_hor` corresponding to a vector of
the durations of the individual time periods.
"""
durations(single_hor::SingleHorizon) = single_hor.dur

"""
    indices_optimization(single_hor::SingleHorizon)

Extracts the fiels `idx_optim` from the `SingleHorizon` `single_hor` corresponding to a vector
of the indices of the **_optimization_** horizon.
"""
indices_optimization(single_hor::SingleHorizon) = single_hor.idx_optim

"""
    indices_implementation(single_hor::SingleHorizon)

Extracts the fiels `idx_impl` from the `SingleHorizon` `single_hor` corresponding to a vector
of the indices of the **_implementation_** horizon.
"""
indices_implementation(single_hor::SingleHorizon) = single_hor.idx_impl
