module db.users;

import system.debugwriteln;
import system.hpf;
import variables;
import system.uintreader;
import std.conv;

/* one user takes 
16 bytes - nickname in ASCII
32 bytes - hashed password
4 bytes - balance in uint32
3 bytes - how much bets was already done in uint24(for ram economy lmfaooo)
every bet is stored as index which points into bets.hpf
*/

// use only for testing
// use only for testing
void loadAllUsersData() {
    debugWriteln("Loading users into RAM");
    if (parsedChunks.length == 0) {
        parsedChunks.length = 3;
    }
    parsedChunks[0] = parseArchive(systemSettings.pathToData~"data/db/users.hpf");
    users.length = 0;
    
    for (int i = 0; i < parsedChunks[0].length; i++) {
        ubyte[] data = loadFileFromHPF("data/db/users.hpf", parsedChunks[0], cast(int)i);
        
        if (data.length < 55) {
            debugWriteln("chunk ", i, " too small (", data.length, "), skipping");
            continue;
        }
        
        char[16] nameBuf;
        nameBuf[] = cast(char[]) data[0 .. 16];
        size_t nameEnd = 0;
        while (nameEnd < 16 && nameBuf[nameEnd] != 0) nameEnd++;
        string nickname = nameBuf[0 .. nameEnd].idup;
        
        char[32] passwordHash;
        passwordHash[] = cast(char[]) data[16 .. 48];
        size_t passwordEnd = 0;
        while (passwordEnd < 32 && passwordHash[passwordEnd] != 0) passwordEnd++;
        string password = passwordHash[0 .. passwordEnd].idup;
        
        uint balance = readUInt32(data, 48);
        
        uint betsDone = readUInt24(data, 52);
        
        uint[] betsIndexes;
        betsIndexes.reserve(betsDone);
        for (uint j = 0; j < betsDone; j++) {
            size_t offset = 55 + j * 3;
            if (offset + 3 > data.length) {
                debugWriteln("chunk ", i, ": bet index ", j, " out of bounds");
                break;
            }
            betsIndexes ~= readUInt24(data, offset);
        }
        
        users ~= User(nickname, password, balance, betsDone, betsIndexes);
        debugWriteln(users[$-1]);
    }
}

ubyte[] serializeUser(User u) {
    size_t totalSize = 16 + 32 + 4 + 3 + u.betsIndexes.length * 3;
    ubyte[] result = new ubyte[totalSize];

    for (int i = 0; i < 16; i++) {
        result[i] = (i < u.nickname.length) ? cast(ubyte)u.nickname[i] : 0;
    }

    for (int i = 0; i < 32; i++) {
        result[16 + i] = (i < u.hashedPassword.length) ? cast(ubyte)u.hashedPassword[i] : 0;
    }

    // balance (uint32, little-endian)
    result[48] = cast(ubyte)(u.balance & 0xFF);
    result[49] = cast(ubyte)((u.balance >> 8) & 0xFF);
    result[50] = cast(ubyte)((u.balance >> 16) & 0xFF);
    result[51] = cast(ubyte)((u.balance >> 24) & 0xFF);

    // betsDone (uint24, little-endian)
    uint betsDone = cast(uint)u.betsIndexes.length;
    result[52] = cast(ubyte)(betsDone & 0xFF);
    result[53] = cast(ubyte)((betsDone >> 8) & 0xFF);
    result[54] = cast(ubyte)((betsDone >> 16) & 0xFF);

    foreach (j, idx; u.betsIndexes) {
        size_t off = 55 + j * 3;
        result[off]     = cast(ubyte)(idx & 0xFF);
        result[off + 1] = cast(ubyte)((idx >> 8) & 0xFF);
        result[off + 2] = cast(ubyte)((idx >> 16) & 0xFF);
    }

    return result;
}