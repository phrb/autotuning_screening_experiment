using JSON, CSV, DataFrames

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
    # TODO: Fix this. Plackett-Burman should return designs larger
    #       than requested rather than smaller.
    plackett_burman(length(factors) + 4)
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

    for i = 1:design_size[2]
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

function generate_flags(experiments::NextTable)
    flag_dict = Dict{UInt, String}()

    for row in experiments
        flags = string()

        for (flag, value) in zip(keys(row), row)
            if flag != :response && flag != :complete && flag != :id
                if value == "on"
                    flags = string(flags, flag, " ")
                elseif value != "off"
                    try
                        parse(Int, value)
                    catch ArgumentError
                        value = string("\"", value, "\"")
                    end

                    flags = string(flags, flag, value, " ")
                end                    
            end
        end

        flag_dict[row.id] = strip(flags)
    end

    flag_dict
end

function generate_flags(experiments::DataFrame)
    flag_dict = Dict{UInt, String}()

    for i = 1:size(experiments, 1)
        row = experiments[i, :]

        flags = string()

        for flag in names(row)
            if flag != :response && flag != :complete && flag != :id
                if row[flag][1] == "on"
                    flags = string(flags, flag, " ")
                elseif row[flag][1] != "off"
                    value = row[flag][1]

                    try
                        value = parse(Int, value)
                    catch ArgumentError
                        value = string("\"", value, "\"")
                    end

                    flags = string(flags, flag, value, " ")
                end                    
            end
        end

        flag_dict[row[:id][1]] = strip(flags)
    end

    flag_dict
end

function log_state(run_id::UInt)
end

function compile_with_flags(flags::String)
    environment = copy(ENV)
    environment["NVCC_FLAGS"] = flags

    directory = "../gaussian/"

    c = Cmd(`make`, env = environment, dir = directory)

    println(flags)
    run(c)
end

function measure(experiments::DataFrame, id::UInt,
                 data::Nullable{DataFrame}, replications::Int)
    measurement = experiments[experiments[:id] .== id, :]

    for i = 1:replications
      directory = "../gaussian/"
      c = Cmd(`./run.sh`, dir = directory)
      response = @elapsed run(c)

      println(response)

      measurement[:response] = response

      if isnull(data)
          data = measurement
      else
          append!(data, measurement)
      end
    end

    data
end

function run_experiments()
    factors = generate_search_space("../parameters/nvcc_flags.json")
    design = generate_design(factors)
    experiments = generate_experiments(design, factors)

    CSV.write("./experiments.csv", experiments)

    flags = generate_flags(experiments)

    replications = 5

    data = Nullable{DataFrame}()

    for (id, flag) in flags
        log_state(id)
        compile_with_flags(flag)
        data = measure(experiments, id, data, replications)
    end

    CSV.write("./results.csv", data)
end

run_experiments()
