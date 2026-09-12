import std.stdio;
import vibe.vibe;
import system.debugwriteln;
import system.hpf;
import db.users;
import db.bets;
import networking.incoming;
import networking.outcoming;
import variables;
import system.config;

void preloader() {
	debugWriteln("Loading all values into RAM");
	loadAllUsersData();
	loadAllBetsData();
}

void main(string[] args)
{
	debugWriteln("mitsubishi galant 67 eshkere startuet, testiruem");
	if (args.length <= 1) {
		debugWriteln("HELP: [data-path-absolute] [port]");
		return;
	}
	preloader();

	auto router = new URLRouter;

	router.get("*", serveStaticFiles("/"~systemSettings.pathToData~"/assets/"));

	// outcoming
	router.get("/userInfo", &userInfo);
	router.get("/betInfo", &betInfo);
	router.get("/flush", &flushData);

	// incoming
	router.post("/userRegister", &registerUser);
	router.post("/userLogin", &loginUser);
	router.post("/userUpdateBalance", &updateUserBalance);

	// bets
	router.post("/betRegister", &registerBet);
	router.post("/betTakePart", &takePartInBet);
	router.post("/betUntakePart", &untakePartInBet);
	router.post("/betRemove", &removeBet);
	router.post("/betStopAuction", &stopBetAuction);
	router.post("/betSetResult", &setBetResult);

	auto settings = new HTTPServerSettings;
	settings.port = args[3].to!ushort;
	settings.bindAddresses = [args[2].to!string];
	listenHTTP(settings, router);
	runApplication();
}