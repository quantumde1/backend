module db.bets;

import system.debugwriteln;
import system.hpf;
import variables;
import system.uintreader;

/*
every bet uses 32 bytes for its name, its cost in uint24(3 bytes), and participants(indexes of them, uint32), also UNIX timestamp in uint32, and 1 byte for state
*/
void loadAllBetsData() {
    debugWriteln("Loading bets into RAM");
    if (parsedChunks.length == 0) {
        parsedChunks.length = 3;
    }
    parsedChunks[1] = parseArchive(pathToData~"data/db/bets.hpf");
    bets.length = 0;
    
    for (int i = 0; i < parsedChunks[1].length; i++) {
        ubyte[] data = loadFileFromHPF("data/db/bets.hpf", parsedChunks[1], cast(int)i);
        if (data.length < 48) {
            debugWriteln("chunk ", i, " too small, skipping");
            continue;
        }
        char[32] nameBuf;
        nameBuf[] = cast(char[])data[0 .. 32];
        size_t nameEnd = 0;
        while (nameEnd < 32 && nameBuf[nameEnd] != 0) {
            nameEnd++;
        }
        string betname = nameBuf[0..nameEnd].idup;
        uint price = readUInt24(data, 32);
        uint firstUser = readUInt32(data, 35);
        uint secondUser = readUInt32(data, 39);
        uint unixTimestamp = readUInt32(data, 43);
        bool state = cast(bool)data[47];
        bets ~= Bet(betname, price, firstUser, secondUser, unixTimestamp, state);
        debugWriteln(bets[i]);
    }
    debugWriteln("setting betsState to same length");
    betsState.length = bets.length;
    for (int i = 0; i < betsState.length; i++) {
        if (betsState[i] != true) {
            betsState[i] = false;
        }
    }
}

ubyte[] serializeBet(Bet b) {
    ubyte[] result = new ubyte[48];

    foreach (i; 0 .. 32) {
        result[i] = (i < b.betName.length) ? cast(ubyte)b.betName[i] : 0;
    }

    // цена (uint24, little-endian)
    result[32] = cast(ubyte)(b.price & 0xFF);
    result[33] = cast(ubyte)((b.price >> 8) & 0xFF);
    result[34] = cast(ubyte)((b.price >> 16) & 0xFF);

    // participantOne (uint32, little-endian)
    result[35] = cast(ubyte)(b.participantOne & 0xFF);
    result[36] = cast(ubyte)((b.participantOne >> 8) & 0xFF);
    result[37] = cast(ubyte)((b.participantOne >> 16) & 0xFF);
    result[38] = cast(ubyte)((b.participantOne >> 24) & 0xFF);

    // participantTwo (uint32, little-endian)
    result[39] = cast(ubyte)(b.participantTwo & 0xFF);
    result[40] = cast(ubyte)((b.participantTwo >> 8) & 0xFF);
    result[41] = cast(ubyte)((b.participantTwo >> 16) & 0xFF);
    result[42] = cast(ubyte)((b.participantTwo >> 24) & 0xFF);

    // unixTimestamp (uint32, little-endian)
    result[43] = cast(ubyte)(b.unixTimestamp & 0xFF);
    result[44] = cast(ubyte)((b.unixTimestamp >> 8) & 0xFF);
    result[45] = cast(ubyte)((b.unixTimestamp >> 16) & 0xFF);
    result[46] = cast(ubyte)((b.unixTimestamp >> 24) & 0xFF);

    // status
    result[47] = b.status ? 1 : 0;

    return result;
}