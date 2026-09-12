module system.sc3_r11.lzss;

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