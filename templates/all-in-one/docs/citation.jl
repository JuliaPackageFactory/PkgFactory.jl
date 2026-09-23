import Bibliography

function citation_bibtex(path)
    document = Bibliography.read_bibliography(path; format = :CFF)
    entries = Bibliography.bibliography_entries(document)
    length(entries) == 1 || error("Expected one valid citation in $path")
    entry = only(values(entries))
    # Standard fields are mapped by Bibliography; retain the software version too.
    filter!(pair -> first(pair) == "version", entry.fields)
    return Bibliography.export_bibtex(entry) * "\n"
end
