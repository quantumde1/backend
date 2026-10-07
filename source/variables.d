// quantumde1 developed software, licensed under MIT license.
module variables;

import d2sqlite3;

enum uint NO_IMAGE = 0xFFFFFF;

struct Bet {
    uint id;
    string betName;
    uint price;
    uint participantOne;
    uint participantTwo;
    uint unixTimestamp;
    bool status;
    string description;
    uint[10] imageIndexes;
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


Database database;