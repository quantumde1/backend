module networking.outcoming;

import system.debugwriteln;
import db.users;
import db.lots;
import db.images;
import variables;
import vibe.vibe;
import vibe.data.json;
import std.conv;

import system.lzss;

Json userToJson(uint userId) {
    User u = getUserById(userId);

    Json[] lotsArr, lotsNamesArr;
    foreach (idx; u.lotsIndexes) {
        lotsArr ~= Json(idx);
        Lot b = getlotById(idx);
        lotsNamesArr ~= Json(b.id != 0 ? b.lotName : "<missing>");
    }

    return Json([
        "id":        Json(u.id),
        "name":      Json(u.nickname),
        "balance":   Json(u.balance),
        "lotsCount": Json(u.lotsDone),
        "lots":      Json(lotsArr),
        "lotsNames": Json(lotsNamesArr),
    ]);
}

Json lotToJson(uint lotId) {
    Lot b = getlotById(lotId);

    User p1 = getUserById(b.participantOne);
    User p2 = getUserById(b.participantTwo);

    Json[] imagesArr;
    foreach (idx; b.imageIndexes) {
        debugWriteln(imagesArr.length);
        imagesArr ~= Json(idx);
    }

    return Json([
        "id":                  Json(b.id),
        "name":                Json(b.lotName),
        "price":               Json(b.price),
        "participantOneIndex": Json(b.participantOne),
        "participantTwoIndex": Json(b.participantTwo),
        "unixTimestamp":       Json(b.unixTimestamp),
        "status":              Json(b.status),
        "description":         Json(b.description),
        "participantOneName":  Json(p1.nickname),
        "participantTwoName":  Json(p2.nickname),
        "images":              Json(imagesArr),
    ]);
}

void writeJson(HTTPServerResponse res, Json j) {
    res.headers["Content-Type"] = "application/json; charset=utf-8";
    res.writeBody(j.toString());
}

void userInfo(HTTPServerRequest req, HTTPServerResponse res) {
    uint userId = to!uint(req.query.get("id", "0"));

    if (!userExists(userId)) {
        res.statusCode = 404;
        writeJson(res, Json(["error": Json("no_user")]));
        return;
    }

    writeJson(res, userToJson(userId));
}

void lotInfo(HTTPServerRequest req, HTTPServerResponse res) {
    uint lotId = to!uint(req.query.get("id", "0"));

    if (!lotExists(lotId)) {
        res.statusCode = 404;
        writeJson(res, Json(["error": Json("no_lot")]));
        return;
    }

    writeJson(res, lotToJson(lotId));
}

void imageInfo(HTTPServerRequest req, HTTPServerResponse res) {
    uint imageId = to!uint(req.query.get("id", "0"));

    ubyte[] data = getImage(imageId);
    if (data.length == 0) {
        res.statusCode = 404;
        res.writeBody("not found");
        return;
    }

    res.headers["Content-Type"] = detectImageMime(data);
    res.writeBody(data);
}