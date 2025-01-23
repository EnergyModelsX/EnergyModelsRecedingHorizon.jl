using Pkg
# Activate the local environment including Documenter, DocumenterInterLinks
Pkg.activate(@__DIR__)

using Documenter
using DocumenterInterLinks
using DocumenterCitations

using TimeStruct
using EnergyModelsBase
using EnergyModelsRecHorizon
const TS = TimeStruct
const EMB = EnergyModelsBase
const EMRH = EnergyModelsRecHorizon

# Copy the NEWS.md file
cp("NEWS.md", "docs/src/manual/NEWS.md"; force = true)

links = InterLinks(
    # "TimeStruct" => "https://sintefore.github.io/TimeStruct.jl/stable/",
    "EnergyModelsBase" => "https://energymodelsx.github.io/EnergyModelsBase.jl/stable/",
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
    ],
    pages = [
        "Home" => "index.md",
        "Manual" => Any[
            "Quick Start"=>"manual/quick-start.md",
            "Philosophy"=>"manual/philosophy.md",
            "Initialization"=>"manual/initialization.md",
            "Cost to go"=>"manual/cost-to-go.md",
            "Example"=>"manual/simple-example.md",
            "Release notes"=>"manual/NEWS.md",
        ],
        "How to" => Any[
            "Create a new node"=>"how-to/create-new-node.md",
        ],
        "Library" => Any[
            "Public"=>"library/public.md",
            "Internals"=>String[
                "library/internals/types-EMRH.md",
                # "library/internals/methods-fields.md",
                "library/internals/methods-EMRH.md",
                "library/internals/methods-EMB.md",
            ],
        ],
        "References" => "references.md",
    ],
    plugins = [links, bib],
)

# deploydocs(;
#     repo = "https://idesignres.pages.sintef.no/wp-2/EnergyModelsRecHorizon.jl",
# )
