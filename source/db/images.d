module db.images;

import system.debugwriteln;
import system.hpf;
import variables;

enum uint NO_IMAGE = 0xFFFFFF;

void loadAllImagesData() {
    debugWriteln("Loading images into RAM");
    if (parsedChunks.length == 0) {
        parsedChunks.length = 3;
    }
    parsedChunks[2] = parseArchive(pathToData~"data/db/images.hpf");
    images.length = 0;

    for (int i = 0; i < parsedChunks[2].length; i++) {
        ubyte[] data = loadFileFromHPF("data/db/images.hpf", parsedChunks[2], cast(int)i);
        images ~= data;
        debugWriteln("loaded image #", i, " (", data.length, " bytes)");
    }
}

uint addImage(ubyte[] data) {
    uint newIndex = cast(uint)images.length;
    images ~= data;
    debugWriteln("added image #", newIndex, " (", data.length, " bytes)");
    return newIndex;
}

ubyte[] getImage(uint index) {
    if (index >= images.length) {
        return [];
    }
    return images[index];
}

string detectImageMime(ubyte[] data) {
    if (data.length >= 8
        && data[0] == 0x89 && data[1] == 0x50 && data[2] == 0x4E && data[3] == 0x47) {
        return "image/png";
    }
    if (data.length >= 3
        && data[0] == 0xFF && data[1] == 0xD8 && data[2] == 0xFF) {
        return "image/jpeg";
    }
    if (data.length >= 6
        && data[0] == 0x47 && data[1] == 0x49 && data[2] == 0x46) {
        return "image/gif";
    }
    if (data.length >= 12
        && data[0] == 0x52 && data[1] == 0x49 && data[2] == 0x46 && data[3] == 0x46
        && data[8] == 0x57 && data[9] == 0x45 && data[10] == 0x42 && data[11] == 0x50) {
        return "image/webp";
    }
    return "application/octet-stream";
}
