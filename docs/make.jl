using Pkg
# Activate the local environment including Documenter, DocumenterInterLinks
Pkg.activate(@__DIR__)

using Documenter
using DocumenterInterLinks
using DocumenterCitations

using TimeStruct
using EnergyModelsBase
using EnergyModelsGeography
using EnergyModelsRecHorizon
using ParametricOptInterface

const TS = TimeStruct
const EMB = EnergyModelsBase
const EMG = EnergyModelsGeography
const EMRH = EnergyModelsRecHorizon
const POI = ParametricOptInterface

const EMGExt = Base.get_extension(EMRH, :EMGExt)
const POIExt = Base.get_extension(EMRH, :POIExt)


# Copy the NEWS.md file
cp(joinpath(@__DIR__, "..", "NEWS.md"), joinpath(@__DIR__, "src", "manual", "NEWS.md"); force = true)

links = InterLinks(
    "TimeStruct" => "https://sintefore.github.io/TimeStruct.jl/stable/",
    "EnergyModelsBase" => "https://energymodelsx.github.io/EnergyModelsBase.jl/stable/",
    "EnergyModelsGeography" => "https://energymodelsx.github.io/EnergyModelsGeography.jl/stable/",
)

bib = CitationBibliography(joinpath(@__DIR__, "src", "references.bib"))

DocMeta.setdocmeta!(
    EnergyModelsRecHorizon,
    :DocTestSetup,
    :(using EnergyModelsRecHorizon);
    recursive = true,
)

makedocs(
    sitename = "EnergyModelsRecHorizon",
    repo = "https://gitlab.sintef.no/idesignres/wp-2/energymodelsrechorizon.jl/{commit}{path}#{line}",
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical = "idesignres.pages.sintef.no/wp-2/EnergyModelsRecHorizon.jl",
        edit_link = "main",
        assets = String[],
        ansicolor = true,
    ),
    modules = [
        EMRH,
        isdefined(Base, :get_extension) ?
        Base.get_extension(EMRH, :POIExt) :
        EMRH.POIExt,
        isdefined(Base, :get_extension) ?
        Base.get_extension(EMRH, :EMGExt) :
        EMRH.EMGExt,
        isdefined(Base, :get_extension) ?
        Base.get_extension(EMRH, :EMGPOIExt) :
        EMRH.EMGPOIExt,
    ],
    pages = [
        "Home" => "index.md",
        "Manual" => Any[
            "Quick Start"=>"manual/quick-start.md",
            "Philosophy"=>"manual/philosophy.md",
            "Future value"=>"manual/future-value.md",
            "Example"=>"manual/simple-example.md",
            "Release notes"=>"manual/NEWS.md",
        ],
        "How to" => Any[
            "Adapt an EMX element"=>"how-to/adapt-emx-elem.md",
            "Use the package"=>"how-to/use-emrh.md",
        ],
        "Developer notes" => Any[
            "Code structure"=>"dev-notes/code-structure.md",
            "Problem initialization"=>"dev-notes/initialization.md",
        ],
        "Library" => Any[
            "Public"=>"library/public.md",
            "Internals"=>String[
                "library/internals/types-EMRH.md",
                "library/internals/methods-EMRH.md",
                "library/internals/methods-EMB.md",
                "library/internals/reset.md",
                "library/internals/reference-EMGExt.md",
                "library/internals/reference-POIExt.md",
            ],
        ],
        "References" => "references.md",
    ],
    plugins = [links, bib],
)

# deploydocs(;
#     repo = "https://idesignres.pages.sintef.no/wp-2/EnergyModelsRecHorizon.jl",
# )
