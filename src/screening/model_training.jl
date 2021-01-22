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
        design[f.name] = (rand(factor, experiments) .* 2) .- 1
    end

    design
end

function duplicate_rowwise(design::DataFrame, duplicates::Int)
    design[repeat(1:nrow(design), inner = duplicates), :]
end

function compile_with_flags(flags::String, directory::String)
    environment = copy(ENV)
    environment["NVCC_FLAGS"] = flags

    c = Cmd(`make`, env = environment, dir = directory)

    #println(flags)
    run(c)
end

function measure(experiments::DataFrame, id::UInt,
                 data::DataFrame, replications::Int,
                directory::String)

    for i = 1:replications
        measurement = deepcopy(experiments[experiments[:id] .== id, :])

        c = Cmd(`./run.sh`, dir = directory)
        response = @elapsed run(c)

        measurement[:response] = response
        measurement[:complete] = true

        if isempty(data)
            data = measurement
        else
            append!(data, measurement)
        end
    end

    c = Cmd(`make clean`, dir = directory)
    run(c)

    data
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

function run_experiments()
    design_size = 150000
    log_path = "../../data/needle_titanx"
    directory = "../needle/"
    
    factors = generate_search_space("../parameters/nvcc_flags.json")
    screening_design = CSV.read("$log_path/screening_design.csv",
                                DataFrame)
    results = CSV.read("$log_path/results.csv",
                       DataFrame)

    replications = 10
    model_design = duplicate_rowwise(screening_design, replications)

    println(nrow(model_design))
    println(nrow(results))
    model_design[:response] = results[:response]

    screening_model = FormulaTerm(term(:response),
                                  sum(term.(Symbol.(names(screening_design)))))

    screening_regression = lm(screening_model, model_design)

    random_design = generate_random_2level_design(factors, design_size)
    random_experiments = generate_experiments(convert(Array, random_design),
                                              factors)

    model = FormulaTerm(term(:response),
                        sum(term.(Symbol.(getfield.(factors, :name)))))

    regression = lm(model, model_design)

    random_experiments[!, :prediction] = predict(regression, random_design)

    best_index = findmin(random_experiments[!, :prediction])
    best_prediction = DataFrame(select(random_experiments,
                                       Not(:prediction))[best_index[2], :])

    data = DataFrame()
    flags = generate_flags(best_prediction)

    for (id, flag) in flags
        compile_with_flags(flag, directory)
        data = measure(random_experiments, id, data, replications, directory)
    end

    CSV.write("$log_path/prediction_results.csv", data)

    baseline_data = DataFrame()
    best_flags = DataFrame(("-Xptxas --opt-level=" => [-1, 1]))
    best_experiments = generate_experiments(convert(Array, best_flags),
                                            filter(x -> x.name == "-Xptxas --opt-level=",
                                                   factors))
    flags = generate_flags(best_experiments)

    println(flags)

    for (id, flag) in flags
        compile_with_flags(flag, directory)
        baseline_data = measure(best_experiments, id,
                                baseline_data, replications,directory)
    end

    CSV.write("$log_path/baseline_results.csv", baseline_data)
end

run_experiments()

