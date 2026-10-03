module db.database;

import d2sqlite3;
import system.debugwriteln;
import std.path;

Database database;

void initDatabase(string dataPath) {
    string dbPath = buildPath(dataPath, "data", "db", "lottery.sqlite");
    debugWriteln("Opening SQLite database at ", dbPath);
    database = Database(dbPath);
    database.execute("PRAGMA foreign_keys = ON");
    database.execute("PRAGMA journal_mode = WAL");
    createTables();
}

private void createTables() {
    database.execute("
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nickname TEXT NOT NULL UNIQUE,
            hashed_password TEXT NOT NULL,
            balance INTEGER NOT NULL DEFAULT 0
        )
    ");

    database.execute("
        CREATE TABLE IF NOT EXISTS bets (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            bet_name TEXT NOT NULL,
            price INTEGER NOT NULL,
            participant_one INTEGER NOT NULL,
            participant_two INTEGER,
            unix_timestamp INTEGER NOT NULL,
            status INTEGER NOT NULL DEFAULT 0,
            description TEXT NOT NULL DEFAULT '',
            image_slot_0 INTEGER NOT NULL DEFAULT 16777215,
            image_slot_1 INTEGER NOT NULL DEFAULT 16777215,
            image_slot_2 INTEGER NOT NULL DEFAULT 16777215,
            FOREIGN KEY (participant_one) REFERENCES users(id),
            FOREIGN KEY (participant_two) REFERENCES users(id)
        )
    ");

    database.execute("
        CREATE TABLE IF NOT EXISTS bet_participants (
            user_id INTEGER NOT NULL,
            bet_id INTEGER NOT NULL,
            PRIMARY KEY (user_id, bet_id),
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
            FOREIGN KEY (bet_id) REFERENCES bets(id) ON DELETE CASCADE
        )
    ");
}