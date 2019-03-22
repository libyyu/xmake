-- imports
import("privilege.sudo")

-- main entry
function main(argv)

    -- check global config
    os.exec("xmake g -c")

    -- generic?
    os.exec("xmake f -c")
    os.exec("xmake")
    os.exec("xmake p --verbose -D")
    if os.host() ~= "windows" then
        os.exec("xmake install -o /tmp -a --verbose -D")
        os.exec("xmake uninstall --installdir=/tmp --verbose -D")
    end
    os.exec("xmake c --verbose -D")
    os.exec("xmake f --mode=debug --verbose -D")
    os.exec("xmake m -b")
    os.exec("xmake -r -a -v -D")
    os.exec("xmake m -e buildtest")
    os.exec("xmake m -l")
    os.exec("xmake m buildtest")
    if sudo.has() then
        sudo.exec("xmake install --all -v -D")
        sudo.exec("xmake uninstall -v -D")
    end
    os.exec("xmake m -d buildtest")

    -- test iphoneos?
    if argv and argv.iphoneos then
        if os.host() == "macosx" then
            os.exec("xmake m package -p iphoneos")
        end
    end
end
