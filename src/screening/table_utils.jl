# import JuliaDB
# import FileIO

@everywhere begin
    # using JuliaDB
    # using FileIO

    mutable struct Measurement
        parameters::Dict{Symbol, Any}
        response::Float64
        complete::Bool
        id::UInt64

        Measurement(parameters, r) = new(parameters, r, true, hash(string(r, collect(values(parameters))...)))
        Measurement(parameters) = new(parameters, -1, false, hash(string(-1, collect(values(parameters))...)))
    end

    # function init_table(measurements::Array{Measurement, 1})
    #     rows = Array{Any, 1}()

    #     parameters = collect(keys(measurements[1].parameters))
    #     measurement_names = [name for name in fieldnames(measurements[1]) if name != :parameters]
    #     column_names = vcat(parameters, measurement_names)

    #     for measurement in measurements
    #         push!(rows, vcat(collect(values(measurement.parameters)),
    #                          [getfield(measurement, f) for f in measurement_names]))
    #     end

    #     return table([[r[i] for r in rows] for i = 1:length(rows[1])]...,
    #                  names = column_names, pkey = :id)
    # end

    # function contains(t::NextTable, entry::Measurement)
    #     return entry.id in select(t, :id)
    # end

    # function add_complete_unique_entry!(t::NextTable, entry::Measurement)
    #     if entry.complete && !contains(t, entry)
    #         row_expr::Expr = :@NT

    #         for name in fieldnames(Measurement)
    #             if name == :parameters
    #                 for key in keys(entry.parameters)
    #                     push!(row_expr.args, Expr(Symbol("="), key,
    #                                               entry.parameters[key]))
    #                 end
    #             else
    #                 push!(row_expr.args, Expr(Symbol("="), name,
    #                                           getfield(entry, name)))
    #             end
    #         end

    #         push!(rows(t), eval(row_expr))

    #         # Sorting 't' by its primary key
    #         t = table(t, pkey = t.pkey, copy = false)
    #     end

    #     t
    # end

    # function save_to_disk(t::NextTable, filename::String)
    #     FileIO.save(filename, t)
    # end
end
