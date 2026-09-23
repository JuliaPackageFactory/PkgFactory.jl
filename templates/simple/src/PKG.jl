module {{{PKG}}}

# Public API, accessed as {{{PKG}}}.hello without exporting the name.
public hello

"""
Return a friendly greeting.

# Examples

```jldoctest
julia> {{{PKG}}}.hello()
"Hello, World!"
```
"""
function hello()
    return "Hello, World!"
end

end
