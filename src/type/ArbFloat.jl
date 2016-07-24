#=
            # P is the precision used with the typed occurance
            #
type ArbFloat{P}  <: Real     # field and struct names from arb.h
  exponentOf2        ::Int    #           fmpz
  nwords_sign        ::UInt   #           mp_size_t
  significand1       ::UInt   #           significand_struct
  significand2       ::UInt   #
  radius_exponentOf2 ::Int    #           fmpz
  radius_significand ::UInt   #
end
=#

# get and set working precision for ArbFloat

const ArbFloatPrecision = [116,]
precision(::Type{ArbFloat}) = ArbFloatPrecision[1]

function setprecision(::Type{ArbFloat}, x::Int)
    priorprecision = precision(ArbFloat)
    x = max(11, abs(x))
    x > 4095 && warn("ArbFloats are designed to work best at precisions < 4096 bits")
    ArbFloatPrecision[1] = x
    return priorprecision
end

precision{P}(x::ArbFloat{P}) = P
precision{P}(::Type{ArbFloat{P}}) = P
# allow inquiring the precision of the module: precision(ArbFloats)
precision(::Type{Type{Val{:ArbFloats}}}) = precision(ArbFloat)
precision(m::Module) = precision(Type{Val{Symbol(m)}})

# a type specific hash function helps the type to 'just work'
const hash_arbfloat_lo = (UInt === UInt64) ? 0x37e642589da3416a : 0x5d46a6b4
const hash_0_arbfloat_lo = hash(zero(UInt), hash_arbfloat_lo)
# two values of the same precision
#    with identical midpoint significands and identical radus_exponentOf2s hash equal
# they are the same value, one is less accurate yet centered about the other
hash{P}(z::ArbFloat{P}, h::UInt) =
    hash(z.significand1$z.exponentOf2,
         (h $ hash(z.significand2$(~reinterpret(UInt,P)), hash_arbfloat_lo)
            $ hash_0_arbfloat_lo))

#=
@inline finalize{T<:ArbFloat}(x::T) = ccall(@libarb(arb_clear), Void, (Ptr{T},), &x)
@inline finalize{P}(x::ArbFloat{P}) = ccall(@libarb(arb_clear), Void, (Ptr{ArbFloat{P}},), &x)

function initial0{P}(x::ArbFloat{P})
    z = ArbFloat{P}(0,0,0,0,0,0)
    ccall(@libarb(arb_init), Void, (Ptr{ArbFloat{P}},), &z)
    return z
end
function initial0{T<:ArbFloat}(x::T)
    P = precision(T)
    z = ArbFloat{P}(0,0,0,0,0,0)
    ccall(@libarb(arb_init), Void, (Ptr{ArbFloat{P}},), &z)
    return z
end

#@inline initial0{T<:ArbFloat}(x::Type{T}) = ccall(@libarb(arb_init), Void, (Ptr{T},), &x)
#@inline initial0{P}(x::Type{ArbFloat{P}}) = ccall(@libarb(arb_init), Void, (Ptr{ArbFloat{P}},), &x)
=#
#=
@inline initial0{P}(x::ArbFloat{P}) =  ccall(@libarb(arb_init), Void, (Ptr{ArbFloat{P}},), &x)
@inline finalize{P}(x::ArbFloat{P}) =  ccall(@libarb(arb_clear), Void, (Ptr{ArbFloat{P}},), &x)

# initialize and zero a variable of type ArbFloat
function initializer{P}(::Type{ArbFloat{P}})
    z = ArbFloat{P}(0,0,0,0,0,0)
    ccall(@libarb(arb_init), Void, (Ptr{ArbFloat{P}},), &z)
    initial0(z)
    finalizer(z, finalize)
    return z
end

# initialize and zero a variable of type ArbFloat
function initializer{T<:ArbFloat}(::Type{T})
    P = precision(T)
    z = ArbFloat{P}(0,0,0,0,0,0)
    initial0(z)
    finalizer(z, finalize)
    return z
end
initializer(::Type{ArbFloat}) = initializer{ArbFloat{precision(ArbFloat)}}
=#

#=
free_clib_var{T<:ArbFloat}(x::T) =
    ccall(@libarb(arb_clear), Void, (Ptr{T}, ), &x)

function initializer{T<:ArbFloat}(::Type{T})
    P = precision(T)
    z = ArbFloat{P}(zero(Int), zero(UInt64), zero(Int64), zero(Int64), zero(Int), zero(UInt64))
    ccall(@libarb(arb_init), Void, (Ptr{ArbFloat{P}}, ), &z)
    finalizer(z, free_clib_var)
    return z
end
=#


function release{P}(x::ArbFloat{P})
    ccall(@libarb(arb_clear), Void, (Ptr{ArbFloat{P}}, ), &x)
    return nothing
end

function initializer{P}(::Type{ArbFloat{P}})
    z = ArbFloat{P}(zero(Int), zero(UInt64), zero(Int64), zero(Int64), zero(Int), zero(UInt64))
    ccall(@libarb(arb_init), Void, (Ptr{ArbFloat{P}}, ), &z)
    finalizer(z, release)
    return z
end

# empty constructor
ArbFloat() = initializer(ArbFloat{precision(ArbFloat)})


# parts and aspects
# midpoint, radius, lowerbound, upperbound, bounds

