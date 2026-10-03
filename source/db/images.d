module db.images;

import system.debugwriteln;
import system.hpf;
import variables;
import std.file;
import std.path;

private string imagesArchivePath() {
    return pathToData ~ "data/db/images.hpf";
}

void loadAllImagesData() {
    debugWriteln("Loading images into RAM");
    images.length = 0;
    imageChunks.length = 0;

    string archivePath = imagesArchivePath();
    if (!exists(archivePath)) {
        debugWriteln("images.hpf not found, starting empty");
        return;
    }

    imageChunks = parseArchive(archivePath);
    foreach (i; 0 .. imageChunks.length) {
        ubyte[] data = loadFileFromHPF(archivePath, imageChunks, cast(int)i);
        images ~= data;
        debugWriteln("loaded image #", i, " (", data.length, " bytes)");
    }
}

void saveAllImagesData() {
    debugWriteln("Saving images to HPF (", images.length, " chunks)");
    string archivePath = imagesArchivePath();
    writeArchive(archivePath, images);
    // Перечитываем TOC, чтобы после сохранения offsets были актуальны.
    imageChunks = parseArchive(archivePath);
}

// Пишем HPF сразу при загрузке картинки, чтобы ставки, уже сохранённые
// в SQLite, никогда не ссылались на «потерянный» индекс после краха.
uint addImage(ubyte[] data) {
    uint newIndex = cast(uint)images.length;
    images ~= data;
    debugWriteln("added image #", newIndex, " (", data.length, " bytes)");
    saveAllImagesData();
    return newIndex;
}

ubyte[] getImage(uint index) {
    if (index == NO_IMAGE || index >= images.length) return [];
    return images[index];
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