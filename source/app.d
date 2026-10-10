import std.stdio;
import vibe.vibe;
import system.debugwriteln;
import db.database;
import db.users;
import db.lots;
import db.images;
import networking.incoming;
import networking.outcoming;
import variables;

void main(string[] args)
{
    debugWriteln("mitsubishi galant 67 eshkere startuet, testiruem");
    if (args.length <= 3) {
        debugWriteln("HELP: [data-path-absolute] [address] [port]");
        return;
    }

    pathToData = args[1];
    initDatabase(pathToData~"/data/");

    auto router = new URLRouter;
    router.get("*", serveStaticFiles(pathToData ~ "/data/assets/"));

    router.get("/userInfo",  &userInfo);
    router.get("/lotInfo",   &lotInfo);
    router.get("/imageInfo", &imageInfo);

    router.post("/userRegister",      &registerUser);
    router.post("/userLogin",         &loginUser);
    router.post("/userUpdateBalance", &updateUserBalance);

    router.post("/lotRegister",     &registerlot);
    router.post("/lotTakePart",     &takePartInlot);
    router.post("/lotUntakePart",   &untakePartInlot);
    router.post("/lotRemove",       &removelot);
    router.post("/lotStopAuction",  &stoplotAuction);
    router.post("/lotSetResult",    &setlotResult);

    router.post("/imageUpload", &uploadImage);

    auto settings = new HTTPServerSettings;
    settings.port = args[3].to!ushort;
    settings.bindAddresses = [args[2].to!string];
    settings.maxRequestSize = 3_355_443_2;
    listenHTTP(settings, router);
    runApplication();
}