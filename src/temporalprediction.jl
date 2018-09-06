using NearestNeighbors
export KDTree
export TemporalPrediction

function working_ts(s,em)
    L = length(s)
    τmax = get_τmax(em)
    return s[L-τmax : L]
end

function gen_queries(s,em)
    L = length(s)
    τmax = get_τmax(em)
    s_slice = view( s, L-τmax:L)
    return reconstruct(s_slice, em)
end

function convert_idx(idx, em)
    τmax = get_τmax(em)
    num_pt = get_num_pt(em)
    t = 1 + (idx-1) ÷ num_pt + get_τmax(em)
    α = 1 + (idx-1) % num_pt
    return t,α
end

cut_off_beginning!(s,em) = deleteat!(s, 1:get_τmax(em))

macro record(name, to_record)
    return esc(:(sol.runtimes[$name] = @elapsed $to_record))
end

###########################################################################################
#                        Iterated Time Series Prediction                                  #
###########################################################################################

mutable struct TemporalPrediction{T,Φ,BC,X}
    em::AbstractSpatialEmbedding{T,Φ,BC,X}
    method::AbstractLocalModel
    ntype::AbstractNeighborhood
    treetype#::NNTree what's the type here?
    timesteps::Int64

    runtimes::Dict{Symbol,Float64}
    spred::Vector{Array{T,Φ}}
    TemporalPrediction{T,Φ,BC,X}(em::ASE{T,Φ,BC,X}, method, ntype, ttype, tsteps
                                    ) where {T,Φ,BC,X} =
                                    new(em, method, ntype, ttype, tsteps,
                                    Dict{Symbol,Float64}(),Array{T,Φ}[])
end



function TemporalPrediction(s,
    em::AbstractSpatialEmbedding{T,Φ},
    tsteps;
    ttype=KDTree,
    method = AverageLocalModel(ω_safe),
    ntype = FixedMassNeighborhood(3),
    progress=true) where {T,Φ}

    prelim_sol = TemporalPrediction(em, method, ntype, ttype, tsteps)
    return TemporalPrediction(prelim_sol, s; progress=progress)
end

function TemporalPrediction(sol, s; progress=true)
    progress && println("Reconstructing")
    @record :recontruct   R = reconstruct(s,sol.em)

    #Prepare tree but remove the last reconstructed states first
    progress && println("Creating Tree")
    L = length(R)
    M = get_num_pt(sol.em)

    @record :tree   tree = sol.treetype(R[1:L-M])
    TemporalPrediction(sol, s, R, tree; progress=progress)
end



function TemporalPrediction(sol, s, R, tree; progress=true) where {T, Φ, BC, X}
    em = sol.em
    @assert outdim(em) == size(R,2)
    num_pt = get_num_pt(em)
    #New state that will be predicted, allocate once and reuse
    state = similar(s[1])

    #End of timeseries to work with
    sol.spred = spred = working_ts(s,em)

    @record :prediction for n=1:sol.timesteps
        progress && println("Working on Frame $(n)/$(sol.timesteps)")
        queries = gen_queries(spred, em)

        #Iterate over queries/ spatial points
        for m=1:num_pt
            q = queries[m]

            #Find neighbors
            idxs,dists = neighborhood_and_distances(q,R,tree,sol.ntype)

            xnn = R[idxs]
            #Retrieve ynn
            ynn = map(idxs) do idx
                #Indices idxs are indices of R. Convert to indices of s
                t,α = convert_idx(idx,em)
                s[t+1][α]
            end
            state[m] = sol.method(q,xnn,ynn,dists)[1]
        end
        push!(spred,copy(state))
    end

    cut_off_beginning!(spred,em)
    return sol
end
