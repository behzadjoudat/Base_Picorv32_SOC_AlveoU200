#!/usr/bin/env python3
"""Convert a raw binary to a 32-bit word hex file suitable for $readmemh."""
import sys, struct

def bin2hex(src, dst):
    data = open(src, 'rb').read()
    # Pad to 4-byte boundary
    while len(data) % 4:
        data += b'\x00'
    with open(dst, 'w') as f:
        for i in range(0, len(data), 4):
            word, = struct.unpack_from('<I', data, i)  # little-endian
            f.write(f'{word:08x}\n')

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print(f'Usage: {sys.argv[0]} <in.bin> <out.hex>')
        sys.exit(1)
    bin2hex(sys.argv[1], sys.argv[2])
