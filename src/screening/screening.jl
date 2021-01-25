using JSON, CSV, DataFrames, Distributed

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
    println("entering pb")
    plackett_burman(length(factors) + 5)
end

function init_dataframe(measurements::Array{Measurement, 1})
    data = DataFrame()

    for key in keys(measurements[1].parameters)
        data[!, key] = [m.parameters[key] for m in measurements]
    end

    data[!, :response] = [m.response for m in measurements]
    data[!, :complete] = [m.complete for m in measurements]
    data[!, :id] = [m.id for m in measurements]

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


function factor_dataframe(factors::Array{Factor, 1})
    data = DataFrame()

    for name in fieldnames(Factor)
        data[!, name] = [getfield(f, name) for f in factors]
    end

    data
end

# function generate_flags(experiments::NextTable)
#     flag_dict = Dict{UInt, String}()
#
#     for row in experiments
#         flags = string()
#
#         for (flag, value) in zip(keys(row), row)
#             if flag != :response && flag != :complete && flag != :id
#                 if value == "on"
#                     flags = string(flags, flag, " ")
#                 elseif value != "off"
#                     try
#                         parse(Int, value)
#                     catch ArgumentError
#                         value = string("\"", value, "\"")
#                     end
#
#                     flags = string(flags, flag, value, " ")
#                 end
#             end
#         end
#
#         flag_dict[row.id] = strip(flags)
#     end
#
#     flag_dict
# end

function generate_flags(experiments::DataFrame)
    flag_dict = Dict{UInt, String}()

    for i = 1:size(experiments, 1)
        row = experiments[i, :]

        flags = string()

        exclude = ["response", "complete", "id", "dummy1",
                   "dummy2", "dummy3", "dummy4", "dummy5"]

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

function log_state(log_path::String)
    c = Cmd(`mkdir -p $log_path`)

    println(c)
    run(c)

    cpu = open("$log_path/cpu.txt", "a")
    gpu = open("$log_path/gpu.txt", "a")

    cpu_load = open("$log_path/cpu_load.txt", "a")
    gpu_load = open("$log_path/gpu_load.txt", "a")

    hw = open("$log_path/hw.txt", "a")
    uname = open("$log_path/uname.txt", "a")

    write(cpu, read(`lscpu`, String))
    write(cpu, read(`cat /proc/cpuinfo`, String))

    write(hw, read(`lshw`, String))
    write(hw, read(`lspci`, String))

    write(gpu, read(`nvidia-smi`, String))

    write(uname, read(`uname -a`, String))

    write(cpu_load, read(`date`, String))
    write(cpu_load, read(`ps aux`, String))

    write(gpu_load, read(`date`, String))
    write(gpu_load, read(`nvidia-smi`, String))

    close(cpu)
    close(gpu)

    close(cpu_load)
    close(gpu_load)

    close(hw)
    close(uname)
end

function log_state(run_id::UInt, log_path::String)
    c = Cmd(`mkdir -p $log_path`)

    println(c)
    run(c)

    cpu = open("$log_path/cpu.txt", "a")
    gpu = open("$log_path/gpu.txt", "a")

    cpu_load = open("$log_path/cpu_load.txt", "a")
    gpu_load = open("$log_path/gpu_load.txt", "a")

    hw = open("$log_path/hw.txt", "a")
    uname = open("$log_path/uname.txt", "a")

    measurements = open("$log_path/measurements.txt", "a")

    write(cpu_load, read(`date`, String))
    write(cpu_load, read(`ps aux`, String))

    write(gpu_load, read(`date`, String))
    write(gpu_load, read(`nvidia-smi`, String))

    write(measurements, "$run_id ")
    write(measurements, read(`date`, String))

    close(cpu)
    close(gpu)

    close(cpu_load)
    close(gpu_load)

    close(hw)
    close(uname)

    close(measurements)
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
        measurement = deepcopy(experiments[experiments[!, :id] .== id, :])

        c = Cmd(`./run.sh`, dir = directory)
        response = @elapsed run(c)

        measurement[!, :response] = [response]
        measurement[!, :complete] = [true]

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

function run_experiments()
    factors = generate_search_space("../parameters/gaussian_nvcc_flags.json")
    design = generate_design(factors)

    log_path = "../../data/heartwall_quadrom1200"
    directory = "../heartwall/"

    c = Cmd(`mkdir -p $log_path`)
    run(c)

    if length(factors) < size(design, 2)
        for i = 1:(size(design, 2) - length(factors))
            push!(factors, Factor(Numeric, string("dummy", i),
                                  string(-1), string(1)))
        end
    end

    experiments = generate_experiments(design, factors)

    CSV.write("$log_path/experiments.csv", experiments)

    factor_names = [Symbol(f.name) for f in factors]

    screening_design = DataFrame(design)
    screening_design = rename!(screening_design, factor_names)

    CSV.write("$log_path/screening_design.csv", screening_design)

    factor_df = factor_dataframe(factors)

    CSV.write("$log_path/factors.csv", factor_df)

    flags = generate_flags(experiments)

    replications = 10

    data = DataFrame()

    log_state(log_path)

    for (id, flag) in flags
        log_state(id, log_path)
        compile_with_flags(flag, directory)
        data = measure(experiments, id, data, replications, directory)
    end

    CSV.write("$log_path/results.csv", data)
end

run_experiments()
