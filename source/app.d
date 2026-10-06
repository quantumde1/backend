import std.stdio;
import vibe.vibe;
import system.debugwriteln;
import db.database;
import db.users;
import db.bets;
import db.images;
import networking.incoming;
import networking.outcoming;
import variables;
import system.config;

void main(string[] args)
{
    debugWriteln("mitsubishi galant 67 eshkere startuet, testiruem");
    if (args.length <= 3) {
        debugWriteln("HELP: [data-path-absolute] [address] [port]");
        return;
    }

    pathToData = args[1];
    initDatabase(pathToData);

    auto router = new URLRouter;
    router.get("*", serveStaticFiles(pathToData ~ "/assets/"));

    router.get("/userInfo",  &userInfo);
    router.get("/betInfo",   &betInfo);
    router.get("/imageInfo", &imageInfo);

    router.post("/userRegister",      &registerUser);
    router.post("/userLogin",         &loginUser);
    router.post("/userUpdateBalance", &updateUserBalance);

    router.post("/betRegister",     &registerBet);
    router.post("/betTakePart",     &takePartInBet);
    router.post("/betUntakePart",   &untakePartInBet);
    router.post("/betRemove",       &removeBet);
    router.post("/betStopAuction",  &stopBetAuction);
    router.post("/betSetResult",    &setBetResult);

    router.post("/imageUpload", &uploadImage);

    auto settings = new HTTPServerSettings;
    settings.port = args[3].to!ushort;
    settings.bindAddresses = [args[2].to!string];
    listenHTTP(settings, router);
    runApplication();
}