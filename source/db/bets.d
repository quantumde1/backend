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
           image_slot_0, image_slot_1, image_slot_2, image_slot_3, image_slot_4,
           image_slot_5, image_slot_6, image_slot_7, image_slot_8, image_slot_9
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
        foreach (i; 0 .. 10)
            b.imageIndexes[i] = cast(uint)row[8 + i].as!long;
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
               string description, uint[10] imageIndexes)
{
    uint ts = cast(uint)Clock.currTime().toUnixTime();
    database.execute("
        INSERT INTO bets
            (bet_name, price, participant_one, participant_two,
             unix_timestamp, status, description,
             image_slot_0, image_slot_1, image_slot_2, image_slot_3, image_slot_4,
             image_slot_5, image_slot_6, image_slot_7, image_slot_8, image_slot_9)
        VALUES (?, ?, ?, NULL, ?, 0, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        betName, cast(long)price, cast(long)participantOne, cast(long)ts, description,
        cast(long)imageIndexes[0], cast(long)imageIndexes[1], cast(long)imageIndexes[2],
        cast(long)imageIndexes[3], cast(long)imageIndexes[4], cast(long)imageIndexes[5],
        cast(long)imageIndexes[6], cast(long)imageIndexes[7], cast(long)imageIndexes[8],
        cast(long)imageIndexes[9]);
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