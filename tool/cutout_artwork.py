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
from collections import deque
import sys
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SIZE = (1536, 1024)   # 원본 크기 — 두 장 모두 같다.
SHEETS = {
    1: ROOT / "assets" / "malang1.png",
    2: ROOT / "assets" / "malang2.png",
}
# 남색 밤하늘 위에 그린 세 번째 장. 종이가 아니라 어두운 바탕이라
# cut_space 가 따로 오려낸다.
SPACE_SHEET = ROOT / "assets" / "malang3.png"
SPACE_SIZE = (1024, 1536)
SPACE_BG = (15, 26, 52)
# 네 번째 장도 같은 남색 하늘이지만 바탕이 조금 더 푸르다. 장마다 견본을 따로 둔다.
SPACE_SHEET2 = ROOT / "assets" / "malang4.png"
SPACE_BG2 = (11, 26, 56)
# 다섯 번째 장. 바탕이 가장 어둡고, 그림 둘레에 옅은 빛무리가 있다.
SPACE_SHEET3 = ROOT / "assets" / "malang5.png"
SPACE_BG3 = (8, 24, 54)
OUT = ROOT / "assets" / "cutouts"
# 밤하늘에서만 쓰는 짝. 테두리 색만 다르고 알파는 같다.
NIGHT = OUT / "night"
# 이보다 짙으면 테두리가 아니라 그림 몸통으로 본다.
SOLID = 200
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
    bleach 이 사각형 안에서 흰 것만 지운다. 카드 모서리의 흰 곡선
           장식이 수염과 겹쳐 그려진 자리처럼, 통째로 지우면 그림까지
           함께 사라지는 곳에 쓴다. 다섯 번째 값을 주면 그보다 밝은 것을
           모두 지운다 — 옅은 색 얼룩처럼 흰색이 아닌 것도 걷어낼 때.
    keep   이 사각형 안에서 외곽선 색인 획을 되살린다. 획 가운데가 옅게
           칠해져 여백으로 잘못 지워진 수염 끝에 쓴다. 어두운 만큼 짙게
           남긴다.
    fill   이 사각형 안을 빈틈 없이 채운다. 얼굴 아래가 카드 테두리에
           닿아 흰 털이 그 테두리 색과 함께 지워진 자리에 쓴다. 지워진
           픽셀에는 바로 위 픽셀 색을 내려 받아, 털 색이 테두리까지
           이어진다.
    mirror 오려낸 뒤 한 자리를 좌우로 뒤집어 다른 자리에 얹는다.
           ((L,T,R,B), 놓을 왼쪽 x[, 기울기]) 꼴. 기울기를 주면 띠 아래
           끝으로 갈수록 그만큼(음수면 왼쪽으로) 밀어 얹어, 양쪽 얼굴선이
           대칭이 아닌 자리에서도 이음매가 맞는다. 원본에서 옆 그림과 얽혀 도저히
           갈라낼 수 없는 자리에만 쓴다 — 그림을 새로 그리는 것이 아니라
           그 아이 몸에서 온 획을 그대로 옮긴다.
    wall   지우기가 넘어가지 못하는 사각형 (LTRB). 옆 그림이 칸에 걸쳐
           들어와 색이 이어질 때, 거기서 시작하거나 그리로 번지는 것을
           막는다. 여백 색 견본에서도 빠지므로, 옆 고양이 흰 털이 여백
           기준이 되어 이쪽 털까지 지워지는 일이 없다. 막은 자리는
           마지막에 함께 지운다.
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
    flecks 몸통과 떨어져 바깥에 붙은 옅은 조각을 지운다. 외곽선을 점선처럼
           끊어 그린 아이는 몸 색이 종이와 비슷해, 외곽선 바깥에 남은 종이가
           몸과 같은 색으로 남는다. 이 값(픽셀 수)보다 작은 옅은 덩어리 중
           바깥 투명한 자리에 닿는 것만 지운다. 입 안 하이라이트처럼 그림
           안에 갇힌 덩어리와, 몸통 하나로 이어진 큰 덩어리는 건드리지 않는다.
    """

    def __init__(self, box, sheet=1, grow="tlr", erase=(), wall=(), mirror=(),
                 bleach=(), keep=(), fill=(), blend=0, speck=16, page=250, dark=165.0, bridge=0,
                 off=16.0, step=20.0, flecks=0):
        self.box = box
        self.wall = wall
        self.mirror = mirror
        self.bleach = bleach
        self.keep = keep
        self.fill = fill
        self.blend = blend
        self.sheet = sheet
        self.grow = grow
        self.erase = erase
        self.speck = speck
        self.page = page
        self.dark = dark
        self.bridge = bridge
        self.off = off
        self.step = step
        self.flecks = flecks


ARTS = {
    # 머리 왼쪽과 귀 옆 "!!" 표시 사이로 흰 선이 한 줄 지나간다. 밝은
    # 배경에서는 묻히지만 밤하늘에서는 떠 보인다.
    "mochi": Art((316, 126, 500, 244),
                 erase=((336, 161, 344, 162), (339, 162, 344, 163),
                        (340, 163, 343, 164), (340, 164, 341, 165),
                        (474, 161, 480, 162), (479, 162, 480, 163))),
    # 얼굴 아래가 카드 테두리에 닿아, 그 사이 흰 털이 테두리 색과 함께
    # 지워진다.
    "dalgi": Art((779, 407, 983, 532), fill=((830, 524, 953, 532),)),
    # 잠든 아이는 카드 위에 옅게 깔려 있어 몸 색이 카드와 거의 같다.
    # 기준을 좁게 잡아야 외곽선에서 멈춘다.
    "byeol": Art((1098, 362, 1460, 532), dark=0.0, off=11.0, step=9.0),
    # 왼쪽 수염 끝이 칸 밖으로 나가 잘려 있었다. 칸을 넓히면 카드
    # 모서리의 흰 곡선 장식이 따라 들어와, 그 자리에서는 흰 것만 지운다.
    "sol": Art((48, 748, 250, 916), bleach=((48, 748, 76, 916),)),
    "trio": Art((551, 785, 984, 916)),
    # 왼쪽 수염은 옆 고양이 수염과 같은 획으로 겹쳐 그려져 있어, 어디서
    # 잘라도 두 아이 수염이 한 덩어리로 남는다. 왼쪽 볼을 통째로 비우고,
    # 이 아이 오른쪽 볼에서 볼터치·외곽선·수염이 한 덩이로 든 띠를 떠다
    # 얼굴 한가운데를 축으로 뒤집어 얹는다. 귀 위의 옅은 초록 땀방울은
    # 밝은 것만 걷는다.
    "nabi": Art((812, 793, 984, 916), speck=20,
                # 축은 x = 900 — 양쪽 외곽선 바깥 끝이 840 과 960 이다.
                # 띠 위끝은 양쪽 외곽선이 같은 자리에 오는 줄이다. 오른쪽
                # 얼굴선은 아래로 갈수록 안쪽으로 들어가 있어, 그대로 뒤집으면
                # 띠 아래 끝에서 외곽선이 어긋나고 가늘어진다. 아래로 갈수록
                # 5칸까지 바깥으로 밀어 발 바로 위에서 원래 외곽선과 잇는다.
                # 그 아래 두 줄에 걸친 옆 고양이 수염 끝은 막아 지운다.
                wall=((796, 770, 812, 930), (812, 785, 830, 930),
                      (812, 851, 845, 894), (826, 894, 834, 896)),
                bleach=((884, 796, 918, 822, 180),),
                blend=4,
                mirror=(((952, 851, 985, 894), 816, -5),)),
    # 왼쪽 위로 카드 괘선이 지나간다.
    "kongi": Art((1262, 761, 1468, 915), erase=((1262, 776, 1298, 784),)),
    # 구름과 손글씨 제목. 수채 번짐이 옅어 기준을 더 좁게 잡는다.
    "title": Art((493, 22, 1051, 142), grow="tlrb", speck=32, page=30,
                 dark=0.0, off=9.0, step=9.0),

    # 두 번째 장(말랑 고양이 메모 · 두 번째 이야기)의 여섯 마리.
    "haneul": Art((300, 396, 509, 538), sheet=2),
    # 카드 모서리의 흰 곡선 장식이 왼쪽 수염과 겹쳐 그려져 있다. 통째로
    # 지우면 수염까지 잘리므로 그 자리에서는 흰 것만 지운다.
    "bori": Art((1040, 388, 1276, 538), sheet=2,
                bleach=((1040, 492, 1085, 538), (1155, 524, 1180, 538))),
    # 카드 괘선과 모서리 장식이 함께 걸린다.
    # 왼쪽 수염 사이에 카드의 보랏빛이, 오른쪽 수염 바깥에 카드 모서리
    # 장식의 흰 곡선이 남는다.
    "mongi": Art((274, 845, 509, 978), sheet=2,
                 erase=((274, 845, 326, 858), (486, 940, 509, 972)),
                 bleach=((292, 929, 311, 942, 190), (474, 924, 482, 937, 190),
                         (468, 940, 476, 948, 190), (466, 952, 494, 972, 190),
                         (318, 968, 342, 977, 190))),
    # 오른쪽 수염 아래와 오른쪽 아래 구석에 남는 흰 얼룩.
    # 오른쪽 가운데 수염 끝이 옅게 칠해져 여백과 함께 지워진다.
    "dalrae": Art((722, 848, 971, 978), sheet=2,
                  erase=((947, 939, 955, 946), (958, 957, 971, 969),
                         (720, 896, 738, 908)),
                  bleach=((738, 930, 746, 937, 190),),
                  keep=((938, 929, 958, 939),)),
    # 몸 색이 노란 카드와 가까워 기준을 좁게 잡는다.
    # 외곽선을 점선처럼 끊어 그린 아이. 몸 색도 노란 카드와 가까워
    # 틈을 막고 지운 뒤 되돌린다.
    "danchu": Art((1302, 574, 1495, 733), sheet=2, bridge=3, off=8.0,
                  step=9.0, flecks=120,
                  # 오른쪽 위 모서리 장식과, 왼쪽 수염 위로 잘려 들어온
                  # 옆 칸 하트 끝.
                  erase=((1450, 574, 1495, 604), (1300, 654, 1314, 684))),
}


# 우주 고양이 여섯 마리. 칸은 그림 하나와 그 곁의 별·점을 담는다 — 위아래는
# y=530, y=1000 에서, 왼쪽과 오른쪽은 줄마다 그림 사이의 빈 곳에서 가른다.
SPACE_ARTS = {
    "ujoo": (20, 40, 514, 530),        # 유에프오를 탄 검은 고양이
    "byeoltong": (514, 30, 1024, 530),  # 별 그물을 든 주황 줄무늬
    "dalbit": (0, 530, 503, 1000),      # 달 위에서 망원경을 보는 삼색
    "eunha": (503, 530, 1024, 1000),    # 망토에 물뿌리개, 별꽃 소행성
    "choco": (0, 1000, 476, 1536),      # 별 수첩에 쓰는 샴
    "pyeonji": (476, 1000, 1024, 1536),  # 별 우체통에 편지 넣는 턱시도
}


# 네 번째 장의 여섯 마리. 위아래는 y=540, y=1000 (줄 사이 빈 곳), 왼쪽과 오른쪽은
# 줄마다 그림 사이의 빈 곳에서 가른다.
SPACE_ARTS2 = {
    "cho": (20, 40, 506, 540),        # 초승달에 누운 보라 무늬
    "byeol2": (506, 60, 1024, 540),   # 별을 끌어안은 삼색
    "usubu": (20, 540, 506, 1000),    # 우주복을 입은 삼색
    "got": (506, 540, 1024, 1000),    # 고리 행성 위의 두 마리
    "rocket": (0, 1000, 500, 1536),   # 로켓을 탄 삼색
    "byeoljari": (500, 1000, 1024, 1536),  # 별자리 아래 앉은 세 마리
}


# 다섯 번째 장의 여섯 마리. 세로 줄마다 그림 사이의 빈 곳이 달라 칸을 따로 잡는다.
SPACE_ARTS3 = {
    "nakksi": (0, 40, 530, 567),         # 파란 행성에서 별을 낚는 잠옷 쓴 아이
    "yuribyeong": (530, 40, 1024, 490),  # 별을 담은 유리병을 안은 주황 줄무늬
    "wiseong": (0, 567, 550, 1000),      # 인공위성에 앉은 턱시도
    "pungseon": (550, 490, 1024, 1010),  # 행성 풍선을 든 삼색
    "haemak": (0, 1000, 515, 1536),      # 달 해먹에 누운 샴
    "byeolit": (515, 1010, 1024, 1536),  # 달 위에서 별을 이어 붙이는 두 마리
}


# 갇힌 빈 바탕이 기준으로는 안 잡히는 자리(그림 안쪽 빛무리가 스민 곳). 원본 좌표
# 사각형 안에서 어둡고 붉은 기 없는 픽셀만 지운다. 갈색 외곽선은 붉어서 남고
# 털이나 그림 색은 밝아서 남는다.
SPACE_ERASE = {
    # 행성 고리 안쪽, 그리고 풍선 끈 사이.
    "nakksi": [(80, 358, 125, 402)],
    # 끈 사이만. 귀의 회색 무늬(x<795, y>735)는 이 색 기준에 걸리므로 비켜 잡는다.
    "pungseon": [(762, 685, 800, 733), (800, 730, 860, 765)],
}


def erase_navy(rgba, px, w, rects):
    for x0, y0, x1, y1 in rects:
        for y in range(y0, y1):
            for x in range(x0, x1):
                i = y * w + x
                r, g, b = px[i * 3], px[i * 3 + 1], px[i * 3 + 2]
                lum = 0.299 * r + 0.587 * g + 0.114 * b
                # 어둡고(밝기 105 미만) 붉은 기가 거의 없는 것(r-g 가 작음)만. 갈색
                # 외곽선은 r-g 가 40 넘게 벌어져 남는다.
                if lum < 105 and (r - g) < 24 and (r - b) < 24:
                    rgba[i * 4 + 3] = 0


def read_space(sheet=None):
    """우주 고양이 장을 (가로, 세로, RGB 바이트)로 읽는다."""
    w, h = SPACE_SIZE
    raw = subprocess.run(
        ["magick", str(sheet or SPACE_SHEET), "-alpha", "off", "-depth", "8",
         "ppm:-"], check=True, capture_output=True).stdout
    return w, h, parse_pnm(raw, w, h, 3)


def outside_mask(px, w, h, bg=SPACE_BG, tol=30):
    """가장자리에서 바탕색을 따라 이어진 자리. 몸통 안의 검은 털처럼 바탕과
    비슷해도 외곽선에 둘러싸인 곳은 여기 들지 않는다."""
    limit = tol * tol
    def near(i):
        k = i * 3
        return ((px[k] - bg[0]) ** 2 + (px[k + 1] - bg[1]) ** 2
                + (px[k + 2] - bg[2]) ** 2) <= limit
    out = bytearray(w * h)
    todo = deque()
    for x in range(w):
        for y in (0, h - 1):
            i = y * w + x
            if not out[i] and near(i):
                out[i] = 1
                todo.append(i)
    for y in range(h):
        for x in (0, w - 1):
            i = y * w + x
            if not out[i] and near(i):
                out[i] = 1
                todo.append(i)
    while todo:
        i = todo.popleft()
        x, y = i % w, i // w
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= nx < w and 0 <= ny < h:
                j = ny * w + nx
                if not out[j] and near(j):
                    out[j] = 1
                    todo.append(j)
    return out


def space_layer(px, w, h, bg=SPACE_BG, weak=55.0, halo=8, pocket=12.0,
                pocket_min=20):
    """세 번째 장의 RGBA 를 만든다.

    가장자리에서 바탕색을 따라 이어진 옅은 자리([weak] 보다 바탕에 가까운
    픽셀)가 바깥이다. 별 둘레의 은은한 빛도 이만큼 옅어 바깥에 든다.

    바깥과 닿은 가장자리 띠와 바깥 [halo] 칸 안쪽은 바탕 남색과 가까운 그림
    색 사이 어디쯤인지로 알파를 정하고, 색은 남색이 섞인 채가 아니라 그 그림
    색으로 칠한다. 섞인 채 두면 밝은 카드 위에서 그림 둘레가 남색 띠로 뜬다.
    기준 색은 둘이다.
      · 외곽선 색 — 바깥에서 2칸 넘게 들어간 가장 가까운 픽셀. 고양이의 갈색
        외곽선 가장자리가 이쪽이다.
      · 몸통 색 — 5칸 넘게 들어간 가장 가까운 픽셀. 별의 노란 몸통이다. 별
        둘레의 빛은 이미 남색이 섞여 가장자리 픽셀을 기준으로 삼으면 그 탁한
        색을 따라가 어두운 얼룩이 남으므로, 몸통 색 쪽 줄 위에 놓인 픽셀은 먼저
        이 색으로 칠한다.
    어느 쪽 줄에도 놓이지 않은 가장자리는 진짜 그림 디테일(수염, 작은 점)이라
    그대로 둔다. 외곽선에 둘러싸인 자리는 바탕과 닮은 검은 털이라도 바깥이
    아니므로 지우지 않는다.
    """
    out = outside_mask(px, w, h, bg, weak)

    # 삼각대 다리 사이처럼 외곽선에 갇힌 빈 바탕. 바탕색과 거의 같은 덩어리는
    # 바깥과 이어지지 않아도 지운다. 바탕과 닮은 검은 털(거리 26 안팎)은 이보다
    # 훨씬 멀어 남는다.
    def blank(i):
        k = i * 3
        return ((px[k] - bg[0]) ** 2 + (px[k + 1] - bg[1]) ** 2
                + (px[k + 2] - bg[2]) ** 2) < pocket * pocket

    seen = bytearray(w * h)
    for start in range(w * h):
        if out[start] or seen[start] or not blank(start):
            continue
        seen[start] = 1
        stack, comp = [start], []
        while stack:
            i = stack.pop()
            comp.append(i)
            x, y = i % w, i // w
            for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if 0 <= nx < w and 0 <= ny < h:
                    j = ny * w + nx
                    if not out[j] and not seen[j] and blank(j):
                        seen[j] = 1
                        stack.append(j)
        if len(comp) >= pocket_min:
            for i in comp:
                out[i] = 1

    cap = 6
    depth = [-1] * (w * h)
    todo = deque()
    for i in range(w * h):
        if out[i]:
            depth[i] = 0
            todo.append(i)
    while todo:
        i = todo.popleft()
        if depth[i] >= cap:
            continue
        x, y = i % w, i // w
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h:
                    j = ny * w + nx
                    if depth[j] < 0:
                        depth[j] = depth[i] + 1
                        todo.append(j)

    def spread(min_depth, limit):
        """[min_depth] 칸 넘게 안쪽인 픽셀의 색을 바깥 [limit] 칸까지 번지게 한다."""
        near = [-1] * (w * h)
        reach = bytearray(w * h)
        q = deque()
        for i in range(w * h):
            # 깊이를 못 잰 자리(-1)는 cap 보다 깊다.
            if not out[i] and (depth[i] < 0 or depth[i] > min_depth):
                near[i] = i
                q.append(i)
        while q:
            i = q.popleft()
            if reach[i] >= limit:
                continue
            x, y = i % w, i // w
            for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if 0 <= nx < w and 0 <= ny < h:
                    j = ny * w + nx
                    if near[j] < 0:
                        near[j] = near[i]
                        reach[j] = reach[i] + 1
                        q.append(j)
        return near, reach

    edge_ref, edge_reach = spread(1, halo + 2)

    lum = [0.299 * px[i * 3] + 0.587 * px[i * 3 + 1] + 0.114 * px[i * 3 + 2]
           for i in range(w * h)]

    def brightest(i, reach=9, least=185.0):
        """둘레에서 가장 밝은 그림 픽셀(별의 노란 몸통, 흰 털). 달처럼 어두운
        물체는 밝지 않아 기준이 되지 못한다."""
        x, y = i % w, i // w
        best, best_lum = -1, least
        for yy in range(max(0, y - reach), min(h, y + reach + 1), 2):
            base = yy * w
            for xx in range(max(0, x - reach), min(w, x + reach + 1), 2):
                j = base + xx
                if not out[j] and lum[j] > best_lum:
                    best, best_lum = j, lum[j]
        return best

    def mix(i, f):
        """i 번 픽셀을 바탕과 f 번 픽셀 사이의 섞임으로 볼 때 (몫, 줄에서 벗어난 거리)."""
        k, fk = i * 3, f * 3
        vr, vg, vb = px[fk] - bg[0], px[fk + 1] - bg[1], px[fk + 2] - bg[2]
        norm = vr * vr + vg * vg + vb * vb
        if norm == 0:
            return 0.0, 1e9
        pr, pg, pb = px[k] - bg[0], px[k + 1] - bg[1], px[k + 2] - bg[2]
        t = (pr * vr + pg * vg + pb * vb) / norm
        er, eg, eb = pr - t * vr, pg - t * vg, pb - t * vb
        return t, (er * er + eg * eg + eb * eb) ** 0.5

    rgba = bytearray(w * h * 4)
    for i in range(w * h):
        k, o = i * 3, i * 4
        deep = not out[i] and (depth[i] < 0 or depth[i] > 4)
        if deep:
            rgba[o:o + 3] = px[k:k + 3]
            rgba[o + 3] = 255
            continue
        pick = None
        # 바깥에서 멀지 않은 픽셀만 별빛일 수 있다.
        # 빛무리는 바탕이 섞여 어둡다. 밝은 픽셀(줄기, 잎)은 이 길로 보내지 않는다.
        f = brightest(i) if depth[i] <= 4 and lum[i] < 115 else -1
        if f >= 0 and f != i:
            t, off = mix(i, f)
            if off <= 22 and t > .03:
                pick = (f, t, 0, 1)
        if pick is None:
            f = edge_ref[i]
            if f >= 0 and f != i:
                t, off = mix(i, f)
                if off <= 28:
                    pick = (f, t, edge_reach[i], halo + 2)
        if pick is None:
            if not out[i]:
                rgba[o:o + 3] = px[k:k + 3]
                rgba[o + 3] = 255
            continue
        f, t, r, limit = pick
        a = max(0.0, min(1.0, t))
        if out[i] and limit > 1:
            # 빛이 끝에서 뚝 끊기지 않게, 마지막 세 칸은 옅게 잦아든다.
            a *= min(1.0, (limit - r) / 3)
        if a < .04:
            continue
        fk = f * 3
        rgba[o:o + 3] = px[fk:fk + 3]
        rgba[o + 3] = round(255 * a)
    return rgba


def cut_space(name, box, rgba, w, h):
    """칸 안에서 남은 픽셀의 바깥 사각형으로 잘라 저장한다."""
    left, top, right, bottom = box
    x0 = y0 = 10 ** 9
    x1 = y1 = -1
    for y in range(top, bottom):
        base = y * w
        for x in range(left, right):
            if rgba[(base + x) * 4 + 3]:
                if x < x0: x0 = x
                if x > x1: x1 = x
                if y < y0: y0 = y
                if y > y1: y1 = y
    x0, y0, x1, y1 = x0 - 1, y0 - 1, x1 + 1, y1 + 1
    ow, oh = x1 - x0 + 1, y1 - y0 + 1
    rows = bytearray()
    for y in range(y0, y1 + 1):
        rows.append(0)
        rows += rgba[(y * w + x0) * 4:(y * w + x1 + 1) * 4]
    write_png(OUT / f"{name}.png", ow, oh, rows)
    return f"{name}: {ow}x{oh} (원본 {x0},{y0})"


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
    raw = bytearray(raw)

    walled = bytearray(w * h)
    for x1, y1, x2, y2 in art.wall:
        for y in range(max(0, y1 - ct), min(h, y2 - ct)):
            for x in range(max(0, x1 - cl), min(w, x2 - cl)):
                walled[y * w + x] = 1

    border = [(x, y) for x, y in edge_pixels(w, h) if not walled[y * w + x]]
    paper = paper_colors(px, src_alpha, border, w)
    lum = [0.299 * px[i] + 0.587 * px[i + 1] + 0.114 * px[i + 2]
           for i in range(0, len(px), 3)]
    fat = swell(lum, w, h, art.dark, art.bridge) if art.bridge else None

    def blocked(i):
        if walled[i]:
            return True
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
    for i in range(w * h):
        if walled[i]:
            alpha[i] = 0
    for x1, y1, x2, y2 in art.erase:
        for y in range(max(0, y1 - ct), min(h, y2 - ct)):
            for x in range(max(0, x1 - cl), min(w, x2 - cl)):
                alpha[y * w + x] = 0
    close_pinholes(alpha, w, h)
    drop_specks(alpha, w, h, art.speck)
    soften(px, alpha, walled, w, h)
    # 원본이 반쯤 투명한 자리는 그만큼 옅게 남긴다.
    for i in range(w * h):
        if src_alpha[i] < 255:
            alpha[i] = alpha[i] * src_alpha[i] // 255
    for x1, y1, x2, y2, *light in art.bleach:
        light = light[0] if light else 232
        for i in cells(x1, y1, x2, y2, cl, ct, w, h):
            if lum[i] > light:
                alpha[i] = 0
    for rect in art.keep:
        for i in cells(*rect, cl, ct, w, h):
            # 종이 밝기(230)에서 획 밝기(150)까지를 알파 0~255 로 편다.
            ink = round(255 * min(1.0, max(0.0, (230 - lum[i]) / 80)))
            alpha[i] = max(alpha[i], ink)
    for x1, y1, x2, y2 in art.fill:
        for x in range(max(0, x1 - cl), min(w, x2 - cl)):
            # 사각형 바로 위에서 가장 가까운 흰 털. 입이나 발 획 아래로도
            # 획 색이 아니라 털 색이 내려온다.
            y = y1 - ct - 1
            while y >= 0 and not (alpha[y * w + x] > 240
                                  and lum[y * w + x] > 235):
                y -= 1
            fur = raw[(y * w + x) * 3:(y * w + x) * 3 + 3] if y >= 0 else None
            for y in range(max(0, y1 - ct), min(h, y2 - ct)):
                i = y * w + x
                # 남아 있던 밝은 픽셀도 테두리 색이 섞여 있어 함께 덮는다.
                if fur and lum[i] > 200:
                    raw[i * 3:i * 3 + 3] = fur
                alpha[i] = 255
    for (sl, st, sr, sb), dl, *lean in art.mirror:
        # 오른쪽 끝 몇 칸은 원래 그림과 섞어 이음매가 선으로 보이지 않게 한다.
        last = dl + (sr - 1 - sl)
        lean = lean[0] if lean else 0
        for y in range(st, sb):
            # 아래로 갈수록 떠 올 자리를 옆으로 민다. 놓는 자리는 그대로라
            # 막은 자리를 빈틈 없이 덮는다.
            shift = round(lean * (y - st) / max(1, sb - 1 - st))
            for here in range(dl, last + 1):
                x = sr - 1 - (here - dl) + shift
                sx, sy = x - cl, y - ct
                dx, dy = here - cl, y - ct
                if not (0 <= sx < w and 0 <= sy < h):
                    continue
                if not (0 <= dx < w and 0 <= dy < h):
                    continue
                a = alpha[sy * w + sx]
                if not a:
                    continue
                inset = last - here
                t = 1.0
                if art.blend and inset < art.blend:
                    t = (inset + 1) / (art.blend + 1)
                d, sidx = dy * w + dx, sy * w + sx
                # 이음매 쪽 원래 픽셀은 막은 자리와 닿아 옅어져 있을 수 있다.
                # 색만 섞고 알파는 짙은 쪽을 따라 틈이 비치지 않게 한다.
                alpha[d] = max(alpha[d], a)
                j, k = d * 3, sidx * 3
                for c in range(3):
                    raw[j + c] = round(raw[j + c] * (1 - t) + raw[k + c] * t)
    if art.flecks:
        drop_flecks(alpha, lum, w, h, art.flecks)
    crop_png(name, art, night_edges(raw, alpha, w, h), alpha, w, cl, ct,
             NIGHT)
    return crop_png(name, art, raw, alpha, w, cl, ct)


def night_edges(rgb, alpha, w, h):
    """반투명한 테두리 픽셀에 가장 가까운 불투명 픽셀의 색을 입힌다.

    오려낸 테두리는 원본 종이와 섞인 밝은 색을 그대로 지니고 알파만 낮다.
    흰 종이나 옅은 카드 위에서는 그 색이 배경과 같아 보이지 않지만, 남색
    하늘 위에서는 외곽선을 따라 하얀 띠로 뜬다. 외곽선 색을 바깥으로 이어
    칠하면 알파가 그대로라 모양은 같고, 테두리가 하늘 쪽으로 곱게 스민다.
    """
    near = [-1] * (w * h)
    todo = deque()
    for i in range(w * h):
        # 원본 알파가 조금 모자란 몸통(250 남짓)도 온전한 그림으로 본다.
        if alpha[i] >= SOLID:
            near[i] = i
            todo.append(i)
    while todo:
        i = todo.popleft()
        x, y = i % w, i // w
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= nx < w and 0 <= ny < h:
                j = ny * w + nx
                if near[j] < 0:
                    near[j] = near[i]
                    todo.append(j)
    out = bytearray(rgb)
    for i in range(w * h):
        if 0 < alpha[i] < SOLID and near[i] >= 0:
            k, s = i * 3, near[i] * 3
            out[k:k + 3] = rgb[s:s + 3]
    return out


def drop_flecks(alpha, lum, w, h, most, pale=215, skirt=200):
    """몸통과 떨어져 바깥에 붙은 옅은 조각을 지운다.

    옅은 픽셀(밝기 [pale] 초과)끼리 이어진 덩어리를 세어, [most] 보다 작고
    투명한 자리에 닿는 것만 지운다. 지운 자리 바로 옆의 밝은 가장자리
    ([skirt] 초과)도 함께 걷어, 흐릿한 테가 남지 않게 한다.
    """
    light = [alpha[i] > 40 and lum[i] > pale for i in range(w * h)]
    seen = bytearray(w * h)
    gone = []
    for start in range(w * h):
        if not light[start] or seen[start]:
            continue
        seen[start] = 1
        stack, comp = [start], []
        while stack:
            i = stack.pop()
            comp.append(i)
            x, y = i % w, i // w
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h:
                        j = ny * w + nx
                        if light[j] and not seen[j]:
                            seen[j] = 1
                            stack.append(j)
        if len(comp) >= most:
            continue
        outside = any(
            not (0 <= i % w + dx < w and 0 <= i // w + dy < h)
            or alpha[(i // w + dy) * w + i % w + dx] <= 40
            for i in comp for dy in (-1, 0, 1) for dx in (-1, 0, 1))
        if outside:
            gone += comp
    for i in gone:
        alpha[i] = 0
    for i in gone:
        x, y = i % w, i // w
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h:
                    j = ny * w + nx
                    if alpha[j] and lum[j] > skirt and not light[j]:
                        alpha[j] = 0


def cells(x1, y1, x2, y2, cl, ct, w, h):
    """원본 좌표 사각형 (LTRB) 안의 픽셀 번호."""
    for y in range(max(0, y1 - ct), min(h, y2 - ct)):
        for x in range(max(0, x1 - cl), min(w, x2 - cl)):
            yield y * w + x


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


def soften(px, alpha, walled, w, h):
    """외곽선 바깥에 남는 안티에일리어싱 띠의 알파를 실제 섞인 비율로 맞춘다.

    지운 이웃 색을 여백 B, 남긴 이웃 중 B 에서 가장 먼 색을 그림 F 로 보고
    이 픽셀이 B 와 F 사이 어디쯤인지로 알파를 정한다. 여백에 가까운 띠는
    옅어지고, 색이 뚜렷한 작은 장식은 그대로 남는다. 막은 자리는 여백이
    아니라 나중에 다른 그림이 얹힐 자리라 따지지 않는다.
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
                    if walled[j]:
                        continue
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


