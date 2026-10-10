// quantumde1 developed software, licensed under MIT license.
module variables;

import d2sqlite3;

enum uint NO_IMAGE = 0xFFFFFF;

struct Lot {
    uint id;
    string lotName;
    uint price;
    uint participantOne;
    uint participantTwo;
    uint unixTimestamp;
    bool status;
    string description;
    uint[] imageIndexes;
}

struct User {
    uint id;
    string nickname;
    string hashedPassword;
    uint balance;
    uint lotsDone;
    uint[] lotsIndexes;
}

struct SystemSettings {
    string pathToData;
    string addr;
}

SystemSettings systemSettings;
string pathToData;

Database database;