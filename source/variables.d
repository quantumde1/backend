// quantumde1 developed software, licensed under MIT license.
module variables;

enum uint NO_IMAGE = 0xFFFFFF;

struct ParsedChunk {
    int offset;
    int length;
}

struct Bet {
    uint id;
    string betName;
    uint price;
    uint participantOne;
    uint participantTwo;
    uint unixTimestamp;
    bool status;
    string description;
    uint[3] imageIndexes;
}

struct User {
    uint id;
    string nickname;
    string hashedPassword;
    uint balance;
    uint betsDone;
    uint[] betsIndexes;
}

struct SystemSettings {
    string pathToData;
    string addr;
}

SystemSettings systemSettings;
string pathToData;

ParsedChunk[] imageChunks;
ubyte[][] images;