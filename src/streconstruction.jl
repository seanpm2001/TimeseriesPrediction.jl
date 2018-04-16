using StaticArrays
using IterTools
###########################################################################################
#                       Better generated Reconstruction                                   #
###########################################################################################


function my_reconstruct_impl(::Type{Val{Φ}}, ::Type{Val{lims}},::Type{Val{D}},
    ::Type{Val{B}}, ::Type{Val{k}}) where {Φ, lims, D, B, k}

    gens = Expr[]
    for d=0:D-1, lidx ∈ product([-B*k:k:B*k for i=1:Φ]...)
        cond = :(0 < midx[1] + $(lidx[1]) <= $(lims[1]))
        for i=2:Φ cond = :($cond && 0 < midx[$i] + $(lidx[i]) <= $(lims[i])) end

        push!(gens, :( $cond ?  s[t + $d*τ][(midx .+ $lidx)...] : boundary))
    end

    weights = [:(a*(-1+2*(midx[$i]-1)/($(lims[i]-1)))^b)  for i=1:Φ]

    midxs = product([1:lims[i] for i=1:Φ]...)
    quote
        M = prod(size(s[1]))
        L = length(s) - $(D-1)*τ
        T = eltype(s[1][1])
        data = Vector{SVector{$D*(2*$B + 1)^$Φ+$Φ, T}}(L*M)

        for t ∈ 1:L
            for (n,midx) ∈ enumerate($(midxs))
                data[n+(t-1)*M] = SVector{$D*(2*$B + 1)^Φ+Φ, T}($(gens...),$(weights...))
            end
        end
        data
    end
end

@generated function my_reconstruct(
    ::Type{Val{Φ}},::Type{Val{lims}}, s,
    ::Type{Val{D}}, ::Type{Val{B}}, τ, ::Type{Val{k}},
     boundary, a, b) where {Φ,lims, D, B, k}
     my_reconstruct_impl(Val{Φ}, Val{lims}, Val{D}, Val{B}, Val{k})
end

function myReconstruction(
    s::AbstractVector{Array{T, Φ}}, D, τ::DT, B=1, k=1, boundary=10, a=1, b=1
    ) where {T, Φ, DT}
    lims = size(s[1])
    Reconstruction{D*(2B+1)^Φ+Φ,T,DT}(
    my_reconstruct(Val{Φ},Val{lims}, s, Val{D}, Val{B},τ,Val{k},boundary,a,b), τ)
end
