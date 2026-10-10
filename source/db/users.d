module db.users;

import d2sqlite3;
import system.debugwriteln;
import variables;
import db.database;

private User userFromRow(Row row) {
    User u;
    u.id = cast(uint)row[0].as!long;
    u.nickname = row[1].as!string;
    u.hashedPassword = row[2].as!string;
    u.balance = cast(uint)row[3].as!long;
    return u;
}

User getUserById(uint id) {
    User u;
    foreach (row; database.execute(
        "SELECT id, nickname, hashed_password, balance FROM users WHERE id = ?",
        cast(long)id))
    {
        u = userFromRow(row);
        break;
    }
    if (u.id == 0) return u;
    loadUserlots(u);
    return u;
}

User getUserByNickname(string nickname) {
    User u;
    foreach (row; database.execute(
        "SELECT id, nickname, hashed_password, balance FROM users WHERE nickname = ?",
        nickname))
    {
        u = userFromRow(row);
        break;
    }
    if (u.id == 0) return u;
    loadUserlots(u);
    return u;
}

void loadUserlots(ref User u) {
    uint[] lotIds;
    foreach (row; database.execute(
        "SELECT id FROM lots WHERE participant_one = ? OR participant_two = ? ORDER BY id",
        cast(long)u.id, cast(long)u.id))
    {
        lotIds ~= cast(uint)row[0].as!long;
    }
    u.lotsIndexes = lotIds;
    u.lotsDone = cast(uint)lotIds.length;
}

bool userExists(uint id) {
    foreach (row; database.execute("SELECT 1 FROM users WHERE id = ? LIMIT 1", cast(long)id))
        return true;
    return false;
}

uint createUser(string nickname, string hashedPassword, uint balance = 0) {
    foreach (row; database.execute("SELECT 1 FROM users WHERE nickname = ? LIMIT 1", nickname))
        return 0;
    database.execute(
        "INSERT INTO users (nickname, hashed_password, balance) VALUES (?, ?, ?)",
        nickname, hashedPassword, cast(long)balance);
    return cast(uint)database.lastInsertRowid;
}

void setUserBalance(uint userId, uint balance) {
    database.execute("UPDATE users SET balance = ? WHERE id = ?",
               cast(long)balance, cast(long)userId);
}

bool userInLot(uint userId, uint lotId) {
    foreach (row; database.execute(
        "SELECT 1 FROM lots WHERE id = ? AND (participant_one = ? OR participant_two = ?) LIMIT 1",
        cast(long)lotId, cast(long)userId, cast(long)userId))
        return true;
    return false;
}