function midpoint{T<:ArbFloat}(x::T)
    P = precision(T)
    z = initializer(ArbFloat{P})
    ccall(@libarb(arb_get_mid_arb), Void, (Ptr{ArbFloat}, Ptr{ArbFloat}), &z, &x)
    z
end

function radius{T<:ArbFloat}(x::T)
    P = precision(T)
    z = initializer(ArbFloat{P})
    ccall(@libarb(arb_get_rad_arb), Void, (Ptr{ArbFloat}, Ptr{ArbFloat}), &z, &x)
    z
end

function upperbound{P}(x::ArbFloat{P})
    a = ArfFloat{P}(0,0,0,0)
    ccall(@libarb(arf_init), Void, (Ptr{ArfFloat{P}},), &a)
    z = initializer(ArbFloat{P})
    ccall(@libarb(arb_get_ubound_arf), Void, (Ptr{ArfFloat}, Ptr{ArbFloat}, Int), &a, &x, P)
    ccall(@libarb(arb_set_arf), Void, (Ptr{ArbFloat}, Ptr{ArfFloat}), &z, &a)
    ccall(@libarb(arf_clear), Void, (Ptr{ArfFloat{P}},), &a)
    z
end

function lowerbound{P}(x::ArbFloat{P})
    a = ArfFloat{P}(0,0,0,0)
    ccall(@libarb(arf_init), Void, (Ptr{ArfFloat{P}},), &a)
    z = initializer(ArbFloat{P})
    ccall(@libarb(arb_get_lbound_arf), Void, (Ptr{ArfFloat}, Ptr{ArbFloat}, Int), &a, &x, P)
    ccall(@libarb(arb_set_arf), Void, (Ptr{ArbFloat}, Ptr{ArfFloat}), &z, &a)
    ccall(@libarb(arf_clear), Void, (Ptr{ArfFloat{P}},), &a)
    z
end

bounds{P}(x::ArbFloat{P}) = ( lowerbound(x), upperbound(x) )

function upperBound{T<:ArbFloat}(x::T, prec::Int)
    P = precision(T)
    a = ArfFloat{P}(0,0,0,0)
    ccall(@libarb(arf_init), Void, (Ptr{ArfFloat{P}},), &a)
    z = initializer(ArbFloat{P})
    ccall(@libarb(arb_get_ubound_arf), Void, (Ptr{ArfFloat}, Ptr{ArbFloat}, Int), &a, &x, prec)
    ccall(@libarb(arb_set_arf), Void, (Ptr{ArbFloat}, Ptr{ArfFloat}), &z, &a)
    ccall(@libarb(arf_clear), Void, (Ptr{ArfFloat{P}},), &a)
    z
end

function lowerBound{T<:ArbFloat}(x::T, prec::Int)
    P = precision(T)
    a = ArfFloat{P}(0,0,0,0)
    ccall(@libarb(arf_init), Void, (Ptr{ArfFloat{P}},), &a)
    z = initializer(ArbFloat{P})
    ccall(@libarb(arb_get_lbound_arf), Void, (Ptr{ArfFloat}, Ptr{ArbFloat}, Int), &a, &x, prec)
    ccall(@libarb(arb_set_arf), Void, (Ptr{ArbFloat}, Ptr{ArfFloat}), &z, &a)
    ccall(@libarb(arf_clear), Void, (Ptr{ArfFloat{P}},), &a)
    z
end

lohiBounds{T<:ArbFloat}(x::T, prec::Int) = ( lowerBound(x, prec), upperBound(x, prec) )



function minmax{P}(x::ArbFloat{P}, y::ArbFloat{P})
   x < y ? (x,y) : (y,x)
end

function relativeError{P}(x::ArbFloat{P})
    z = P
    ccall(@libarb(arb_rel_error_bits), Void, (Ptr{Int}, Ptr{ArbFloat}), &z, &x)
    z
end

function relativeAccuracy{P}(x::ArbFloat{P})
    z = P
    ccall(@libarb(arb_rel_accuracy_bits), Void, (Ptr{Int}, Ptr{ArbFloat}), &z, &x)
    z
end

function midpointPrecision{P}(x::ArbFloat{P})
    z = P
    ccall(@libarb(arb_bits), Void, (Ptr{Int}, Ptr{ArbFloat}), &z, &x)
    z
end

function trimmedAccuracy{P}(x::ArbFloat{P})
    z = initializer(ArbFloat{P})
    ccall(@libarb(arb_trim), Void, (Ptr{ArbFloat}, Ptr{ArbFloat}), &z, &x)
    z
end





# precision is significand precision, significand_bits(FloatNN) + 1, for the hidden bit
typealias ArbFloat16  ArbFloat{ 11}  # read   2 ? 3 or fewer decimal digits to write the same digits ( 16bit Float)
typealias ArbFloat32  ArbFloat{ 24}  # read   6 ? 7 or fewer decimal digits to write the same digits ( 32bit Float)
typealias ArbFloat64  ArbFloat{ 53}  # read  15 ?15 or fewer decimal digits to write the same digits ( 64bit Float)
typealias ArbFloat128 ArbFloat{113}  # read  33 ?34 or fewer decimal digits to write the same digits (128bit Float)
typealias ArbFloat256 ArbFloat{237}  # read  71 ?71 or fewer decimal digits to write the same digits (256bit Float)
typealias ArbFloat512 ArbFloat{496}  # read 148?149 or fewer decimal digits to write the same digits (512bit Float)
