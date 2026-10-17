"""Connect to a VNC server with classic VNC password auth and save one full frame.

Usage: python vnc_selfcheck.py HOST PORT PASSWORD OUT.png

Uses security type 2 (VNC password), the same one Windows viewers such as
TigerVNC and TightVNC use, and fails if the frame is blank.
"""
import socket
import struct
import sys

from Crypto.Cipher import DES
from PIL import Image


def recv_exact(sock, n):
    buf = bytearray()
    while len(buf) < n:
        chunk = sock.recv(n - len(buf))
        if not chunk:
            raise SystemExit("VNC server closed the connection")
        buf += chunk
    return bytes(buf)


def vnc_key(password):
    key = password.encode()[:8].ljust(8, b"\0")
    # VNC reverses the bit order of each key byte.
    return bytes(int(f"{b:08b}"[::-1], 2) for b in key)


def main(host, port, password, out):
    sock = socket.create_connection((host, int(port)), timeout=60)
    version = recv_exact(sock, 12)
    print("server version:", version.decode().strip())
    sock.sendall(b"RFB 003.008\n")

    count = recv_exact(sock, 1)[0]
    types = list(recv_exact(sock, count))
    print("security types offered:", types)
    if 2 not in types:
        raise SystemExit("VNC password auth (type 2) is not offered")
    sock.sendall(b"\x02")
    challenge = recv_exact(sock, 16)
    sock.sendall(DES.new(vnc_key(password), DES.MODE_ECB).encrypt(challenge))
    (result,) = struct.unpack(">I", recv_exact(sock, 4))
    if result != 0:
        raise SystemExit("VNC password was rejected")
    print("VNC password accepted")

    sock.sendall(b"\x01")  # shared session
    width, height = struct.unpack(">HH", recv_exact(sock, 4))
    recv_exact(sock, 16)
    (name_len,) = struct.unpack(">I", recv_exact(sock, 4))
    name = recv_exact(sock, name_len).decode(errors="replace")
    print(f"desktop '{name}': {width}x{height}")

    # 32-bit little-endian true colour, red at bit 16, green at 8, blue at 0.
    pixel_format = struct.pack(">BBBBHHHBBB3x", 32, 24, 0, 1, 255, 255, 255, 16, 8, 0)
    sock.sendall(b"\x00\x00\x00\x00" + pixel_format)
    sock.sendall(struct.pack(">BxHi", 2, 1, 0))  # Raw encoding only
    sock.sendall(struct.pack(">BBHHHH", 3, 0, 0, 0, width, height))

    frame = Image.new("RGB", (width, height))
    covered = 0
    while covered < width * height:
        msg_type = recv_exact(sock, 1)[0]
        if msg_type == 0:
            (rects,) = struct.unpack(">xH", recv_exact(sock, 3))
            for _ in range(rects):
                x, y, w, h, enc = struct.unpack(">HHHHi", recv_exact(sock, 12))
                if enc != 0:
                    raise SystemExit(f"unexpected encoding {enc}")
                data = recv_exact(sock, w * h * 4)
                frame.paste(Image.frombytes("RGB", (w, h), data, "raw", "BGRX"), (x, y))
                covered += w * h
        elif msg_type == 2:
            pass  # bell
        elif msg_type == 3:
            (length,) = struct.unpack(">3xI", recv_exact(sock, 7))
            recv_exact(sock, length)
        else:
            raise SystemExit(f"unexpected server message {msg_type}")
    sock.close()

    frame.save(out)
    lo, hi = frame.convert("L").getextrema()
    print(f"saved {out}, brightness range {lo}..{hi}")
    if hi - lo < 10:
        raise SystemExit("VNC frame is blank: macOS blocks screen recording for Screen Sharing")
    print("VNC shows the desktop")


if __name__ == "__main__":
    main(*sys.argv[1:])
