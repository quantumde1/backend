#!/usr/bin/env python3
"""
Генератор тестового images.hpf.

Картинки хранятся в архиве как есть — сырые байты файла (тут: маленькие
однотонные PNG 64x64), без какого-либо дополнительного заголовка.
Индекс картинки = номер чанка в архиве, именно на него ссылаются
imageIndexes в bets.hpf (см. bet_gen.py).

Требует Pillow: pip install Pillow --break-system-packages
"""

import io
import struct
import sys

from PIL import Image

def build_hpf(chunks: list[bytes]) -> bytes:
    toc_size = len(chunks) * 8 + 4
    data_start = 4 + toc_size

    toc = bytearray()
    data = bytearray()
    current_offset = data_start

    for chunk in chunks:
        toc += struct.pack("<I", current_offset)
        toc += struct.pack("<I", len(chunk))
        data += chunk
        current_offset += len(chunk)

    toc += struct.pack("<I", 0xFFFFFFFF)

    out = bytearray()
    out += struct.pack("<I", len(toc))
    out += toc
    out += data
    return bytes(out)

def make_png(color: tuple[int, int, int]) -> bytes:
    img = Image.new("RGB", (64, 64), color)
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()

def main():
    # индексы этих картинок должны соответствовать image_indexes в bet_gen.py
    colors = [
        (231, 76, 60),    # 0 - red
        (46, 204, 113),   # 1 - green
        (52, 152, 219),   # 2 - blue
        (241, 196, 15),   # 3 - yellow
        (155, 89, 182),   # 4 - purple
        (26, 188, 156),   # 5 - teal
        (230, 126, 34),   # 6 - orange
        (149, 165, 166),  # 7 - gray
        (44, 62, 80),     # 8 - dark
    ]

    chunks = [make_png(c) for c in colors]
    hpf = build_hpf(chunks)

    out_path = sys.argv[1] if len(sys.argv) > 1 else "images.hpf"
    with open(out_path, "wb") as f:
        f.write(hpf)

    print(f"written {len(hpf)} bytes to {out_path}")
    print(f"images: {len(chunks)}")
    for i, c in enumerate(colors):
        print(f"  [{i}] color={c}")

if __name__ == "__main__":
    main()
