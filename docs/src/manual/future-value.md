# [Future value](@id man-fv)

The receeding horizon framework optimizes multiple sequential periods, where the outgoing state of previous period is used as the initial state of the next period.
Receeding horizon can be useful to break down and complex optimization problem into multiple smaller.
However, the value of the outgoing state and the end of each individual optimization problem should also be accounted for, in particular for large scale storages. For a more detailed explanation of the concept storage end value we refer to [Aaslid2021](@cite).
A new `AbstractElement`, [`FutureValue`](@ref), has been implemented to be able to include additional terms to the objective without adding new nodes to the model.
The composite type [`StorageValueCuts`](@ref) can be used to describe the value of storages at the end of the optimization period as multiple cutting hyperplanes that depends on one or several of the outgoing state variables. For more details about the generation of cuts in stochastic dual dynamic programming we refer to [Dowson2020](@cite).

## [Mathematical description](@id man-fv-math)

A [`StorageValueCuts`](@ref) object includes a `weight`, a `time` and a `Vector{StorageValueCut}`.
The `weight` indicates the factor of the specific `StorageValueCuts` in the objective function.
Cuts are often combined with discrete markov states such that the resulting storage end value is a weighted sum of several different `StorageValueCuts`.
The `time` indicates at which time the `StorageValueCuts` are valid at relative to the start time of the optimization.
For example, if we consider an optimization with 168 hours duration then we will use the `StorageValueCuts` where the `time` is 168 to valuate the storage at the end of the optimization.
If there only exist cuts at time 160 and 176, we will use a weighted sum of these to cuts as the end value.

Let ``\texttt{future\_value}`` denote the future value of storages in a system given by `StorageValueCuts`, then multiple [`StorageValueCut`](@ref) bounds the value of ``\texttt{future\_value}`` with multiple linear cutting hyperplanes:

```math
\begin{aligned}
    \sum_{s \in S} coefficients(c) \times \texttt{stor\_level}[s,t_{end}] + \texttt{future\_value}[v] \leq cut\_rhs(c) \qquad \forall c \in \mathcal{C}_v, v \in \mathcal{V}
\end{aligned}
```

where ``v ∈ V`` denotes the set of all active `StorageValueCuts` for a given model, ``C_v`` the set of cuts in ``v`` and, ``S`` the individual [`Storage`](@extref EnergyModelsBase nodes-storage) nodes which are included for the given cut.

The following terms are added to objective:

```math
\begin{aligned}
    \sum_{v \in \mathcal{V}} weight(v) \times time\_weight_{v} \times \texttt{future\_value}[v]
\end{aligned}
```

Let ``t_{end}`` denote the end time of the optimization relative to the start time.
Let ``t_{down}`` and ``t_{up}`` denote the time of the cut(s) nearest to ``t_{end}`` in either directions, and ``v_{down}`` and ``v_{up}`` the corresponding `StorageValueCuts`.
The ``time\_weight_{v}`` can be expressed as weighting between the cuts above and below ``t_{end}``:

```math
\begin{aligned}
    time\_weight_{v_{down}} = 1 - \frac{t_{end} - t_{down}}{t_{up} - t_{down}} \\
    time\_weight_{v_{up}} = 1 - time\_weight_{v_{down}}
\end{aligned}
```
