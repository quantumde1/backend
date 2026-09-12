module networking.incoming;

import system.debugwriteln;
import variables;
import vibe.vibe;
import vibe.data.json;
import system.hpf;
import db.users;
import db.bets;
import db.images;
import std.array;
import std.datetime;
import std.range;
import std.algorithm;
import std.base64;
import std.conv;

void registerUser(HTTPServerRequest req, HTTPServerResponse res) {
    debugWriteln("registering user in RAM");
    Json registerJson = req.json;

    string nickname = registerJson["nickname"].get!string;
    string passwordHash = registerJson["passwordHash"].get!string;
    uint balance = 0;
    uint betsDone = 0;
    uint[] betsIndexes;
    users ~= User(nickname, passwordHash, balance, betsDone, betsIndexes);
    debugWriteln("registered successfully: ", nickname);
    res.statusCode = 200;
    res.writeBody(nickname~" success\n");
}

void loginUser(HTTPServerRequest req, HTTPServerResponse res) {
    debugWriteln("logging in user in RAM");
    Json loginJson = req.json;
    string passwordHash = loginJson["passwordHash"].get!string;
    string nickname = loginJson["nickname"].get!string;
    uint userId;
    for (int i = 0; i < users.length; i++) {
        if (users[i].nickname == nickname) {
            userId = i;
            debugWriteln("user index: ", i);
        }
    }
    if (userId == 0) {
        debugWriteln("user not found");
        res.writeBody("error_no_user");
        return;
    }
    if (passwordHash == users[userId].hashedPassword) {
        res.writeBody(userId.to!string);
        res.statusCode = 200;
    } else {
        res.writeBody("error_incorrect_pwd");
        debugWriteln("incorrent pwd entered for user: ", userId);
        return;
    }
    res.statusCode = 200;
}

void uploadImage(HTTPServerRequest req, HTTPServerResponse res) {
    debugWriteln("uploading lot image into RAM");
    Json uploadJson = req.json;

    if ("data" !in uploadJson) {
        res.writeBody("error_no_data");
        return;
    }
    string base64Data = uploadJson["data"].get!string;

    ubyte[] imageData;
    try {
        imageData = cast(ubyte[])Base64.decode(base64Data);
    } catch (Exception e) {
        debugWriteln("bad base64 image: ", e.msg);
        res.writeBody("error_bad_base64");
        return;
    }

    if (imageData.length == 0) {
        res.writeBody("error_empty_image");
        return;
    }

    uint newIndex = addImage(imageData);
    res.statusCode = 200;
    res.writeBody(newIndex.to!string);
}

void registerBet(HTTPServerRequest req, HTTPServerResponse res) {
    debugWriteln("creating bet in RAM");
    Json registerJson = req.json;
    string betName = registerJson["betname"].get!string;
    uint price = registerJson["price"].get!uint;
    uint participantOne = registerJson["participantOne"].get!uint;

    string description = "";
    if ("description" in registerJson) {
        description = registerJson["description"].get!string;
        if (description.length > 128) {
            description = description[0 .. 128];
        }
    }

    uint[3] imageIndexes = [NO_IMAGE, NO_IMAGE, NO_IMAGE];
    if ("images" in registerJson) {
        auto imagesJson = registerJson["images"];
        for (int i = 0; i < 3; i++) {
            if (i < imagesJson.length) {
                imageIndexes[i] = imagesJson[i].get!uint;
            }
        }
    }

    if (users.length <= participantOne) {
        debugWriteln("no such user");
        res.writeBody("error_no_user");
        return;
    }
    if (price > users[participantOne].balance) {
        debugWriteln("user balance is lower than price! stop");
        res.writeBody("error_price_high");
        return;
    }

    uint participantTwo = 0;
    uint time = cast(uint)Clock.currTime().toUnixTime();
    bool status = false;

    uint newBetIndex = cast(uint)bets.length;
    bets ~= Bet(betName, price, participantOne, participantTwo, time, status, description, imageIndexes);

    users[participantOne].betsIndexes ~= newBetIndex;
    users[participantOne].betsDone = cast(uint)users[participantOne].betsIndexes.length;

    debugWriteln("created bet #", newBetIndex, " '", betName, "' by user ", participantOne);
    res.statusCode = 200;
    res.writeBody("success");
}

void updateUserBalance(HTTPServerRequest req, HTTPServerResponse res) {
    debugWriteln("updating user balance");
    Json updateJson = req.json;
    uint balance = updateJson["balance"].get!uint;
    uint userToUpdate = updateJson["userId"].get!uint;
    if (users.length <= userToUpdate) {
        debugWriteln("no such user");
        res.writeBody("error_no_user");
        return;
    }
    users[userToUpdate].balance = balance;
    res.statusCode = 200;
    res.writeBody("success");
}

