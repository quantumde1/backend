module db.images;

import d2sqlite3;
import system.debugwriteln;
import variables;
import system.lzss;
import db.database;

enum ORPHAN_IMAGE_TTL = 24 * 60 * 60;

uint addImage(ubyte[] data) {
    deleteOrphanImages();
    database.execute("INSERT INTO images (data) VALUES (?)", compressLzss(data));
    uint newIndex = cast(uint)database.lastInsertRowid;
    debugWriteln("added image #", newIndex, " (", data.length, " bytes)");
    return newIndex;
}

ubyte[] getImage(uint index) {
    if (index == NO_IMAGE) return [];
    ubyte[] result;
    foreach (row; database.execute("SELECT data FROM images WHERE id = ?", cast(long)index)) {
        result = decompressLzss(cast(ubyte[])row[0].as!(ubyte[]));
        break;
    }
    return result;
}

void deleteOrphanImages(long maxAgeSeconds = ORPHAN_IMAGE_TTL) {
    database.execute(
        "DELETE FROM images WHERE lot_id IS NULL "
        ~ "AND uploaded_at < strftime('%s', 'now') - ?",
        maxAgeSeconds);
}

string detectImageMime(ubyte[] data) {
    if (data.length >= 8 &&
        data[0] == 0x89 && data[1] == 0x50 && data[2] == 0x4E && data[3] == 0x47 &&
        data[4] == 0x0D && data[5] == 0x0A && data[6] == 0x1A && data[7] == 0x0A)
        return "image/png";
    if (data.length >= 3 &&
        data[0] == 0xFF && data[1] == 0xD8 && data[2] == 0xFF)
        return "image/jpeg";
    if (data.length >= 6 &&
        data[0] == 0x47 && data[1] == 0x49 && data[2] == 0x46 && data[3] == 0x38 &&
        (data[4] == 0x37 || data[4] == 0x39) && data[5] == 0x61)
        return "image/gif";
    if (data.length >= 12 &&
        data[0] == 0x52 && data[1] == 0x49 && data[2] == 0x46 && data[3] == 0x46 &&
        data[8] == 0x57 && data[9] == 0x45 && data[10] == 0x42 && data[11] == 0x50)
        return "image/webp";
    return "application/octet-stream";
}

uint[] getLotImages(uint lotId) {
    uint[] result;
    foreach (row; database.execute(
        "SELECT id FROM images WHERE lot_id = ? ORDER BY position, id",
        cast(long)lotId))
    {
        result ~= cast(uint)row[0].as!long;
    }
    return result;
}

void setLotImages(uint lotId, uint[] imageIndexes) {
    foreach (oldId; getLotImages(lotId)) {
        bool keep = false;
        foreach (id; imageIndexes) {
            if (id == oldId) { keep = true; break; }
        }
        if (!keep)
            database.execute("DELETE FROM images WHERE id = ? AND lot_id = ?",
                                cast(long)oldId, cast(long)lotId);
    }
    foreach (i, imgId; imageIndexes) {
        database.execute(
            "UPDATE images SET lot_id = ?, position = ? "
            ~ "WHERE id = ? AND (lot_id IS NULL OR lot_id = ?)",
            cast(long)lotId, cast(long)i, cast(long)imgId, cast(long)lotId);
    }
}

void addLotImage(uint lotId, uint imageId) {
    long nextPos = 0;
    foreach (row; database.execute(
        "SELECT COALESCE(MAX(position), -1) + 1 FROM images WHERE lot_id = ?",
        cast(long)lotId))
    {
        nextPos = row[0].as!long;
    }
    database.execute(
        "UPDATE images SET lot_id = ?, position = ? WHERE id = ? AND lot_id IS NULL",
        cast(long)lotId, nextPos, cast(long)imageId);
}

void removeLotImage(uint lotId, uint imageId) {
    database.execute(
        "DELETE FROM images WHERE id = ? AND lot_id = ?",
        cast(long)imageId, cast(long)lotId);
}