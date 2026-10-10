module db.users;

import d2sqlite3;
import system.debugwriteln;
import variables;
import db.database;

User getUserById(uint id) {
    User u;
    foreach (row; database.execute(
        "SELECT id, nickname, hashed_password, balance FROM users WHERE id = ?",
        cast(long)id))
    {
        u.id = cast(uint)row[0].as!long;
        u.nickname = row[1].as!string;
        u.hashedPassword = row[2].as!string;
        u.balance = cast(uint)row[3].as!long;
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
        u.id = cast(uint)row[0].as!long;
        u.nickname = row[1].as!string;
        u.hashedPassword = row[2].as!string;
        u.balance = cast(uint)row[3].as!long;
        break;
    }
    if (u.id == 0) return u;
    loadUserlots(u);
    return u;
}

private void loadUserlots(ref User u) {
    uint[] lotIds;
    foreach (row; database.execute(
        "SELECT lot_id FROM lot_participants WHERE user_id = ? ORDER BY lot_id",
        cast(long)u.id))
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
    database.execute(
        "INSERT INTO users (nickname, hashed_password, balance) VALUES (?, ?, ?)",
        nickname, hashedPassword, cast(long)balance);
    return cast(uint)database.lastInsertRowid;
}

void setUserBalance(uint userId, uint balance) {
    database.execute("UPDATE users SET balance = ? WHERE id = ?",
               cast(long)balance, cast(long)userId);
}

void addUserTolot(uint userId, uint lotId) {
    database.execute("INSERT OR IGNORE INTO lot_participants (user_id, lot_id) VALUES (?, ?)",
               cast(long)userId, cast(long)lotId);
}

void removeUserFromlot(uint userId, uint lotId) {
    database.execute("DELETE FROM lot_participants WHERE user_id = ? AND lot_id = ?",
               cast(long)userId, cast(long)lotId);
}

bool userInlot(uint userId, uint lotId) {
    foreach (row; database.execute(
        "SELECT 1 FROM lot_participants WHERE user_id = ? AND lot_id = ? LIMIT 1",
        cast(long)userId, cast(long)lotId))
        return true;
    return false;
}