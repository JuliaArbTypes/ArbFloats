function serialize(io::IO, a::T) where {T <: ArbFloat}
    serialize(io, stringall(a))
end

function deserialize(io::IO, ::Type{T}) where {T <: ArbFloat}
    deserialize(io)
end
