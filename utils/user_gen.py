#!/usr/bin/env python3
"""
Генератор тестового users.hpf для котиков.

Формат одного пользователя (один чанк):
  [0..16]   ник, 16 байт ASCII (дополнен нулями)
  [16..48]  хэш пароля, 32 байта ASCII (дополнен нулями)
  [48..52]  баланс, uint32 LE
  [52..55]  betsDone, uint24 LE
  [55..]    индексы ставок, по 3 байта uint24 LE каждый
"""

import struct
import sys

def write_uint24_le(value: int) -> bytes:
    """Записать uint24 в little-endian (3 байта)."""
    if not (0 <= value <= 0xFFFFFF):
        raise ValueError(f"uint24 out of range: {value}")
    return bytes([value & 0xFF, (value >> 8) & 0xFF, (value >> 16) & 0xFF])

def pack_fixed_string(s: str, length: int) -> bytes:
    """Строка в ASCII, дополненная нулями до length байт."""
    raw = s.encode("ascii")
    if len(raw) > length:
        raise ValueError(f"string too long: {s} ({len(raw)} > {length})")
    return raw + b"\x00" * (length - len(raw))

def pack_user(nick: str, password: str, balance: int, bets_indexes: list[int]) -> bytes:
    """Упаковать одного пользователя в чанк."""
    data = bytearray()
    data += pack_fixed_string(nick, 16)          # 0..16
    data += pack_fixed_string(password, 32)      # 16..48
    data += struct.pack("<I", balance)           # 48..52
    data += write_uint24_le(len(bets_indexes))   # 52..55
    for idx in bets_indexes:
        data += write_uint24_le(idx)
    return bytes(data)

def build_hpf(chunks: list[bytes]) -> bytes:
    """
    Собрать HPF-файл.
    
    Формат:
      [0..4]                    длина оглавления в байтах (uint32 LE)
      [4..4+len(оглавления)]    оглавление: пары (offset uint32 LE, length uint32 LE)
      [после оглавления]        данные чанков
      маркер конца оглавления: 0xFFFFFFFF
    """
    toc_size = len(chunks) * 8 + 4
    header_size = 4
    data_start = header_size + toc_size
    
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
    # Тестовые пользователи: (ник, пароль, баланс, [индексы ставок])
    # Пароли — тестовые, хэши — просто заглушки (ASCII)
    test_users = [
        ("Kotik",          "kotik123",           1000, [0, 2, 4, 5, 7, 10]),
        ("Barsik",         "barsik_secret",       500, [0, 1, 6, 8]),
        ("Murzik",         "murz1k_pwd",         2500, [1, 2, 7, 9]),
        ("Pushok",         "pushok",                0, [3, 8, 11]),
        ("Vasya",          "vasya_228",        999999, [3, 4, 9]),
        ("VeryLongNick16", "very_long_password",   42, [5, 6, 10, 11]),
    ]
    
    chunks = [
        pack_user(nick, pwd, bal, bets)
        for nick, pwd, bal, bets in test_users
    ]
    hpf = build_hpf(chunks)
    
    out_path = sys.argv[1] if len(sys.argv) > 1 else "users.hpf"
    with open(out_path, "wb") as f:
        f.write(hpf)
    
    print(f"written {len(hpf)} bytes to {out_path}")
    print(f"users: {len(test_users)}")
    for nick, pwd, bal, bets in test_users:
        print(f"  {nick:16s} balance={bal:6d} bets={len(bets)} -> {bets}")

if __name__ == "__main__":
    main()