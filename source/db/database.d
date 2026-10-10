module db.database;

import d2sqlite3;
import system.debugwriteln;
import std.file : mkdirRecurse;
import std.path;
import variables;

void initDatabase(string dataPath) {
    string dbPath = buildPath(dataPath, "db", "lottery.sqlite");
    mkdirRecurse(dirName(dbPath));
    debugWriteln("Opening SQLite database at ", dbPath);
    database = Database(dbPath);
    database.execute("PRAGMA foreign_keys = ON");
    database.execute("PRAGMA journal_mode = WAL");
    database.execute("PRAGMA busy_timeout = 5000");
    createTables();
}

void createTables() {
    database.execute("
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nickname TEXT NOT NULL UNIQUE,
            hashed_password TEXT NOT NULL,
            balance INTEGER NOT NULL DEFAULT 0
        )
    ");

    database.execute("
        CREATE TABLE IF NOT EXISTS lots (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            lot_name TEXT NOT NULL,
            price INTEGER NOT NULL,
            participant_one INTEGER NOT NULL,
            participant_two INTEGER,
            unix_timestamp INTEGER NOT NULL,
            status INTEGER NOT NULL DEFAULT 0,
            description TEXT NOT NULL DEFAULT '',
            FOREIGN KEY (participant_one) REFERENCES users(id),
            FOREIGN KEY (participant_two) REFERENCES users(id)
        )
    ");
    database.execute(
        "CREATE INDEX IF NOT EXISTS idx_lots_participant_one ON lots(participant_one)"
    );
    database.execute(
        "CREATE INDEX IF NOT EXISTS idx_lots_participant_two ON lots(participant_two)"
    );
    database.execute("
        CREATE TABLE IF NOT EXISTS images (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            lot_id INTEGER,
            position INTEGER NOT NULL DEFAULT 0,
            uploaded_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
            data BLOB NOT NULL,
            FOREIGN KEY (lot_id) REFERENCES lots(id) ON DELETE CASCADE
        )
    ");
    database.execute(
        "CREATE INDEX IF NOT EXISTS idx_images_lot ON images(lot_id, position)"
    );
}