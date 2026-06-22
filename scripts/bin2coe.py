#!/usr/bin/env python3
"""
Convert a raw binary to a Xilinx .coe file for Block Memory Generator.
The BRAM is 128 KB = 16384 × 64-bit words (BOOM uses 64-bit wide BRAM).
Bytes beyond the binary are initialised to 0.
"""
import sys, struct

BRAM_WORDS = 16384  # 128 KB / 8

def bin2coe(src, dst):
    data = bytearray(open(src, 'rb').read())
    # Pad to full BRAM size
    target_size = BRAM_WORDS * 8
    data += b'\x00' * (target_size - len(data))
    if len(data) > target_size:
        print(f'WARNING: binary ({len(data)} B) exceeds BRAM size ({target_size} B).',
              file=sys.stderr)
        data = data[:target_size]

    with open(dst, 'w') as f:
        f.write('memory_initialization_radix=16;\n')
        f.write('memory_initialization_vector=\n')
        words = []
        for i in range(0, len(data), 8):
            word, = struct.unpack_from('<Q', data, i)   # 64-bit little-endian
            words.append(f'{word:016x}')
        f.write(',\n'.join(words))
        f.write(';\n')

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print(f'Usage: {sys.argv[0]} <in.bin> <out.coe>')
        sys.exit(1)
    bin2coe(sys.argv[1], sys.argv[2])
