// quantumde1 developed software, licensed under MIT license.
module variables;

/* system */

struct ParsedChunk {
    int offset;
    int length;
}

struct Bet {
    string betName;
    uint price;
    uint participantOne;
    uint participantTwo;
    uint unixTimestamp;
    bool status;
}

struct User {
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

/* booleans */


/* strings */


/* floats */


/* integers */

/* archives */
ParsedChunk[][] parsedChunks;

/* data */
Bet[] bets;
bool[] betsState; // used for monitoring state of bets for exiting them by participant two, false means can be exited, true - cannot

User[] users;