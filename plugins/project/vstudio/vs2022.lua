import("impl.vs201x")

-- make
function make(outputdir)

    -- init vstudio info
    local vsinfo = 
    {
        vstudio_version     = "2022"
    ,   filters_version     = "4.0"
    ,   solution_version    = "12"
    }

    -- make project
    vs201x.make(outputdir, vsinfo)
end