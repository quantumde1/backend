module db.images;

import d2sqlite3;
import system.debugwriteln;
import variables;
import db.database;

uint addImage(ubyte[] data) {
    string mime = detectImageMime(data);
    database.execute("INSERT INTO images (data, mime) VALUES (?, ?)", data, mime);
    uint id = cast(uint)database.lastInsertRowid;
    debugWriteln("added image #", id, " (", data.length, " bytes, ", mime, ")");
    return id;
}

ubyte[] getImage(uint index) {
    if (index == NO_IMAGE) return [];
    foreach (row; database.execute("SELECT data FROM images WHERE id = ?", cast(long)index))
        return row[0].as!(ubyte[]);
    return [];
}

string getImageMime(uint index) {
    if (index == NO_IMAGE) return "application/octet-stream";
    foreach (row; database.execute("SELECT mime FROM images WHERE id = ?", cast(long)index))
        return row[0].as!string;
    return "application/octet-stream";
}

string detectImageMime(ubyte[] data) {
    if (data.length >= 8 &&
        data[0] == 0x89 && data[1] == 0x50 && data[2] == 0x4E && data[3] == 0x47)
        return "image/png";
    if (data.length >= 3 &&
        data[0] == 0xFF && data[1] == 0xD8 && data[2] == 0xFF)
        return "image/jpeg";
    if (data.length >= 6 &&
        data[0] == 0x47 && data[1] == 0x49 && data[2] == 0x46)
        return "image/gif";
    if (data.length >= 12 &&
        data[0] == 0x52 && data[1] == 0x49 && data[2] == 0x46 && data[3] == 0x46 &&
        data[8] == 0x57 && data[9] == 0x45 && data[10] == 0x42 && data[11] == 0x50)
        return "image/webp";
    return "application/octet-stream";
}