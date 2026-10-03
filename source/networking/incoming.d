module networking.incoming;

import system.debugwriteln;
import variables;
import vibe.vibe;
import vibe.data.json;
import db.users;
import db.bets;
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

void registerBet(HTTPServerRequest req, HTTPServerResponse res) {
    debugWriteln("creating bet");
    Json j = req.json;
    string betName     = j["betname"].get!string;
    uint price         = j["price"].get!uint;
    uint participantOne = j["participantOne"].get!uint;

    string description = "";
    if ("description" in j) {
        description = j["description"].get!string;
        if (description.length > 128) description = description[0 .. 128];
    }

    uint[3] imageIndexes = [NO_IMAGE, NO_IMAGE, NO_IMAGE];
    if ("images" in j) {
        auto imgs = j["images"];
        for (int i = 0; i < 3; i++)
            if (i < imgs.length) imageIndexes[i] = imgs[i].get!uint;
    }

    User u = getUserById(participantOne);
    if (u.id == 0) { res.writeBody("error_no_user"); return; }
    if (price > u.balance) { res.writeBody("error_price_high"); return; }

    uint newBetIndex = createBet(betName, price, participantOne, description, imageIndexes);
    debugWriteln("created bet #", newBetIndex, " '", betName, "' by user ", participantOne);
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

void takePartInBet(HTTPServerRequest req, HTTPServerResponse res) {
    Json j = req.json;
    uint userId   = j["userId"].get!uint;
    uint betId    = j["betId"].get!uint;
    uint betPrice = j["betPrice"].get!uint;

    if (!userExists(userId) || !betExists(betId)) {
        res.writeBody("error_no_such"); return;
    }
    Bet b = getBetById(betId);
    User u = getUserById(userId);

    if (betPrice < b.price) { res.writeBody("error_price_lower_than_before"); return; }
    if (u.balance < b.price) { res.writeBody("error_price_high"); return; }

    bool already = userInBet(userId, betId);

    setBetParticipantTwo(betId, userId);
    setBetPrice(betId, betPrice);
    if (!already) addUserToBet(userId, betId);

    res.statusCode = 200;
    res.writeBody("success");
}

void untakePartInBet(HTTPServerRequest req, HTTPServerResponse res) {
    Json j = req.json;
    uint userId = j["userId"].get!uint;
    uint betId  = j["betId"].get!uint;

    Bet b = getBetById(betId);
    if (b.id == 0) { res.writeBody("error_no_bet"); return; }

    if (b.status == true || b.participantOne == userId) {
        debugWriteln("cannot untake");
        res.writeBody("error_cannot_untake");
        return;
    }

    setBetParticipantTwo(betId, 0);
    removeUserFromBet(userId, betId);
    debugWriteln("removed participant!");
    res.statusCode = 200;
    res.writeBody("success");
}

void removeBet(HTTPServerRequest req, HTTPServerResponse res) {
    Json j = req.json;
    uint userId = j["userId"].get!uint;
    uint betId  = j["betId"].get!uint;

    Bet b = getBetById(betId);
    if (b.id == 0) { res.writeBody("error_no_bet"); return; }
    if (userId != b.participantOne) {
        res.writeBody("error_not_creator");
        return;
    }

    deleteBet(betId);
    res.statusCode = 200;
    res.writeBody("success");
}

void stopBetAuction(HTTPServerRequest req, HTTPServerResponse res) {
    Json j = req.json;
    uint betId = j["betId"].get!uint;
    if (!betExists(betId)) { res.writeBody("error_no_bet"); return; }
    setBetStatus(betId, true);
    res.statusCode = 200;
    res.writeBody("success");
}

void setBetResult(HTTPServerRequest req, HTTPServerResponse res) {
    Json j = req.json;
    uint betIndex = j["betId"].get!uint;

    Bet b = getBetById(betIndex);
    if (b.id == 0) { res.writeBody("error_no_bet"); return; }
    if (b.participantTwo == 0) { res.writeBody("error_no_participant_two"); return; }
    if (b.status == true) { res.writeBody("error_already_settled"); return; }

    User p1 = getUserById(b.participantOne);
    User p2 = getUserById(b.participantTwo);

    setUserBalance(p1.id, p1.balance + b.price);
    setUserBalance(p2.id, p2.balance - b.price);
    setBetStatus(betIndex, true);

    res.statusCode = 200;
    res.writeBody("success");
}

// SQLite пишет сразу — flush больше не нужен. Оставлен для совместимости.
void flushData(HTTPServerRequest req, HTTPServerResponse res) {
    debugWriteln("flush: SQLite stores data immediately, noop");
    res.headers["Content-Type"] = "text/plain";
    res.statusCode = 200;
    res.writeBody("success");
}