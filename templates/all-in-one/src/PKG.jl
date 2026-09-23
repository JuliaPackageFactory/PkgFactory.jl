module {{{PKG}}}

# Public API, accessed as {{{PKG}}}.hello without exporting the name.
public hello

# Packages

import DocStringExtensions

"""
$(DocStringExtensions.TYPEDSIGNATURES)

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
