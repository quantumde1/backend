module system.hpf;

import system.debugwriteln;
import system.uintreader;
import std.string;
import std.conv;
import std.stdio;
import variables;
import std.file;
import std.path;

ParsedChunk[] parseArchive(string filename) {
    ParsedChunk[] parsedChunks;
    auto archive = File(filename, "rb");
    ubyte[] offsetsChunkLengthUbyte = new ubyte[4];
    archive.rawRead(offsetsChunkLengthUbyte);
    debugWriteln(offsetsChunkLengthUbyte); // debug
    int offsetsChunkLength = readUInt32(offsetsChunkLengthUbyte, 0);
    debugWriteln("int repres: ", offsetsChunkLength);
    ubyte[] chunks = new ubyte[offsetsChunkLength];
    archive.rawRead(chunks);
    int currentOffset = 0;
    while (readUInt32(chunks, currentOffset) != 0xFFFFFFFF) {
        parsedChunks ~= ParsedChunk(
            cast(int)readUInt32(chunks, currentOffset),
            cast(int)readUInt32(chunks, currentOffset+4)
        );
        currentOffset+=8;
    }
    return parsedChunks;
}

void writeArchive(string filename, ubyte[][] chunks) {
    size_t tocSize = chunks.length * 8 + 4;
    size_t headerSize = 4;
    size_t dataStart = headerSize + tocSize;

    ParsedChunk[] offsets;
    offsets.reserve(chunks.length);

    ubyte[] data;
    size_t currentOffset = dataStart;
    foreach (ref chunk; chunks) {
        offsets ~= ParsedChunk(cast(int)currentOffset, cast(int)chunk.length);
        data ~= chunk;
        currentOffset += chunk.length;
    }

    ubyte[] offsetsTable;
    offsetsTable.reserve(tocSize);

    foreach (ref c; offsets) {
        ubyte[4] offBuf = [
            cast(ubyte)(c.offset & 0xFF),
            cast(ubyte)((c.offset >> 8) & 0xFF),
            cast(ubyte)((c.offset >> 16) & 0xFF),
            cast(ubyte)((c.offset >> 24) & 0xFF)
        ];
        offsetsTable ~= offBuf;

        ubyte[4] lenBuf = [
            cast(ubyte)(c.length & 0xFF),
            cast(ubyte)((c.length >> 8) & 0xFF),
            cast(ubyte)((c.length >> 16) & 0xFF),
            cast(ubyte)((c.length >> 24) & 0xFF)
        ];
        offsetsTable ~= lenBuf;
    }

    offsetsTable ~= [0xFF, 0xFF, 0xFF, 0xFF];

    ubyte[] finalFile;
    finalFile.reserve(4 + offsetsTable.length + data.length);

    uint offsetsLen = cast(uint)offsetsTable.length;
    finalFile ~= [
        cast(ubyte)(offsetsLen & 0xFF),
        cast(ubyte)((offsetsLen >> 8) & 0xFF),
        cast(ubyte)((offsetsLen >> 16) & 0xFF),
        cast(ubyte)((offsetsLen >> 24) & 0xFF)
    ];
    finalFile ~= offsetsTable;
    finalFile ~= data;

    string tmpName = "/tmp/"~baseName(filename)~".tmp";
    auto f = File(tmpName, "wb");
    f.rawWrite(finalFile);
    f.close();
    std.file.copy(tmpName, filename);
    std.file.remove(tmpName);
    debugWriteln("writeArchive: ", filename, " — ", chunks.length, " chunks, ",
                 finalFile.length, " byte");
}

ubyte[] loadFileFromHPF(string filename, ParsedChunk[] parsedChunks, int fileIndex) {
    auto archive = File(filename, "rb");
    archive.seek(parsedChunks[fileIndex].offset);
    ubyte[] file = new ubyte[parsedChunks[fileIndex].length];
    archive.rawRead(file);
    return file;
}