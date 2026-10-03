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

    // SQLite открывается сразу, схема создаётся при первом запуске.
    // Данные подгружаются on-demand — кэш в памяти больше не нужен.
    initDatabase(pathToData);

    auto router = new URLRouter;
    router.get("*", serveStaticFiles(pathToData ~ "/assets/"));

    // outcoming
    router.get("/userInfo",  &userInfo);
    router.get("/betInfo",   &betInfo);
    router.get("/imageInfo", &imageInfo);
    router.get("/flush",     &flushData);

    // incoming
    router.post("/userRegister",      &registerUser);
    router.post("/userLogin",         &loginUser);
    router.post("/userUpdateBalance", &updateUserBalance);

    // bets
    router.post("/betRegister",     &registerBet);
    router.post("/betTakePart",     &takePartInBet);
    router.post("/betUntakePart",   &untakePartInBet);
    router.post("/betRemove",       &removeBet);
    router.post("/betStopAuction",  &stopBetAuction);
    router.post("/betSetResult",    &setBetResult);

    // images
    router.post("/imageUpload", &uploadImage);

    auto settings = new HTTPServerSettings;
    settings.port = args[3].to!ushort;
    settings.bindAddresses = [args[2].to!string];
    listenHTTP(settings, router);
    runApplication();
}