def crop_png(name, art, rgb, alpha, w, cl, ct, out=OUT):
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
    write_png(out / f"{name}.png", ow, oh, rows)
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
    for name in list(ARTS) + list(SPACE_ARTS) + list(SPACE_ARTS2) + list(SPACE_ARTS3):
        subprocess.run(
            ["magick", str(OUT / f"{name}.png"), "-background", "#3aa0ff",
             "-layers", "flatten", "-scale", "250%",
             str(SHEET / f"{name}.png")], check=True)
    print(f"확인용 시트: {SHEET}")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    NIGHT.mkdir(parents=True, exist_ok=True)
    for name, art in ARTS.items():
        print(cut(name, art))
    # 어두운 바탕에 그린 우주 고양이. 낮·밤 짝이 따로 없다 — 테두리가 이미
    # 외곽선 색이라 어느 배경 위에서도 그대로 쓴다.
    # 마지막 값은 장마다 다른 기준. 다섯 번째 장은 빛무리가 그림 안쪽 빈 바탕까지
    # 스며 바탕과의 거리가 커서, 갇힌 빈 곳을 더 넉넉히 잡고 빛무리 폭을 좁힌다.
    for sheet, bg, arts, opts in (
            (SPACE_SHEET, SPACE_BG, SPACE_ARTS, {}),
            (SPACE_SHEET2, SPACE_BG2, SPACE_ARTS2, {}),
            (SPACE_SHEET3, SPACE_BG3, SPACE_ARTS3,
             {"pocket": 34.0, "pocket_min": 40, "halo": 4})):
        sw, sh, spx = read_space(sheet)
        layer = space_layer(spx, sw, sh, bg, **opts)
        for name, box in arts.items():
            erase_navy(layer, spx, sw, SPACE_ERASE.get(name, []))
            print(cut_space(name, box, layer, sw, sh))
    if "--check" in sys.argv:
        check_sheet()
