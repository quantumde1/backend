module networking.incoming;

import system.debugwriteln;
import variables;
import vibe.vibe;
import vibe.data.json;
import db.users;
import db.lots;
import db.images;
import std.datetime;
import std.base64;
import std.conv;
void registerUser(HTTPServerRequest req, HTTPServerResponse res) {
    debugWriteln("registering user");
    Json j = req.json;
    string nickname = j["nickname"].get!string;
    string passwordHash = j["passwordHash"].get!string;

    if (getUserByNickname(nickname).id != 0) {
        res.statusCode = 409;
        res.writeBody("error_user_exists");
        return;
    }

    createUser(nickname, passwordHash);
    debugWriteln("registered successfully: ", nickname);
    res.statusCode = 200;
    res.writeBody(nickname ~ " success\n");
}

void loginUser(HTTPServerRequest req, HTTPServerResponse res) {
    debugWriteln("logging in user");
    Json j = req.json;
    string passwordHash = j["passwordHash"].get!string;
    string nickname     = j["nickname"].get!string;

    User u = getUserByNickname(nickname);
    if (u.id == 0) {
        res.writeBody("error_no_user");
        return;
    }
    if (passwordHash == u.hashedPassword) {
        res.statusCode = 200;
        res.writeBody(u.id.to!string);
    } else {
        res.writeBody("error_incorrect_pwd");
    }
}

import system.lzss;

void uploadImage(HTTPServerRequest req, HTTPServerResponse res) {
    debugWriteln("uploading image");
    Json j = req.json;
    if ("data" !in j) { res.writeBody("error_no_data"); return; }

    string base64Data = j["data"].get!string;
    ubyte[] imageData;
    try {
        imageData = cast(ubyte[])Base64.decode(base64Data);
    } catch (Exception e) {
        debugWriteln("bad base64 image: ", e.msg);
        res.writeBody("error_bad_base64");
        return;
    }
    if (imageData.length == 0) { res.writeBody("error_empty_image"); return; }

    uint newIndex = addImage(imageData);
    res.statusCode = 200;
    res.writeBody(newIndex.to!string);
}

void registerlot(HTTPServerRequest req, HTTPServerResponse res) {
    debugWriteln("creating Lot");
    Json j = req.json;
    string lotName     = j["lotname"].get!string;
    uint price         = j["price"].get!uint;
    uint participantOne = j["participantOne"].get!uint;

    string description = "";
    if ("description" in j) {
        description = j["description"].get!string;
        if (description.length > 128) description = description[0 .. 128];
    }

    uint[10] imageIndexes;
    imageIndexes[] = NO_IMAGE;
    if ("images" in j) {
        auto imgs = j["images"];
        foreach (i; 0 .. imgs.length > 10 ? 10 : imgs.length)
            imageIndexes[i] = imgs[i].get!uint;
    }

    User u = getUserById(participantOne);
    if (u.id == 0) { res.writeBody("error_no_user"); return; }
    if (price > u.balance) { res.writeBody("error_price_high"); return; }

    uint newlotIndex = createlot(lotName, price, participantOne, description, imageIndexes);
    debugWriteln("created Lot #", newlotIndex, " '", lotName, "' by user ", participantOne);
    res.statusCode = 200;
    res.writeBody("success");
}

void updateUserBalance(HTTPServerRequest req, HTTPServerResponse res) {
    debugWriteln("updating user balance");
    Json j = req.json;
    uint balance      = j["balance"].get!uint;
    uint userToUpdate = j["userId"].get!uint;

    if (!userExists(userToUpdate)) { res.writeBody("error_no_user"); return; }
    setUserBalance(userToUpdate, balance);
    res.statusCode = 200;
    res.writeBody("success");
}

void takePartInlot(HTTPServerRequest req, HTTPServerResponse res) {
    Json j = req.json;
    uint userId   = j["userId"].get!uint;
    uint lotId    = j["lotId"].get!uint;
    uint lotPrice = j["lotPrice"].get!uint;

    if (!userExists(userId) || !lotExists(lotId)) {
        res.writeBody("error_no_such"); return;
    }
    Lot b = getlotById(lotId);
    if (b.status == true) {
        debugWriteln("cannot change max Lot");
        res.writeBody("error_cannot_change_state");
        return;
    }
    User u = getUserById(userId);

    if (lotPrice < b.price) { res.writeBody("error_price_lower_than_before"); return; }
    if (u.balance < b.price) { res.writeBody("error_price_high"); return; }

    bool already = userInlot(userId, lotId);

    setlotParticipantTwo(lotId, userId);
    setlotPrice(lotId, lotPrice);
    if (!already) addUserTolot(userId, lotId);

    res.statusCode = 200;
    res.writeBody("success");
}

void untakePartInlot(HTTPServerRequest req, HTTPServerResponse res) {
    Json j = req.json;
    uint userId = j["userId"].get!uint;
    uint lotId  = j["lotId"].get!uint;

    Lot b = getlotById(lotId);
    if (b.id == 0) { res.writeBody("error_no_lot"); return; }

    if (b.status == true || b.participantOne == userId) {
        debugWriteln("cannot untake");
        res.writeBody("error_cannot_untake");
        return;
    }

    setlotParticipantTwo(lotId, 0);
    removeUserFromlot(userId, lotId);
    debugWriteln("removed participant!");
    res.statusCode = 200;
    res.writeBody("success");
}

void removelot(HTTPServerRequest req, HTTPServerResponse res) {
    Json j = req.json;
    uint userId = j["userId"].get!uint;
    uint lotId  = j["lotId"].get!uint;

    Lot b = getlotById(lotId);
    if (b.id == 0) { res.writeBody("error_no_lot"); return; }
    if (userId != b.participantOne) {
        res.writeBody("error_not_creator");
        return;
    }

    deletelot(lotId);
    res.statusCode = 200;
    res.writeBody("success");
}

void stoplotAuction(HTTPServerRequest req, HTTPServerResponse res) {
    Json j = req.json;
    uint lotId = j["lotId"].get!uint;
    if (!lotExists(lotId)) { res.writeBody("error_no_lot"); return; }
    setlotStatus(lotId, true);
    res.statusCode = 200;
    res.writeBody("success");
}

void setlotResult(HTTPServerRequest req, HTTPServerResponse res) {
    Json j = req.json;
    uint lotIndex = j["lotId"].get!uint;

    Lot b = getlotById(lotIndex);
    if (b.id == 0) { res.writeBody("error_no_lot"); return; }
    if (b.participantTwo == 0) { res.writeBody("error_no_participant_two"); return; }
    if (b.status == true) { res.writeBody("error_already_settled"); return; }

    User p1 = getUserById(b.participantOne);
    User p2 = getUserById(b.participantTwo);

    setUserBalance(p1.id, p1.balance + b.price);
    setUserBalance(p2.id, p2.balance - b.price);
    setlotStatus(lotIndex, true);

    res.statusCode = 200;
    res.writeBody("success");
}