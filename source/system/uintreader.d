module system.uintreader;

ushort readUInt16(ref ubyte[] bytes, size_t offset) {
    size_t internalCurrentPosition = offset;
    ubyte b0 = bytes[internalCurrentPosition];
    ubyte b1 = bytes[internalCurrentPosition + 1];
    ushort result = b0 | (b1 << 8);
    return result;
}

uint readUInt24(ref ubyte[] bytes, size_t offset) {
    size_t internalCurrentPosition = offset;
    uint b0 = bytes[internalCurrentPosition];
    uint b1 = bytes[internalCurrentPosition + 1];
    uint b2 = bytes[internalCurrentPosition + 2];
    uint result = b0 | (b1 << 8) | (b2 << 16);
    return result;
}

uint readUInt32(ref ubyte[] bytes, size_t offset) {
    size_t internalCurrentPosition = offset;
    uint b0 = bytes[internalCurrentPosition];
    uint b1 = bytes[internalCurrentPosition + 1];
    uint b2 = bytes[internalCurrentPosition + 2];
    uint b3 = bytes[internalCurrentPosition + 3];
    uint result = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24);
    return result;
}

float readFloat16(ref ubyte[] bytes, size_t offset) {
    size_t internalCurrentPosition = offset;
    ubyte b0 = bytes[internalCurrentPosition];
    ubyte b1 = bytes[internalCurrentPosition + 1];
    return b0 + b1 / 100.0f;
}