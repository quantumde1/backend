#!/usr/bin/env python3
"""
Генератор тестового bets.hpf для котиков.

Формат одной ставки (один чанк, 48 байт):
  [0..32]   name, 32 байта ASCII (дополнено нулями)
  [32..35]  price, uint24 LE
  [35..39]  participantOne, uint32 LE (индекс пользователя)
  [39..43]  participantTwo, uint32 LE (индекс пользователя)
  [43..47]  unixTimestamp, uint32 LE
  [47]      state, 1 байт (0 = неактивна, 1 = активна)
"""

import struct
import sys
import time
import random

def write_uint24_le(value: int) -> bytes:
    if not (0 <= value <= 0xFFFFFF):
        raise ValueError(f"uint24 out of range: {value}")
    return bytes([value & 0xFF, (value >> 8) & 0xFF, (value >> 16) & 0xFF])

def pack_name(name: str, length: int = 32) -> bytes:
    raw = name.encode("ascii")
    if len(raw) > length:
        raise ValueError(f"bet name too long: {name} ({len(raw)} > {length})")
    return raw + b"\x00" * (length - len(raw))

def pack_bet(name: str, price: int, p1: int, p2: int, ts: int, state: bool) -> bytes:
    data = bytearray()
    data += pack_name(name, 32)             # 0..32
    data += write_uint24_le(price)          # 32..35
    data += struct.pack("<I", p1)           # 35..39
    data += struct.pack("<I", p2)           # 39..43
    data += struct.pack("<I", ts)           # 43..47
    data += bytes([1 if state else 0])      # 47
    assert len(data) == 48, f"bet size = {len(data)}, expected 48"
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
    # Тестовые ставки: (name, price, p1, p2, state)
    # p1, p2 — индексы пользователей (0 = Kotik, 1 = Barsik, ...)
    test_bets = [
        ("maska",        100,  0, 1, True),
        ("shlyapa",           50,  1, 2, True),
        ("kofta",       250,  2, 0, True),
        ("kurtka",         10,  3, 4, True),
        ("test",        1000,  4, 0, True),
        ("perchatka",         500,  0, 5, True),
        ("telefon",          75,  5, 1, True),
        ("noutbuk", 33,  0, 2, True),
        ("planshet",       666,  1, 3, True),
        ("meow",        42,  2, 4, True),
        ("test2", 999, 5, 0, True),
        ("Empty state", 1, 3, 5, True),
    ]
    
    now = int(time.time())
    chunks = []
    for i, (name, price, p1, p2, state) in enumerate(test_bets):
        ts = now - random.randint(0, 86400 * 7)  # в пределах недели
        chunks.append(pack_bet(name, price, p1, p2, ts, state))
    
    hpf = build_hpf(chunks)
    
    out_path = sys.argv[1] if len(sys.argv) > 1 else "bets.hpf"
    with open(out_path, "wb") as f:
        f.write(hpf)
    
    print(f"written {len(hpf)} bytes to {out_path}")
    print(f"bets: {len(test_bets)}")
    for i, (name, price, p1, p2, state) in enumerate(test_bets):
        print(f"  [{i:2d}] {name:32s} price={price:5d} p1={p1} p2={p2} state={state}")

if __name__ == "__main__":
    main()