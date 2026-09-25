abstract type PkgFactoryError <: Exception end

struct GitHubAPIError <: PkgFactoryError
    status::Int
    message::String
    retry_after::Union{Nothing,Int}
end
GitHubAPIError(status::Int, message::String) = GitHubAPIError(status, message, nothing)

Base.showerror(io::IO, error::GitHubAPIError) = print(io, error.message)

struct InputError <: PkgFactoryError
    message::String
end
Base.showerror(io::IO, err::InputError) = print(io, err.message)

struct CreationError <: PkgFactoryError
    stage::String
    status::Int
end
Base.showerror(io::IO, err::CreationError) = print(io,
    "Package creation stopped at ", err.stage,
    ". GitHub may have changed; check repository status before resuming.")
