module networking.outcoming;

import system.debugwriteln;
import db.users;
import db.bets;
import db.images;
import variables;
import vibe.vibe;
import std.conv;
import networking.format;
import std.typecons;

Val userToVal(uint userId) {
    User u = getUserById(userId);
    Tuple!(string, Val)[] obj;

    obj ~= tuple("id",        Val.uint_(u.id));
    obj ~= tuple("name",      Val.str(u.nickname));
    obj ~= tuple("balance",   Val.uint_(u.balance));
    obj ~= tuple("betsCount", Val.uint_(u.betsDone));

    Val[] betsArr, betsNamesArr;
    foreach (idx; u.betsIndexes) {
        betsArr ~= Val.uint_(idx);
        Bet b = getBetById(idx);
        betsNamesArr ~= Val.str(b.id != 0 ? b.betName : "<missing>");
    }
    obj ~= tuple("bets",      Val.arr_(betsArr));
    obj ~= tuple("betsNames", Val.arr_(betsNamesArr));

    return Val.obj_(obj);
}

Val betToVal(uint betId) {
    Bet b = getBetById(betId);
    Tuple!(string, Val)[] obj;

    obj ~= tuple("id",                  Val.uint_(b.id));
    obj ~= tuple("name",                Val.str(b.betName));
    obj ~= tuple("price",               Val.uint_(b.price));
    obj ~= tuple("participantOneIndex", Val.uint_(b.participantOne));
    obj ~= tuple("participantTwoIndex", Val.uint_(b.participantTwo));
    obj ~= tuple("unixTimestamp",       Val.uint_(b.unixTimestamp));
    obj ~= tuple("status",              Val.bool_(b.status));
    obj ~= tuple("description",         Val.str(b.description));

    User p1 = getUserById(b.participantOne);
    User p2 = getUserById(b.participantTwo);
    obj ~= tuple("participantOneName", Val.str(p1.nickname));
    obj ~= tuple("participantTwoName", Val.str(p2.nickname));

    Val[] imagesArr;
    foreach (idx; b.imageIndexes) imagesArr ~= Val.uint_(idx);
    obj ~= tuple("images", Val.arr_(imagesArr));

    return Val.obj_(obj);
}

void userInfo(HTTPServerRequest req, HTTPServerResponse res) {
    string idStr = req.query.get("id", "0");
    uint userId = to!uint(idStr);

    if (!userExists(userId)) {
        res.statusCode = 404;
        auto fmt = parseFormat(req);
        if (fmt == OutputFormat.Json) {
            res.headers["Content-Type"] = "application/json";
            res.writeBody(`{"error":"no_user"}`);
        } else {
            res.headers["Content-Type"] = "text/x-lua";
            res.writeBody(`{ error = "no_user" }`);
        }
        return;
    }

    auto fmt = parseFormat(req);
    auto v = userToVal(userId);
    writeFormatted(res, v, fmt);
}

void betInfo(HTTPServerRequest req, HTTPServerResponse res) {
    string idStr = req.query.get("id", "0");
    uint betId = to!uint(idStr);

    if (!betExists(betId)) {
        res.statusCode = 404;
        auto fmt = parseFormat(req);
        if (fmt == OutputFormat.Json) {
            res.headers["Content-Type"] = "application/json";
            res.writeBody(`{"error":"no_bet"}`);
        } else {
            res.headers["Content-Type"] = "text/x-lua";
            res.writeBody(`{ error = "no_bet" }`);
        }
        return;
    }

    auto fmt = parseFormat(req);
    auto v = betToVal(betId);
    writeFormatted(res, v, fmt);
}

void imageInfo(HTTPServerRequest req, HTTPServerResponse res) {
    string idStr = req.query.get("id", "0");
    uint imageId = to!uint(idStr);

    ubyte[] data = getImage(imageId);
    if (data.length == 0) {
        res.statusCode = 404;
        res.writeBody("not found");
        return;
    }

    res.headers["Content-Type"] = getImageMime(imageId);
    res.writeBody(data);
}