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
    # TODO: Fix this. Plackett-Burman should return designs larger
    #       than requested rather than smaller.
    plackett_burman(length(factors) + 4)
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

    init_table(measurements)
end

function generate_commands(experiments::NextTable)
    commands = Dict{UInt, String}()

    for row in experiments
        command = string()

        for (flag, value) in zip(keys(row), row)
            if flag != :response && flag != :complete && flag != :id
                if value == "on"
                    command = string(command, flag, " ")
                elseif value != "off"
                    try
                        parse(Int, value)
                    catch ArgumentError
                        value = string("\"", value, "\"")
                    end

                    command = string(command, flag, value, " ")
                end
            end
        end

        commands[row.id] = strip(command)
    end

    commands
end

function log_state()
end

function compile(command::String)
    environment = copy(ENV)
    environment["NVCC_FLAGS"] = command
    println(command)

    directory = "../gaussian/"

    c = Cmd(`make`, env = environment, dir = directory)

    run(c)
end

function measure()
    directory = "../gaussian/"
    c = Cmd(`./run.sh`, dir = directory)

    run(c)
end

function run_experiments()
    factors = generate_search_space("../parameters/nvcc_flags.json")
    design = generate_design(factors)
    experiments = generate_experiments(design, factors)

    save_to_disk(experiments, "./experiments.csv")

    commands = generate_commands(experiments)

    for (id, command) in commands
        println(id)
        log_state()
        compile(command)
        measure()
    end
end

run_experiments()
