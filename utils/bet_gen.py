#!/usr/bin/env python3
"""
Генератор тестового bets.hpf для маркетплейса (бывшие "котики").

Формат одной ставки/лота (один чанк, 185 байт):
  [0..32]    name, 32 байта ASCII (дополнено нулями)
  [32..35]   price, uint24 LE
  [35..39]   participantOne, uint32 LE (индекс пользователя)
  [39..43]   participantTwo, uint32 LE (индекс пользователя)
  [43..47]   unixTimestamp, uint32 LE
  [47]       state, 1 байт (0 = неактивна, 1 = активна)
  [48..176]  description, 128 байт ASCII (дополнено нулями)
  [176..179] imageIndexes[0], uint24 LE (0xFFFFFF = нет картинки)
  [179..182] imageIndexes[1], uint24 LE
  [182..185] imageIndexes[2], uint24 LE
"""

import struct
import sys
import time
import random

NO_IMAGE = 0xFFFFFF

def write_uint24_le(value: int) -> bytes:
    if not (0 <= value <= 0xFFFFFF):
        raise ValueError(f"uint24 out of range: {value}")
    return bytes([value & 0xFF, (value >> 8) & 0xFF, (value >> 16) & 0xFF])

def pack_ascii(s: str, length: int) -> bytes:
    raw = s.encode("ascii")
    if len(raw) > length:
        raise ValueError(f"string too long: {s} ({len(raw)} > {length})")
    return raw + b"\x00" * (length - len(raw))

def pack_utf8(s: str, length: int) -> bytes:
    """
    Упаковать строку в UTF-8 (D-строки — это UTF-8), дополнив нулями до length байт.
    Если строка в байтах длиннее length, обрезаем, не разрывая многобайтовый символ.
    """
    raw = s.encode("utf-8")
    if len(raw) > length:
        raw = raw[:length]
        while raw and (raw[-1] & 0xC0) == 0x80:  # обрезали середину multibyte-символа
            raw = raw[:-1]
    return raw + b"\x00" * (length - len(raw))

def pack_bet(name: str, price: int, p1: int, p2: int, ts: int, state: bool,
             description: str = "", image_indexes=None) -> bytes:
    if image_indexes is None:
        image_indexes = [NO_IMAGE, NO_IMAGE, NO_IMAGE]
    image_indexes = list(image_indexes) + [NO_IMAGE] * (3 - len(image_indexes))

    data = bytearray()
    data += pack_ascii(name, 32)             # 0..32
    data += write_uint24_le(price)           # 32..35
    data += struct.pack("<I", p1)            # 35..39
    data += struct.pack("<I", p2)            # 39..43
    data += struct.pack("<I", ts)            # 43..47
    data += bytes([1 if state else 0])       # 47
    data += pack_utf8(description, 128)      # 48..176
    for idx in image_indexes[:3]:            # 176..185
        data += write_uint24_le(idx)
    assert len(data) == 185, f"bet size = {len(data)}, expected 185"
    return bytes(data)

def build_hpf(chunks: list[bytes]) -> bytes:
    """
    HPF:
      [0..4]                  длина оглавления (uint32 LE)
      [4..4+toc_len]          оглавление: пары (offset uint32 LE, length uint32 LE)
                              + маркер 0xFFFFFFFF в конце
      [после оглавления]      данные чанков
    """
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

def main():
    # Тестовые лоты: (name, price, p1, p2, state, description, image_indexes)
    # p1, p2 — индексы пользователей (0 = Kotik, 1 = Barsik, ...)
    # image_indexes — индексы картинок в data/db/images.hpf (см. image_gen.py), NO_IMAGE если без фото
    test_bets = [
        ("maska",       100,  0, 1, True,  "Карнавальная маска, ручная роспись",       [0]),
        ("shlyapa",     50,   1, 2, True,  "Фетровая шляпа, размер 58",                [1, 2]),
        ("kofta",       250,  2, 0, True,  "Вязаная кофта, шерсть",                    []),
        ("kurtka",      10,   3, 4, True,  "Куртка осенняя, б/у",                      [3]),
        ("test",        1000, 4, 0, True,  "Тестовый лот без описания и фото",         []),
        ("perchatka",   500,  0, 5, True,  "Кожаные перчатки, пара",                   [4, 5, 6]),
        ("telefon",     75,   5, 1, True,  "Старый кнопочный телефон, рабочий",        [7]),
        ("noutbuk",     33,   0, 2, True,  "Ноутбук на запчасти",                      []),
        ("planshet",    666,  1, 3, True,  "Планшет, экран треснут",                   [8]),
        ("meow",        42,   2, 4, True,  "Просто мяу",                               []),
        ("test2",       999,  5, 0, True,  "",                                         []),
        ("Empty state", 1,    3, 5, True,  "Лот с длинным-длинным описанием " * 3,     []),
    ]
    
    now = int(time.time())
    chunks = []
    for i, (name, price, p1, p2, state, description, images) in enumerate(test_bets):
        ts = now - random.randint(0, 86400 * 7)  # в пределах недели
        # description может быть длиннее 128 символов в тестовых данных выше — обрежем
        chunks.append(pack_bet(name, price, p1, p2, ts, state, description[:128], images))
    
    hpf = build_hpf(chunks)
    
    out_path = sys.argv[1] if len(sys.argv) > 1 else "bets.hpf"
    with open(out_path, "wb") as f:
        f.write(hpf)
    
    print(f"written {len(hpf)} bytes to {out_path}")
    print(f"bets: {len(test_bets)}")
    for i, (name, price, p1, p2, state, description, images) in enumerate(test_bets):
        print(f"  [{i:2d}] {name:32s} price={price:5d} p1={p1} p2={p2} state={state} images={images} desc={description[:30]!r}")

if __name__ == "__main__":
    main()
