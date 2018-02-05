using JSON

include("plackett_burman.jl")
include("table_utils.jl")

abstract type Enumeration end
abstract type Flag end
abstract type Numeric end

struct Factor
    t::Type
    name::String
    min::String
    max::String
end

function generate_search_space(filename::String)
    json_data       = JSON.parsefile(filename)
    parameter_types = ["flags", "enumeration_parameters", "numeric_parameters"]
    parameters      = Array{Factor, 1}()

    for key in keys(json_data)
        prefix = json_data[key]["prefix"]
        for parameter_type in parameter_types
            if !(isempty(json_data[key][parameter_type]))
                if parameter_type == "flags"
                    for parameter in json_data[key][parameter_type]
                        push!(parameters, Factor(Flag, "$prefix $parameter",
                                                 "on", "off"))
                    end
                elseif parameter_type == "enumeration_parameters"
                    for parameter in json_data[key][parameter_type]
                        push!(parameters, Factor(Enumeration, 
                                                 "$prefix $(parameter[1])",
                                                 "$(parameter[2][1])",
                                                 "$(parameter[2][end])"))
                    end
                else
                    for parameter in json_data[key][parameter_type]
                        push!(parameters, Factor(Numeric,
                                                 "$prefix $(parameter[1])",
                                                 "$(parameter[2]["min"])",
                                                 "$(parameter[2]["max"])"))
                    end
                end
            end
        end
    end
    return parameters
end

function generate_design(factors::Array{Factor, 1})
    plackett_burman(length(factors) + 2)
end

function generate_experiments(design::Array{Int, 2}, factors::Array{Factor, 1})
end

function run_experiments()
    factors = generate_search_space("../parameters/nvcc_flags.json")
    design = generate_design(factors)
end

run_experiments()
