module networking.format;

import vibe.vibe;
import vibe.data.json;

void writeJson(HTTPServerResponse res, Json j, bool pretty = true) {
    res.headers["Content-Type"] = "application/json; charset=utf-8";
    res.writeBody(pretty ? j.toPrettyString() : j.toString());
}