using StatsModels, GLM, DataFrames, Distributions, Random, CSV, JSON

abstract type Enumeration end
abstract type Flag end
abstract type Numeric end

struct Factor
    t::Type
    name::String
    min::String
    max::String
end

mutable struct Measurement
    parameters::Dict{Symbol, Any}
    response::Float64
    complete::Bool
    id::UInt64

    Measurement(parameters, r) = new(parameters, r, true, hash(string(r, collect(values(parameters))...)))
    Measurement(parameters) = new(parameters, -1, false, hash(string(-1, collect(values(parameters))...)))
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

function generate_flags(experiments::DataFrame)
    flag_dict = Dict{UInt, String}()

    for i = 1:size(experiments, 1)
        row = experiments[i, :]

        flags = string()

        exclude = ["response", "complete", "id", "dummy1",
                   "dummy2", "dummy3", "dummy4"]

        for flag in names(row)
            if !(flag in exclude)
                if row[flag] == "on"
                    flags = string(flags, flag, " ")
                elseif row[flag] != "off"
                    value = row[flag]

                    try
                        value = parse(Int, value)
                    catch ArgumentError
                        value = string("\"", value, "\"")
                    end

                    flags = string(flags, flag, value, " ")
                end                    
            end
        end

        flag_dict[row[:id]] = strip(flags)
    end

    flag_dict
end

function init_dataframe(measurements::Array{Measurement, 1})
    data = DataFrame()

    for key in keys(measurements[1].parameters)
        data[key] = [m.parameters[key] for m in measurements]
    end

    data[:response] = [m.response for m in measurements]
    data[:complete] = [m.complete for m in measurements]
    data[:id] = [m.id for m in measurements]
    
    data
end

function generate_experiments(design::Array{Int, 2}, factors::Array{Factor, 1})
    design_size = size(design)
    factors_length = length(factors)

    measurements = Array{Measurement, 1}()

    for i = 1:design_size[1]
        levels = Dict{Symbol, Any}()

        for j = 1:factors_length
            if design[i, j] == 1
                levels[Symbol(factors[j].name)] = factors[j].max
            else
                levels[Symbol(factors[j].name)] = factors[j].min
            end
        end

        push!(measurements, Measurement(levels))
    end

    init_dataframe(measurements)
end

function generate_random_2level_design(factors::Array{Factor, 1},
                                       experiments::Int)
    factor = DiscreteUniform(0, 1)
    design = DataFrame()

    for f in factors
        design[f.name] = rand(factor, experiments)
    end

    design
end

function duplicate_rowwise(design::DataFrame, duplicates::Int)
    indices = collect(1:nrow(design))
    design[convert(Array, reshape([indices indices]',
                                  2 * nrow(design),
                                  1)),
           :]
end

design_size = 1500

factors = generate_search_space("../parameters/nvcc_flags.json")
design = generate_random_2level_design(factors, design_size)
experiments = generate_experiments(convert(Array, design), factors)

screening_design = CSV.read("../../data/gaussian_titanx/screening_design.csv",
                            DataFrame)

results = CSV.read("../../data/gaussian_titanx/results.csv",
                   DataFrame)
