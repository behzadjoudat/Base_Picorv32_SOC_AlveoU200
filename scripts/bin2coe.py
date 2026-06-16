#!/usr/bin/env python3
"""
Convert a raw binary to a Xilinx .coe file for Block Memory Generator.
The BRAM is 128 KB = 32768 × 32-bit words.
Bytes beyond the binary are initialised to 0.
"""
import sys, struct

BRAM_WORDS = 32768  # 128 KB / 4

def bin2coe(src, dst):
    data = bytearray(open(src, 'rb').read())
    # Pad to full BRAM size
    data += b'\x00' * (BRAM_WORDS * 4 - len(data))
    if len(data) > BRAM_WORDS * 4:
        print(f'WARNING: binary ({len(data)} B) exceeds BRAM size ({BRAM_WORDS*4} B).',
              file=sys.stderr)
        data = data[:BRAM_WORDS * 4]

    with open(dst, 'w') as f:
        f.write('memory_initialization_radix=16;\n')
        f.write('memory_initialization_vector=\n')
        words = []
        for i in range(0, len(data), 4):
            word, = struct.unpack_from('<I', data, i)
            words.append(f'{word:08x}')
        f.write(',\n'.join(words))
        f.write(';\n')

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print(f'Usage: {sys.argv[0]} <in.bin> <out.coe>')
        sys.exit(1)
    bin2coe(sys.argv[1], sys.argv[2])
