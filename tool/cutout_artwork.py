#!/usr/bin/env python3
"""원본 PNG에서 고양이·구름 그림만 알파로 오려낸다.

색은 원본 픽셀 그대로 두고 알파만 깎는다. 종이·카드 여백은 그림 테두리에
막힐 때까지 번지는 플러드 필로 지운다. 손으로 그린 실루엣 경로와 달리
실제 외곽선에 딱 붙어서 배경이 남지 않는다.

    python3 tool/cutout_artwork.py           # assets/cutouts/*.png 다시 만들기
    python3 tool/cutout_artwork.py --check   # 확인용 시트도 함께

`magick`(ImageMagick) 이 있어야 한다. 파이썬은 표준 라이브러리만 쓴다.
"""

import struct
import subprocess
import sys
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SIZE = (1536, 1024)   # 원본 크기 — 두 장 모두 같다.
SHEETS = {
    1: ROOT / "assets" / "malang1.png",
    2: ROOT / "assets" / "malang2.png",
}
OUT = ROOT / "assets" / "cutouts"
SHEET = ROOT / "build" / "cutout_check"

# 씨앗을 놓을 여백. 그림 바깥에서 시작해야 안쪽으로 새지 않는다.
PAD = 8


class Art:
    """그림 하나를 오려내는 설정.

    box    원본 좌표 LTRB. lib/widgets/original_artwork.dart 의 bounds() 와 같다.
    sheet  어느 원본에서 오려낼지. 1 은 malang1.png, 2 는 malang2.png.
    grow   씨앗 자리를 벌려 둘 변(tlrb). 이웃 카드나 카드 밖 종이까지
           넘어가지 않을 만큼만 벌린다.
    erase  무조건 지울 사각형 (LTRB). 색만으로는 여백과 구분되지 않는
           구석에만 쓴다.
    speck  이보다 작게 떨어져 남은 조각은 지운다. 수염이나 반짝임처럼
           떨어져 있어도 그림인 조각보다는 작게 잡는다.
    page   원본 알파가 이보다 옅으면 색을 따지지 않고 여백으로 본다.
           카드 가장자리는 종이와 섞인 자리라 기본값이 그것까지 포함한다.
           수채 번짐처럼 원래 옅게 그린 그림은 30 으로 낮춘다.
    dark   이보다 어두우면 외곽선으로 보고 멈춘다.
    bridge 외곽선을 점선처럼 끊어 그린 아이용. 지울 때는 외곽선을 이만큼
           부풀려 틈을 막고, 다 지운 뒤 그만큼 되돌린다. 틈으로 새는 깊이가
           이 값으로 묶여 몸통에 얼룩이 남지 않는다.
    off    여백 색에서 이만큼 벗어나면 그림으로 보고 멈춘다.
    step   이웃으로 번질 때 허용하는 색 차이. 종이 그라데이션은 넘고
           그림 경계는 못 넘는 값.
    """

    def __init__(self, box, sheet=1, grow="tlr", erase=(), speck=16, page=250,
                 dark=165.0, bridge=0, off=16.0, step=20.0):
        self.box = box
        self.sheet = sheet
        self.grow = grow
        self.erase = erase
        self.speck = speck
        self.page = page
        self.dark = dark
        self.bridge = bridge
        self.off = off
        self.step = step


ARTS = {
    "mochi": Art((316, 126, 500, 244)),
    "dalgi": Art((779, 407, 983, 532)),
    # 잠든 아이는 카드 위에 옅게 깔려 있어 몸 색이 카드와 거의 같다.
    # 기준을 좁게 잡아야 외곽선에서 멈춘다.
    "byeol": Art((1098, 362, 1460, 532), dark=0.0, off=11.0, step=9.0),
    "sol": Art((60, 748, 250, 916)),
    "trio": Art((551, 785, 984, 916)),
    # 옆 고양이 수염 끝이 칸에 걸린다 — 조각 기준을 조금 키운다.
    "nabi": Art((830, 793, 984, 916), speck=32),
    # 왼쪽 위로 카드 괘선이 지나간다.
    "kongi": Art((1262, 761, 1468, 915), erase=((1262, 776, 1298, 784),)),
    # 구름과 손글씨 제목. 수채 번짐이 옅어 기준을 더 좁게 잡는다.
    "title": Art((493, 22, 1051, 142), grow="tlrb", speck=32, page=30,
                 dark=0.0, off=9.0, step=9.0),

    # 두 번째 장(말랑 고양이 메모 · 두 번째 이야기)의 여섯 마리.
    "haneul": Art((300, 396, 509, 538), sheet=2),
    # 카드 모서리의 흰 곡선 장식이 칸에 걸린다.
    "noeul": Art((812, 133, 1001, 282), sheet=2,
                 erase=((955, 128, 992, 161),)),
    "bori": Art((1040, 388, 1276, 538), sheet=2,
                erase=((1040, 496, 1078, 532),)),
    # 카드 괘선과 모서리 장식이 함께 걸린다.
    "mongi": Art((274, 845, 509, 978), sheet=2,
                 erase=((274, 845, 326, 858), (486, 940, 509, 972))),
    "dalrae": Art((722, 848, 971, 978), sheet=2),
    # 몸 색이 노란 카드와 가까워 기준을 좁게 잡는다.
    # 외곽선을 점선처럼 끊어 그린 아이. 몸 색도 노란 카드와 가까워
    # 틈을 막고 지운 뒤 되돌린다.
    "danchu": Art((1302, 574, 1495, 733), sheet=2, bridge=3, off=8.0,
                  step=9.0, erase=((1450, 574, 1495, 604),)),
}


