

-- imports
import("core.tool.tool")
import("core.tool.compiler")
import("core.project.config")
import("core.project.project")
import("core.language.language")

-- get log mkfile
function _logfile()

    -- get it
    return vformat("$(buildir)/.build.log")
end

-- mkdir directory
function _mkdir(mkfile, dir)

    if config.get("plat") == "windows" then
        mkfile:print("\t-@mkdir %s > /null 2>&1", dir)
    else
        mkfile:print("\t@mkdir -p %s", dir)
    end
end

-- make all
function _make_all(mkfile)
end

-- make
function make(outputdir)

    -- enter project directory
    local olddir = os.cd(project.directory())

    -- remove the log mkfile first
    os.rm(_logfile())

    -- open the mkfile
    local mkfile = io.open(path.join(outputdir, "mk"), "w")

    -- make all
    _make_all(mkfile)

    -- close the mkfile
    mkfile:close()
 
    -- leave project directory
    os.cd(olddir)
end