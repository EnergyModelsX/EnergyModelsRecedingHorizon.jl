"""
    abstract type AbstractPath

Supertype for identification of the type which is resetted by a lens.
"""
abstract type AbstractPath end

"""
    abstract type AbstractInitDataPath <: AbstractPath

Supertype for identification of the [`AbstractPath`](@ref) types that are used for initial
data. If you create a new [`AbstractInitData`](@ref) type, you must also create a new
`AbstractInitDataPath` subtype
"""
abstract type AbstractInitDataPath <: AbstractPath end

"""
    struct OperPath <: AbstractPath

Internal type for paths pointing towards operational profiles.
"""
struct OperPath <: AbstractPath end

"""
    struct ElementPath <: AbstractPath

Internal type for paths pointing towards nodes.
"""
struct ElementPath <: AbstractPath end

"""
    struct InitDataPath <: AbstractPath

Internal type for paths pointing towards [`InitData`](@ref).

# Fields
- **`key::Symbol`** is the key in the [`InitData`](@ref) (and correspondingly in the JuMP
  model).
"""
struct InitDataPath <: AbstractInitDataPath
    key::Symbol
end


abstract type AbstractReset end
mutable struct ElementReset <: AbstractReset
    lens::Union{PropertyLens,ComposedFunction}
    val::EMB.Node
    function ElementReset(field, x::AbstractElement)
        lens = _create_lens_for_field(field)
        val = lens(x)
        new(lens, val)
    end
end

mutable struct OperReset <: AbstractReset
    lens::Union{PropertyLens,ComposedFunction}
    var
    val::OperationalProfile
    function OperReset(field, x::AbstractElement)
        lens = _create_lens_for_field(field)
        val = lens(x)
        new(lens, nothing, val)
    end
end

mutable struct InitReset <: AbstractReset
    lens::Union{PropertyLens,ComposedFunction}
    path
    var
    val
    function InitReset(field, path, x::AbstractElement)
        lens = _create_lens_for_field(field)
        val = lens(x)
        new(lens, path, nothing, val)
    end
end

ResetType(field_id, path::AbstractInitDataPath, x) = InitReset(field_id, path, x)
ResetType(field_id, _::OperPath, x) = OperReset(field_id, x)
ResetType(field_id, _::ElementPath, x) = ElementReset(field_id, x)


abstract type AbstractSub end

has_init(s::AbstractSub) = has_init(s.reference)
mutable struct ModelSub{T<:RecHorEnergyModel} <: AbstractSub
    new::T
    reference::T
    reset::Vector{<:AbstractReset}
end
Substitution(new::T, ref::T, reset::Vector{<:AbstractReset}) where {T<:RecHorEnergyModel} =
    ModelSub(new, ref, reset)

mutable struct ProductSub{T<:Resource} <: AbstractSub
    new::T
    reference::T
    reset::Vector{<:AbstractReset}
end
Substitution(new::T, ref::T, reset::Vector{<:AbstractReset}) where {T<:Resource} =
    ProductSub(new, ref, reset)

mutable struct NodeSub{T<:EMB.Node} <: AbstractSub
    new::T
    reference::T
    reset::Vector{<:AbstractReset}
end

mutable struct LinkSub{T<:Link} <: AbstractSub
    new::T
    reference::T
    reset::Vector{<:AbstractReset}
end

Substitution(new::T, ref::T, reset::Vector{<:AbstractReset}) where {T<:AbstractElement} =
    _ele_to_sub(T)(new, ref, reset)
_ele_to_sub(::Type{<:EMB.Node}) = NodeSub
_ele_to_sub(::Type{<:Link}) = LinkSub

Substitution(x::T, reset::Vector{<:AbstractReset}) where {T} = Substitution(x, x, reset)

mutable struct UpdateType
    model::ModelSub
    opers::Dict
    products::Vector{<:ProductSub}
    elements::Vector{Vector}
end

function update_to_case(𝒰::UpdateType)
    𝒳ᵛᵉᶜ = Vector[]
    for 𝒮 ∈ 𝒰.elements
        𝒳 = [s.new for s ∈ 𝒮]
        isempty(𝒳) || push!(𝒳ᵛᵉᶜ, 𝒳)
    end
    return 𝒳ᵛᵉᶜ
end
get_sub_elements_vec(𝒰::UpdateType) = 𝒰.elements


get_ele_sub(𝒮ᵛᵉᶜ::Vector{Vector}, x::Type{<:AbstractElement}) =
    filter(𝒮 -> typeof(𝒮) == Vector{_ele_to_sub(x)}, 𝒮ᵛᵉᶜ)[1]
get_ele_sub(𝒰::UpdateType, x::Type{<:AbstractElement}) = get_ele_sub(𝒰.elements, x)

new_el(𝒮::Vector{<:AbstractSub}, x_old::AbstractElement) =
    filter(x -> x.reference == x_old, 𝒮)[1].new
old_el(𝒮::Vector{<:AbstractSub}, x_new::AbstractElement) =
    filter(x -> x.new == x_new, 𝒮)[1].reference
new_el(𝒰::UpdateType, x_old::AbstractElement) = new_el(get_ele_sub(𝒰, typeof(x_old)), x_old)
old_el(𝒰::UpdateType, x_new::AbstractElement) = old_el(get_ele_sub(𝒰, typeof(x_new)), x_new)
new_el(𝒰::UpdateType, x_old::Resource) = filter(x -> x.reference == x_old, 𝒰.products)[1].new
old_el(𝒰::UpdateType, x_new::Resource) = filter(x -> x.new == x_new, 𝒰.products)[1].reference
old_el(𝒰::UpdateType, x_new::TS.TimePeriod) = 𝒰.opers[x_new]

EMB.get_products(𝒰::UpdateType) = Resource[𝒮.new for 𝒮 ∈ 𝒰.products]
EMB.get_nodes(𝒰::UpdateType) = EMB.Node[𝒮.new for 𝒮 ∈ get_ele_sub(𝒰, EMB.Node)]
EMB.get_links(𝒰::UpdateType) = Link[𝒮.new for 𝒮 ∈ get_ele_sub(𝒰, EMB.Link)]

old_el(𝒰::Dict, x_new::EMB.Node) = 𝒰[:nodes][x_new]
old_el(𝒰::Dict, x_new::Link) = 𝒰[:links][x_new]
old_el(𝒰::Dict, x_new::Resource) = 𝒰[:products][x_new]
old_el(𝒰::Dict, x_new::TS.TimePeriod) = 𝒰[:opers][x_new]