def read_region(sheet, left, top, right, bottom):
    """잘라낸 칸의 (보이는 색, 원본 색, 원본 알파)를 읽는다.

    원본 PNG는 종이 여백이 투명이고 그 밑 RGB 에는 엉뚱한 색이 깔려 있다.
    경계는 흰 종이에 얹어 보이는 색으로 찾고, 내보낼 때는 원본 색과
    알파를 그대로 쓴다.
    """
    w, h = right - left, bottom - top
    crop = ["-crop", f"{w}x{h}+{left}+{top}", "+repage", "-depth", "8"]

    def run(*extra):
        return subprocess.run(["magick", str(SHEETS[sheet])] + crop
                              + list(extra), check=True,
                              capture_output=True).stdout

    flat = parse_pnm(run("-background", "white", "-alpha", "remove",
                         "-alpha", "off", "ppm:-"), w, h, 3)
    raw = parse_pnm(run("-alpha", "off", "ppm:-"), w, h, 3)
    src_alpha = parse_pnm(run("-alpha", "extract", "pgm:-"), w, h, 1)
    return w, h, flat, raw, src_alpha


def parse_pnm(raw, w, h, bands):
    """P5/P6 헤더만 읽고 픽셀을 돌려준다.

    머리말 뒤 공백은 딱 한 글자다. 더 건너뛰면 첫 픽셀을 잃는다.
    """
    fields, pos = [], 0
    while len(fields) < 4:
        while raw[pos:pos + 1] in b" \t\r\n":
            pos += 1
        end = pos
        while raw[end:end + 1] not in b" \t\r\n":
            end += 1
        fields.append(raw[pos:end])
        pos = end + 1
    assert fields[0] in (b"P5", b"P6") and int(fields[3]) == 255, fields
    assert (int(fields[1]), int(fields[2])) == (w, h), fields
    body = raw[pos:pos + w * h * bands]
    assert len(body) == w * h * bands, (len(body), w, h, bands)
    return body


def edge_pixels(w, h):
    """칸의 네 변. 여백 지우기는 여기서 시작한다."""
    return ([(x, 0) for x in range(w)] + [(x, h - 1) for x in range(w)]
            + [(0, y) for y in range(h)] + [(w - 1, y) for y in range(h)])


