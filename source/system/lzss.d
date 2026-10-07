module system.lzss;

import core.stdc.string;

enum N = 4096;
enum F = 18;
enum THRESHOLD = 2;

int decompressLZSS(ubyte[] dst, ubyte[] src) 
{
    ubyte[N + F - 1] text_buf;
    ubyte* dst_ptr = dst.ptr;
    ubyte* src_ptr = src.ptr;
    ubyte* src_end = src_ptr + src.length;
    
    int r = N - F;
    ubyte c;
    uint flags = 0;
    int i, j, k;
    
    memset(text_buf.ptr, 0, r);
    
    while (true) {
        if (((flags >>= 1) & 0x100) == 0) {
            if (src_ptr < src_end) {
                c = *src_ptr++;
            } else {
                break;
            }
            flags = c | 0xFF00;
        }
        
        if (flags & 1) {
            if (src_ptr < src_end) {
                c = *src_ptr++;
            } else {
                break;
            }
            *dst_ptr++ = c;
            text_buf[r++] = c;
            r &= (N - 1);
        } else {
            if (src_ptr < src_end) {
                i = *src_ptr++;
            } else {
                break;
            }
            if (src_ptr < src_end) {
                j = *src_ptr++;
            } else {
                break;
            }
            
            i |= ((j & 0xF0) << 4);
            j = (j & 0x0F) + THRESHOLD;
            
            for (k = 0; k <= j; k++) {
                c = text_buf[(i + k) & (N - 1)];
                *dst_ptr++ = c;
                text_buf[r++] = c;
                r &= (N - 1);
            }
        }
    }
    
    return cast(int)(dst_ptr - dst.ptr);
}

ubyte[] decompressLzss(ubyte[] src, int expectedSize = -1) 
{
    if (expectedSize <= 0) {
        expectedSize = cast(int)src.length * 2;
    }
    
    ubyte[] result = new ubyte[expectedSize];
    int actualSize = decompressLZSS(result, src);
    
    if (actualSize < expectedSize) {
        result.length = actualSize;
    }
    
    return result;
}

enum MIN_MATCH = THRESHOLD + 1;
enum HASH_BITS = 13;
enum HASH_SIZE = 1 << HASH_BITS;
enum MAX_CHAIN = 128;

private uint hash3(const(ubyte)* p)
{
    return ((cast(uint)p[0] << 10) ^ (cast(uint)p[1] << 5) ^ p[2]) & (HASH_SIZE - 1);
}

int compressLZSS(ubyte[] dst, const(ubyte)[] src)
{
    immutable size_t n = src.length;
    if (n == 0) return 0;

    auto head = new int[HASH_SIZE];
    head[] = -1;
    auto prev = new int[n];

    size_t sp = 0;
    size_t dp = 0;
    size_t flagPos = 0;
    int flagBit = 8;

    void insertPos(size_t pos)
    {
        if (pos + MIN_MATCH <= n)
        {
            uint h = hash3(&src[pos]);
            prev[pos] = head[h];
            head[h] = cast(int)pos;
        }
    }

    while (sp < n)
    {
        size_t maxLen = n - sp;
        if (maxLen > F) maxLen = F;

        size_t bestLen = 0;
        size_t bestDist = 0;

        if (maxLen >= MIN_MATCH)
        {
            int cand = head[hash3(&src[sp])];
            int chain = MAX_CHAIN;

            while (cand >= 0 && chain-- > 0)
            {
                size_t dist = sp - cast(size_t)cand;
                if (dist > N - 1) break;

                size_t len = 0;
                while (len < maxLen && src[cand + len] == src[sp + len]) len++;

                if (len > bestLen)
                {
                    bestLen = len;
                    bestDist = dist;
                    if (len == maxLen) break;
                }
                cand = prev[cand];
            }
        }

        bool isMatch = bestLen >= MIN_MATCH;

        if (flagBit == 8)
        {
            if (dp >= dst.length) return -1;
            flagPos = dp++;
            dst[flagPos] = 0;
            flagBit = 0;
        }

        if (isMatch)
        {
            if (dp + 2 > dst.length) return -1;

            uint ringPos = cast(uint)((N - F + (sp - bestDist)) & (N - 1));

            dst[dp++] = cast(ubyte)(ringPos & 0xFF);
            dst[dp++] = cast(ubyte)(((ringPos >> 8) & 0x0F) << 4 | (bestLen - MIN_MATCH));

            foreach (k; 0 .. bestLen) insertPos(sp + k);
            sp += bestLen;
        }
        else
        {
            if (dp >= dst.length) return -1;

            dst[dp++] = src[sp];
            dst[flagPos] |= cast(ubyte)(1 << flagBit);

            insertPos(sp);
            sp++;
        }

        flagBit++;
    }

    return cast(int)dp;
}

ubyte[] compressLzss(const(ubyte)[] src)
{
    size_t maxSize = src.length + (src.length + 7) / 8 + 1;
    auto result = new ubyte[maxSize];

    int actual = compressLZSS(result, src);
    assert(actual >= 0);

    result.length = actual;
    return result;
}