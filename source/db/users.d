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
    loadUserBets(u);
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
    loadUserBets(u);
    return u;
}

private void loadUserBets(ref User u) {
    uint[] betIds;
    foreach (row; database.execute(
        "SELECT bet_id FROM bet_participants WHERE user_id = ? ORDER BY bet_id",
        cast(long)u.id))
    {
        betIds ~= cast(uint)row[0].as!long;
    }
    u.betsIndexes = betIds;
    u.betsDone = cast(uint)betIds.length;
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

void addUserToBet(uint userId, uint betId) {
    database.execute("INSERT OR IGNORE INTO bet_participants (user_id, bet_id) VALUES (?, ?)",
               cast(long)userId, cast(long)betId);
}

void removeUserFromBet(uint userId, uint betId) {
    database.execute("DELETE FROM bet_participants WHERE user_id = ? AND bet_id = ?",
               cast(long)userId, cast(long)betId);
}

bool userInBet(uint userId, uint betId) {
    foreach (row; database.execute(
        "SELECT 1 FROM bet_participants WHERE user_id = ? AND bet_id = ? LIMIT 1",
        cast(long)userId, cast(long)betId))
        return true;
    return false;
}