#!/usr/bin/env python3
"""Extract a device's AFE module calibration from a Qualcomm ACDB file.

On Android, the ACDB loader sends these parameters to the ADSP when an AFE
port starts (afe_send_cal). On mainline, q6afe-dai loads them from a file
named by the DAI's qcom,cal-firmware property, in this format (all LE u32):

    "QAFC", version 1, record count,
    then per record: module id, instance id, param id, size, data
    (data zero padded to a multiple of 4 bytes)

Usage: acdb-afe-cal.py <file.acdb> <acdb device id> <sample rate> <out>
"""

import struct
import sys


def chunks(d):
    """Map chunk name -> (offset of data, length). Header is 32 bytes."""
    out = {}
    o = 32
    while o + 12 <= len(d):
        name = d[o:o + 8].decode('latin1')
        ln = struct.unpack_from('<I', d, o + 8)[0]
        out[name] = (o + 12, ln)
        o += 12 + ln
    return out


def afe_cal(d, dev, rate):
    c = chunks(d)
    u32 = lambda o: struct.unpack_from('<I', d, o)[0]
    lut, lut_len = c['AFEILUT0']
    cdft = c['AFEICDFT'][0]
    cdot = c['AFEICDOT'][0]
    pool = c['DATAPOOL'][0]

    # AFE LUT rows: acdb device id, sample rate, CDFT offset, CDOT offset
    rows = u32(lut)
    width = (lut_len - 4) // 4 // rows
    for r in range(rows):
        row = [u32(lut + 4 + 4 * (r * width + k)) for k in range(width)]
        if row[0] != dev or row[1] != rate:
            continue
        defs, offs = cdft + row[2], cdot + row[3]
        count = u32(defs)
        assert u32(offs) == count
        for k in range(count):
            mid, iid, pid = struct.unpack_from('<III', d, defs + 4 + 12 * k)
            data_off = pool + u32(offs + 4 + 4 * k)
            size = u32(data_off)
            yield mid, iid, pid, d[data_off + 4:data_off + 4 + size]
        return
    sys.exit(f'no AFE calibration for acdb id {dev} at {rate} Hz')


def main():
    acdb, dev, rate, out = sys.argv[1:5]
    d = open(acdb, 'rb').read()
    assert d[:8] == b'QCMSNDDB', 'not an ACDB file'
    recs = list(afe_cal(d, int(dev, 0), int(rate, 0)))
    blob = b'QAFC' + struct.pack('<II', 1, len(recs))
    for mid, iid, pid, data in recs:
        blob += struct.pack('<IIII', mid, iid, pid, len(data))
        blob += data + b'\0' * (-len(data) % 4)
        print(f'{mid:#010x}/{iid:#x} {pid:#010x}: {len(data)} bytes')
    open(out, 'wb').write(blob)


if __name__ == '__main__':
    main()
