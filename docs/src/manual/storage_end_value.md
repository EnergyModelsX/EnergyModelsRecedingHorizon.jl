# [Storage end values](@id man-sev)

A new `AbstractElement`, [`FutureValue`](@ref), has been implemented to be able to include additional terms to the objective without adding new nodes to the model.
The composite type [`StorageValueCuts`](@ref) can be used to describe the value of storages at the end of the optimization period as multiple cutting hyperplanes that depend on one or several of the outgoing state variables.
For more details about the generation of cuts in stochastic dual dynamic programming we refer to [Dowson2020](@cite).

## [Arguments for `StorageValueCuts`](@id man-sev-args)

A [`StorageValueCuts`](@ref) object includes a `weight`, a `time` and a `Vector{StorageValueCut}`.
The `weight` indicates the factor of the respective `StorageValueCuts` in the objective function.
Cuts are often combined with discrete Markov states such that the resulting storage end value is a weighted sum of several different `StorageValueCuts`.
The `time` indicates at which time the `StorageValueCuts` are valid relative to the start time of the optimization problem in a given receding horizon iteration.

Each [`StorageValueCut`](@ref) object is defined by a set of coefficients `coeffs`, and a constant `rhs`.
The `coeffs` can be defined by a dictionary with keys ``s`` and values ``w_s``, where ``s`` denotes a given [`Storage`](@extref EnergyModelsBase nodes-storage) node for which the cut refers to, and ``w_s`` denotes the coefficient for the given cut.

## [Mathematical description](@id man-sev-math)

Let ``\texttt{future\_value}`` denote the future value of storages in a system given by `StorageValueCuts`.
Multiple [`StorageValueCut`](@ref) elements bound the value of ``\texttt{future\_value}`` with linear cutting hyperplanes:

```math
\begin{aligned}
    \texttt{future\_value}[v] + \sum_{s, w_s} w_s \times \texttt{stor\_level}[s,t_{end}] \leq cut\_rhs(c) \qquad \forall c \in C_v, v \in V
\end{aligned}
```

where ``v ∈ V`` denotes the set of all active `StorageValueCuts` for a given model,
``C_v`` the set of cuts in ``v``,
``c`` represents each `StorageValueCut` in ``v``,
and ``(s, w_s)`` represents the set of coefficients for ``c`` in the `coeffs` field.

The following terms are added to objective:

```math
\begin{aligned}
    \sum_{v \in V} weight(v) \times time\_weight(v) \times \texttt{future\_value}[v]
\end{aligned}
```

The term ``weight(v)`` refers to a constant weight defined for the [`StorageValueCuts`](@ref) element (field `weight`).
The term ``time\_weight(v)`` is updated for every [`StorageValueCuts`](@ref) element along the receding horizon iterations.
The only non-zero weights will be related to [`StorageValueCuts`](@ref) closest in time to the current optimization end time.

For example, consider a receding horizon iteration for which the optimization problem ends at 168 time units after the full problem's first operational period.
If there exists one or multiple `StorageValueCuts` objects where `time` is 168, we use these `StorageValueCuts` to valuate the storage at the end of the iteration.
Otherwise, if the closest `StorageValueCuts` in both directions are defined at times 160 and 180, we will use a weighted sum of these to cuts as the end value.
Currently, a `StorageValueCuts` must be added for `time` = 0.

Let ``t_{end}`` denote the end time of the optimization relative to the start time.
Let ``t_{down}`` and ``t_{up}`` denote the time of the cut(s) nearest to ``t_{end}`` in either directions, and ``v_{down}`` and ``v_{up}`` the corresponding `StorageValueCuts`.
The value of ``time\_weight(v)`` can be expressed as weighting between the cuts above and below ``t_{end}``:

```math
\begin{aligned}
    time\_weight(v_{down}) = 1 - \frac{t_{end} - t_{down}}{t_{up} - t_{down}} \\
    time\_weight(v_{up}) = 1 - time\_weight(v_{down})
\end{aligned}
```