void takePartInBet(HTTPServerRequest req, HTTPServerResponse res) {
    Json partJson = req.json;
    uint userId   = partJson["userId"].get!uint;
    uint betId    = partJson["betId"].get!uint;
    uint betPrice = partJson["betPrice"].get!uint;

    if (userId >= users.length || betId >= bets.length) {
        res.writeBody("error_no_such"); return;
    }
    if (betPrice < bets[betId].price) {
        res.writeBody("error_price_lower_than_before"); return;
    }
    if (users[userId].balance < bets[betId].price) {
        res.writeBody("error_price_high"); return;
    }

    bool alreadyParticipates = users[userId].betsIndexes.canFind(betId);

    bets[betId].participantTwo = userId;
    bets[betId].price = betPrice;

    if (!alreadyParticipates) {
        users[userId].betsIndexes ~= betId;
        //users[userId].betsDone = cast(uint)users[userId].betsIndexes.length;
    }

    res.statusCode = 200;
    res.writeBody("success");
}

void untakePartInBet(HTTPServerRequest req, HTTPServerResponse res) {
    Json partJson = req.json;
    uint userId = partJson["userId"].get!uint;
    uint betId = partJson["betId"].get!uint;
    if (bets[betId].status == true || bets[betId].participantOne == userId) {
        debugWriteln("cannot untake part either cuz auction stopped or cuz you're a creator");
        res.writeBody("error_cannot_untake");
        return;
    }
    bets[betId].participantTwo = 0;
    users[userId].betsIndexes = users[userId].betsIndexes
        .filter!(i => i != betId).array;
    users[userId].betsDone = cast(uint)users[userId].betsIndexes.length;
    debugWriteln("removed participant!");
}

void removeBet(HTTPServerRequest req, HTTPServerResponse res) {
    Json partJson = req.json;
    uint userId = partJson["userId"].get!uint;
    uint betId = partJson["betId"].get!uint;
    if (userId != bets[betId].participantOne) {
        debugWriteln("You're not a creator");
        res.writeBody("error_not_creator");
        return;
    }
    bets = bets[0 .. betId].chain(bets[betId+1 .. $]).array;
    res.statusCode = 200;
    res.writeBody("success");
}

void stopBetAuction(HTTPServerRequest req, HTTPServerResponse res) {
    Json partJson = req.json;
    uint betId = partJson["betId"].get!uint;
    if (bets[betId].status == true) {
        debugWriteln("already stopped auction and cannot untake!");
        label_here:
        res.statusCode = 200;
        res.writeBody("success");
        return;
    }
    bets[betId].status = true;
    goto label_here;
}

void setBetResult(HTTPServerRequest req, HTTPServerResponse res) {
    Json partJson = req.json;
    uint betIndex  = partJson["betId"].get!uint;

    if (betIndex >= bets.length) {
        res.writeBody("error_no_bet"); return;
    }
    auto bet = bets[betIndex];
    if (bet.participantTwo == 0) {
        res.writeBody("error_no_participant_two"); return;
    }
    if (bet.status == true) {
        res.writeBody("error_already_settled"); return;
    }

    debugWriteln(bet.participantOne);
    debugWriteln(bet.participantTwo);
    users[bet.participantOne].balance += bet.price;
    users[bet.participantTwo].balance -= bet.price;
    bets[betIndex].status = true;
    res.statusCode = 200;
    res.writeBody("success");
}

void flushData(HTTPServerRequest req, HTTPServerResponse res) {
    debugWriteln("flush: recreating archives using RAM data");

    ubyte[][] userChunks;
    userChunks.reserve(users.length);
    foreach (ref u; users) {
        userChunks ~= serializeUser(u);
    }

    ubyte[][] betChunks;
    betChunks.reserve(bets.length);
    foreach (ref b; bets) {
        betChunks ~= serializeBet(b);
    }

    ubyte[][] imageChunks = images.dup;

    bool ok = true;
    string errorMsg;

    try {
        writeArchive("data/db/users.hpf", userChunks);
        writeArchive("data/db/bets.hpf", betChunks);
        writeArchive("data/db/images.hpf", imageChunks);

        if (parsedChunks.length < 3) parsedChunks.length = 3;
        parsedChunks[0] = parseArchive("data/db/users.hpf");
        parsedChunks[1] = parseArchive("data/db/bets.hpf");
        parsedChunks[2] = parseArchive("data/db/images.hpf");
    } catch (Exception e) {
        ok = false;
        errorMsg = e.msg;
        debugWriteln("flush: error: ", e.msg);
    }

    res.headers["Content-Type"] = "text/plain";
    res.statusCode = ok ? 200 : 500;
    if (ok == true) {
        users.length = 0;
        bets.length = 0;
        images.length = 0;
        debugWriteln("Reloading databases to RAM");
        loadAllUsersData();
        loadAllBetsData();
        loadAllImagesData();
    }
    res.writeBody("success");
}
