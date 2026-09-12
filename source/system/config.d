module system.config;

import std.stdio;
import std.file;
import std.string;
import std.range;
import variables;
import std.conv;
import system.debugwriteln;

nothrow string parseConf(string type, string filename) {
    try
    {
        auto file = File(filename);
        auto config = file.byLineCopy();
        
        static immutable typeMap = [
            "data_path": "DATA_PATH=",
            "address": "ADDRESS="
        ];

        if (type in typeMap)
        {
            auto prefix = typeMap[type];
            foreach (line; config)
            {
                auto trimmedLine = strip(line);
                if (trimmedLine.startsWith("//")) {
                    continue;
                }
                if (trimmedLine.startsWith(prefix))
                {
                    auto value = trimmedLine[prefix.length .. $].strip();
                    debug debugWriteln("Value for ", type, ": ", value);
                    return value;
                }
            }
        }
    }
    catch (Exception e)
    {
        debugWriteln(e.msg);
    }
    return "";
}

SystemSettings loadSettingsFromConfigFile(string confName) {
    return SystemSettings(
        parseConf("data_path", confName).to!string,
        parseConf("address", confName).to!string,
    );
}