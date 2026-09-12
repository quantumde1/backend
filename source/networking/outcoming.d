module networking.outcoming;

import system.debugwriteln;
import db.users;
import db.bets;
import db.images;
import variables;
import vibe.vibe;
import std.conv;
import std.array;
import networking.format;
import std.typecons;

Val userToVal(uint userId) {
    User u = users[userId];
    Tuple!(string, Val)[] obj;

    obj ~= tuple("id", Val.uint_(userId));
    obj ~= tuple("name", Val.str(u.nickname));
    obj ~= tuple("balance", Val.uint_(u.balance));
    obj ~= tuple("betsCount", Val.uint_(u.betsDone));

    Val[] betsArr;
    Val[] betsNamesArr;
    foreach (idx; u.betsIndexes) {
        betsArr ~= Val.uint_(idx);
        if (idx < bets.length) {
            betsNamesArr ~= Val.str(bets[idx].betName);
        } else {
            betsNamesArr ~= Val.str("<missing>");
        }
    }
    obj ~= tuple("bets", Val.arr_(betsArr));
    obj ~= tuple("betsNames", Val.arr_(betsNamesArr));

    return Val.obj_(obj);
}

Val betToVal(uint betId) {
    Bet b = bets[betId];
    Tuple!(string, Val)[] obj;

    obj ~= tuple("id", Val.uint_(betId));
    obj ~= tuple("name", Val.str(b.betName));
    obj ~= tuple("price", Val.uint_(b.price));
    obj ~= tuple("participantOneIndex", Val.uint_(b.participantOne));
    obj ~= tuple("participantTwoIndex", Val.uint_(b.participantTwo));
    obj ~= tuple("unixTimestamp", Val.uint_(b.unixTimestamp));
    obj ~= tuple("status", Val.bool_(b.status));
    obj ~= tuple("description", Val.str(b.description));

    string p1 = (b.participantOne < users.length) ? users[b.participantOne].nickname : "";
    string p2 = (b.participantTwo < users.length) ? users[b.participantTwo].nickname : "";
    obj ~= tuple("participantOneName", Val.str(p1));
    obj ~= tuple("participantTwoName", Val.str(p2));

    // индексы картинок лота (NO_IMAGE = 0xFFFFFF означает отсутствие картинки в слоте)
    Val[] imagesArr;
    foreach (idx; b.imageIndexes) {
        imagesArr ~= Val.uint_(idx);
    }
    obj ~= tuple("images", Val.arr_(imagesArr));

    return Val.obj_(obj);
}

void userInfo(HTTPServerRequest req, HTTPServerResponse res) {
    string idStr = req.query.get("id", "0");
    uint userId = to!uint(idStr);

    if (userId >= users.length) {
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
    debugWriteln(fmt);
    debugWriteln(v);
    writeFormatted(res, v, fmt);
}

void betInfo(HTTPServerRequest req, HTTPServerResponse res) {
    string idStr = req.query.get("id", "0");
    uint betId = to!uint(idStr);

    if (betId >= bets.length) {
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

// отдаёт сырые байты картинки лота по её индексу в data/db/images.hpf
void imageInfo(HTTPServerRequest req, HTTPServerResponse res) {
    string idStr = req.query.get("id", "0");
    uint imageId = to!uint(idStr);

    ubyte[] data = getImage(imageId);
    if (data.length == 0) {
        res.statusCode = 404;
        res.writeBody("not found");
        return;
    }

    res.headers["Content-Type"] = detectImageMime(data);
    res.writeBody(data);
}
