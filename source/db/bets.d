module db.bets;

import d2sqlite3;
import system.debugwriteln;
import variables;
import db.database;
import db.users;
import std.datetime : Clock;

Bet getBetById(uint id) {
    Bet b;
    foreach (row; database.execute("
        SELECT id, bet_name, price, participant_one, participant_two,
               unix_timestamp, status, description,
               image_slot_0, image_slot_1, image_slot_2
        FROM bets WHERE id = ?", cast(long)id))
    {
        b.id             = cast(uint)row[0].as!long;
        b.betName        = row[1].as!string;
        b.price          = cast(uint)row[2].as!long;
        b.participantOne = cast(uint)row[3].as!long;
        b.participantTwo = cast(uint)row[4].as!long;
        b.unixTimestamp  = cast(uint)row[5].as!long;
        b.status         = row[6].as!long != 0;
        b.description    = row[7].as!string;
        b.imageIndexes[0] = cast(uint)row[8].as!long;
        b.imageIndexes[1] = cast(uint)row[9].as!long;
        b.imageIndexes[2] = cast(uint)row[10].as!long;
        break;
    }
    return b;
}

bool betExists(uint id) {
    foreach (row; database.execute("SELECT 1 FROM bets WHERE id = ? LIMIT 1", cast(long)id))
        return true;
    return false;
}

uint createBet(string betName, uint price, uint participantOne,
               string description, uint[3] imageIndexes)
{
    uint ts = cast(uint)Clock.currTime().toUnixTime();
    database.execute("
        INSERT INTO bets
            (bet_name, price, participant_one, participant_two,
             unix_timestamp, status, description,
             image_slot_0, image_slot_1, image_slot_2)
        VALUES (?, ?, ?, NULL, ?, 0, ?, ?, ?, ?)",
        betName,
        cast(long)price,
        cast(long)participantOne,
        cast(long)ts,
        description,
        cast(long)imageIndexes[0],
        cast(long)imageIndexes[1],
        cast(long)imageIndexes[2]);

    uint betId = cast(uint)database.lastInsertRowid;
    addUserToBet(participantOne, betId);
    return betId;
}

void setBetParticipantTwo(uint betId, uint userId) {
    if (userId == 0)
        database.execute("UPDATE bets SET participant_two = NULL WHERE id = ?", cast(long)betId);
    else
        database.execute("UPDATE bets SET participant_two = ? WHERE id = ?",
                         cast(long)userId, cast(long)betId);
}

void setBetPrice(uint betId, uint price) {
    database.execute("UPDATE bets SET price = ? WHERE id = ?", cast(long)price, cast(long)betId);
}

void setBetStatus(uint betId, bool status) {
    database.execute("UPDATE bets SET status = ? WHERE id = ?",
                     cast(long)(status ? 1 : 0), cast(long)betId);
}

void deleteBet(uint betId) {
    database.execute("DELETE FROM bets WHERE id = ?", cast(long)betId);
}