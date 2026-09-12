module networking.format;

import std.string;
import std.conv;
import std.array;
import std.algorithm;
import std.typecons;
import vibe.vibe;

struct Val {
    enum Kind { Null, Bool, Int, UInt, Float, Str, Arr, Obj }
    Kind kind;
    bool b;
    long i;
    ulong u;
    double f;
    string s;
    Val[] arr;
    Tuple!(string, Val)[] obj;

    static Val null_() { return Val(Kind.Null); }
    static Val bool_(bool v) { return Val(Kind.Bool, b: v); }
    static Val int_(long v) { return Val(Kind.Int, i: v); }
    static Val uint_(ulong v) { return Val(Kind.UInt, u: v); }
    static Val float_(double v) { return Val(Kind.Float, f: v); }
    static Val str(string v) { return Val(Kind.Str, s: v); }
    static Val arr_(Val[] v) { return Val(Kind.Arr, arr: v); }
    static Val obj_(Tuple!(string, Val)[] v) { return Val(Kind.Obj, obj: v); }
}

string escapeLuaString(string s) {
    auto sb = appender!string;
    foreach (c; s) {
        switch (c) {
            case '"':  sb ~= `\"`; break;
            case '\\': sb ~= `\\`; break;
            case '\n': sb ~= `\n`; break;
            case '\r': sb ~= `\r`; break;
            case '\t': sb ~= `\t`; break;
            default:   sb ~= c; break;
        }
    }
    return sb.data;
}

string escapeJsonString(string s) {
    auto sb = appender!string;
    foreach (c; s) {
        switch (c) {
            case '"':  sb ~= `\"`; break;
            case '\\': sb ~= `\\`; break;
            case '\n': sb ~= `\n`; break;
            case '\r': sb ~= `\r`; break;
            case '\t': sb ~= `\t`; break;
            default:
                if (c < 0x20) {
                    sb ~= format(`\u%04x`, c);
                } else {
                    sb ~= c;
                }
                break;
        }
    }
    return sb.data;
}

string renderLua(ref const Val v, int indent = 0, bool pretty = true) {
    auto sb = appender!string;
    void pad(int n) { if (pretty) foreach (_; 0 .. n) sb ~= "  "; }

    final switch (v.kind) {
        case Val.Kind.Null:  sb ~= "nil"; break;
        case Val.Kind.Bool:  sb ~= v.b ? "true" : "false"; break;
        case Val.Kind.Int:   sb ~= to!string(v.i); break;
        case Val.Kind.UInt:  sb ~= to!string(v.u); break;
        case Val.Kind.Float: sb ~= to!string(v.f); break;
        case Val.Kind.Str:   sb ~= `"` ~ escapeLuaString(v.s) ~ `"`; break;
        case Val.Kind.Arr:
            sb ~= "{";
            if (pretty && v.arr.length > 0) sb ~= "\n";
            foreach (i, e; v.arr) {
                pad(indent + 1);
                sb ~= renderLua(e, indent + 1, pretty);
                if (i + 1 < v.arr.length) sb ~= ",";
                if (pretty) sb ~= "\n";
            }
            pad(indent);
            sb ~= "}";
            break;
        case Val.Kind.Obj:
            sb ~= "{";
            if (pretty && v.obj.length > 0) sb ~= "\n";
            foreach (i, kv; v.obj) {
                pad(indent + 1);
                sb ~= kv[0] ~ " = " ~ renderLua(kv[1], indent + 1, pretty);
                if (i + 1 < v.obj.length) sb ~= ",";
                if (pretty) sb ~= "\n";
            }
            pad(indent);
            sb ~= "}";
            break;
    }
    return sb.data;
}

string renderJson(ref const Val v, int indent = 0, bool pretty = true) {
    auto sb = appender!string;
    void pad(int n) { if (pretty) foreach (_; 0 .. n) sb ~= "  "; }

    final switch (v.kind) {
        case Val.Kind.Null:  sb ~= "null"; break;
        case Val.Kind.Bool:  sb ~= v.b ? "true" : "false"; break;
        case Val.Kind.Int:   sb ~= to!string(v.i); break;
        case Val.Kind.UInt:  sb ~= to!string(v.u); break;
        case Val.Kind.Float: sb ~= to!string(v.f); break;
        case Val.Kind.Str:   sb ~= `"` ~ escapeJsonString(v.s) ~ `"`; break;
        case Val.Kind.Arr:
            sb ~= "[";
            if (pretty && v.arr.length > 0) sb ~= "\n";
            foreach (i, e; v.arr) {
                pad(indent + 1);
                sb ~= renderJson(e, indent + 1, pretty);
                if (i + 1 < v.arr.length) sb ~= ",";
                if (pretty) sb ~= "\n";
            }
            pad(indent);
            sb ~= "]";
            break;
        case Val.Kind.Obj:
            sb ~= "{";
            if (pretty && v.obj.length > 0) sb ~= "\n";
            foreach (i, kv; v.obj) {
                pad(indent + 1);
                sb ~= `"` ~ escapeJsonString(kv[0]) ~ `": ` ~ renderJson(kv[1], indent + 1, pretty);
                if (i + 1 < v.obj.length) sb ~= ",";
                if (pretty) sb ~= "\n";
            }
            pad(indent);
            sb ~= "}";
            break;
    }
    return sb.data;
}

enum OutputFormat { Lua, Json }

OutputFormat parseFormat(HTTPServerRequest req) {
    string f = req.query.get("format", "lua").toLower();
    if (f == "json") return OutputFormat.Json;
    return OutputFormat.Lua;
}

void writeFormatted(HTTPServerResponse res, ref const Val v, OutputFormat fmt, bool pretty = true) {
    string body;
    string contentType;
    final switch (fmt) {
        case OutputFormat.Lua:
            body = renderLua(v, 0, pretty);
            contentType = "text/x-lua; charset=utf-8";
            break;
        case OutputFormat.Json:
            body = renderJson(v, 0, pretty);
            contentType = "application/json; charset=utf-8";
            break;
    }
    res.headers["Content-Type"] = contentType;
    res.writeBody(body);
}