def paper_colors(px, src_alpha, border, w):
    """여백 색 견본.

    테두리 픽셀을 16단계로 뭉쳐 세고 자주 나온 색만 남긴다. 카드와 종이처럼
    색이 둘 이상이어도 각각 기준이 되고, 테두리를 스치는 괘선이나 그림
    조각 같은 드문 색은 기준에서 빠진다. 카드 가장자리처럼 반쯤 투명한
    자리는 두 색이 섞여 있어 기준으로 쓰지 않는다.
    """
    bins = {}
    for x, y in border:
        i = y * w + x
        if src_alpha[i] < 250:
            continue   # 카드 밖이거나 카드 모서리 — 두 색이 섞여 있다.
        k = i * 3
        acc = bins.setdefault((px[k] >> 4, px[k + 1] >> 4, px[k + 2] >> 4),
                              [0, 0, 0, 0])
        acc[0] += px[k]
        acc[1] += px[k + 1]
        acc[2] += px[k + 2]
        acc[3] += 1
    floor = max(3, len(border) // 40)
    return [(a[0] / a[3], a[1] / a[3], a[2] / a[3])
            for a in bins.values() if a[3] >= floor]


def near_paper(px, i, paper, off):
    """여백 색 견본 중 하나에 가까우면 참."""
    k = i * 3
    r, g, b = px[k], px[k + 1], px[k + 2]
    lim = off * off
    return any((r - pr) ** 2 + (g - pg) ** 2 + (b - pb) ** 2 <= lim
               for pr, pg, pb in paper)


def cut(name, art):
    left, top, right, bottom = art.box
    cl = max(0, left - PAD) if "l" in art.grow else left
    ct = max(0, top - PAD) if "t" in art.grow else top
    cr = min(SIZE[0], right + PAD) if "r" in art.grow else right
    cb = min(SIZE[1], bottom + PAD) if "b" in art.grow else bottom
    w, h, px, raw, src_alpha = read_region(art.sheet, cl, ct, cr, cb)

    border = edge_pixels(w, h)
    paper = paper_colors(px, src_alpha, border, w)
    lum = [0.299 * px[i] + 0.587 * px[i + 1] + 0.114 * px[i + 2]
           for i in range(0, len(px), 3)]
    fat = swell(lum, w, h, art.dark, art.bridge) if art.bridge else None

    def blocked(i):
        if fat is not None and fat[i]:
            return True
        if src_alpha[i] < art.page:
            return False   # 종이 여백 — 색을 따지지 않고 지운다.
        return lum[i] < art.dark or not near_paper(px, i, paper, art.off)

    outside = bytearray(w * h)
    todo = []
    for x, y in border:
        i = y * w + x
        if not outside[i] and not blocked(i):
            outside[i] = 1
            todo.append((x, y))
    while todo:
        x, y = todo.pop()
        here = (y * w + x) * 3
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if not (0 <= nx < w and 0 <= ny < h):
                continue
            j = ny * w + nx
            if outside[j] or blocked(j):
                continue
            k = j * 3
            if ((px[k] - px[here]) ** 2 + (px[k + 1] - px[here + 1]) ** 2
                    + (px[k + 2] - px[here + 2]) ** 2) > art.step ** 2:
                continue
            outside[j] = 1
            todo.append((nx, ny))

    if fat is not None:
        shrink(outside, lum, px, paper, art, w, h)
    alpha = bytearray(0 if o else 255 for o in outside)
    for x1, y1, x2, y2 in art.erase:
        for y in range(max(0, y1 - ct), min(h, y2 - ct)):
            for x in range(max(0, x1 - cl), min(w, x2 - cl)):
                alpha[y * w + x] = 0
    close_pinholes(alpha, w, h)
    drop_specks(alpha, w, h, art.speck)
    soften(px, alpha, w, h)
    # 원본이 반쯤 투명한 자리는 그만큼 옅게 남긴다.
    for i in range(w * h):
        if src_alpha[i] < 255:
            alpha[i] = alpha[i] * src_alpha[i] // 255
    return crop_png(name, art, raw, alpha, w, cl, ct)


def swell(lum, w, h, dark, by):
    """외곽선을 `by` 칸만큼 부풀린 자리. 점선처럼 끊긴 틈을 막는다."""
    mask = bytearray(1 if v < dark else 0 for v in lum)
    edge = [i for i, v in enumerate(mask) if v]
    for _ in range(by):
        nxt = []
        for i in edge:
            x, y = i % w, i // w
            for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if 0 <= nx < w and 0 <= ny < h and not mask[ny * w + nx]:
                    mask[ny * w + nx] = 1
                    nxt.append(ny * w + nx)
        edge = nxt
    return mask


def shrink(outside, lum, px, paper, art, w, h):
    """부풀린 외곽선 자리를 여백 쪽에서 되돌린다.

    여백 색인 칸만 `bridge` 칸까지 되돌리므로, 외곽선 틈으로 새 들어가는
    깊이도 그만큼에서 멈춘다.
    """
    edge = [i for i, o in enumerate(outside) if o]
    for _ in range(art.bridge):
        nxt = []
        for i in edge:
            x, y = i % w, i // w
            for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if not (0 <= nx < w and 0 <= ny < h):
                    continue
                j = ny * w + nx
                if outside[j] or lum[j] < art.dark:
                    continue
                if not near_paper(px, j, paper, art.off):
                    continue
                outside[j] = 1
                nxt.append(j)
        edge = nxt


def close_pinholes(alpha, w, h, rounds=2, least=6):
    """그림 안쪽에 뚫린 자잘한 구멍을 메운다.

    외곽선을 점선처럼 끊어 그린 아이는 그 틈으로 여백 색이 새어 들어가
    몸통에 얼룩이 남는다. 이웃 여덟 칸 중 대부분이 그림이면 그 픽셀도
    그림으로 되돌린다. 넓은 여백은 이웃이 모자라 그대로 남는다.
    """
    for _ in range(rounds):
        back = []
        for y in range(h):
            for x in range(w):
                i = y * w + x
                if alpha[i]:
                    continue
                n = 0
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        nx, ny = x + dx, y + dy
                        if (0 <= nx < w and 0 <= ny < h
                                and alpha[ny * w + nx] and (dx or dy)):
                            n += 1
                if n >= least:
                    back.append(i)
        if not back:
            break
        for i in back:
            alpha[i] = 255


def drop_specks(alpha, w, h, least):
    """따로 떨어진 자잘한 조각을 지운다. 괘선 끝이나 옆 그림 부스러기다."""
    seen = bytearray(w * h)
    for start in range(w * h):
        if seen[start] or not alpha[start]:
            continue
        stack, cells = [start], []
        seen[start] = 1
        while stack:
            i = stack.pop()
            cells.append(i)
            x, y = i % w, i // w
            for nx in range(max(0, x - 1), min(w, x + 2)):
                for ny in range(max(0, y - 1), min(h, y + 2)):
                    j = ny * w + nx
                    if not seen[j] and alpha[j]:
                        seen[j] = 1
                        stack.append(j)
        if len(cells) < least:
            for i in cells:
                alpha[i] = 0


def soften(px, alpha, w, h):
    """외곽선 바깥에 남는 안티에일리어싱 띠의 알파를 실제 섞인 비율로 맞춘다.

    지운 이웃 색을 여백 B, 남긴 이웃 중 B 에서 가장 먼 색을 그림 F 로 보고
    이 픽셀이 B 와 F 사이 어디쯤인지로 알파를 정한다. 여백에 가까운 띠는
    옅어지고, 색이 뚜렷한 작은 장식은 그대로 남는다.
    """
    edge = {}
    for y in range(h):
        for x in range(w):
            i = y * w + x
            if not alpha[i]:
                continue
            br = bg = bb = n = 0
            kept = []
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    nx, ny = x + dx, y + dy
                    if not (0 <= nx < w and 0 <= ny < h):
                        continue
                    j = ny * w + nx
                    k = j * 3
                    if alpha[j]:
                        kept.append(k)
                    else:
                        br, bg, bb, n = (br + px[k], bg + px[k + 1],
                                         bb + px[k + 2], n + 1)
            if not n:
                continue
            br, bg, bb = br / n, bg / n, bb / n

            def off(k):
                return ((px[k] - br) ** 2 + (px[k + 1] - bg) ** 2
                        + (px[k + 2] - bb) ** 2) ** 0.5

            far = max(off(k) for k in kept)
            if far < 1:
                continue
            edge[i] = min(alpha[i], round(255 * min(1.0, off(i * 3) / far)))
    for i, a in edge.items():
        alpha[i] = a


def crop_png(name, art, rgb, alpha, w, cl, ct):
    """선언한 좌표로 되돌려 저장한다 — 배치 좌표는 그대로 쓴다."""
    left, top, right, bottom = art.box
    ox, oy, ow, oh = left - cl, top - ct, right - left, bottom - top
    rows = bytearray()
    kept = 0
    for y in range(oy, oy + oh):
        rows.append(0)
        for x in range(ox, ox + ow):
            i = y * w + x
            k = i * 3
            rows += bytes((rgb[k], rgb[k + 1], rgb[k + 2], alpha[i]))
            kept += alpha[i] > 0
    write_png(OUT / f"{name}.png", ow, oh, rows)
    return f"{name}: {ow}x{oh}, 남긴 픽셀 {kept * 100 // (ow * oh)}%"


def write_png(path, w, h, rows):
    def chunk(tag, body):
        return (struct.pack(">I", len(body)) + tag + body
                + struct.pack(">I", zlib.crc32(tag + body) & 0xFFFFFFFF))

    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(bytes(rows), 9))
        + chunk(b"IEND", b""))


def check_sheet():
    """잘린 자리를 눈으로 보려고 진한 배경에 올린 시트를 만든다."""
    SHEET.mkdir(parents=True, exist_ok=True)
    for name in ARTS:
        subprocess.run(
            ["magick", str(OUT / f"{name}.png"), "-background", "#3aa0ff",
             "-layers", "flatten", "-scale", "250%",
             str(SHEET / f"{name}.png")], check=True)
    print(f"확인용 시트: {SHEET}")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for name, art in ARTS.items():
        print(cut(name, art))
    if "--check" in sys.argv:
        check_sheet()
