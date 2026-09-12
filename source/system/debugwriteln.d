module system.debugwriteln;

import std.stdio;

nothrow void debugWriteln(A...)(A args)
{
    debug
    {
        try
        {
            writeln("INFO: SERVER: ", args);
        }
        catch (Exception e)
        {
            debugWriteln("ERROR:", e.msg);
        }
    }
}