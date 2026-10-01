"""숫자 → 한국어 읽기(TTS 입력용). 책 6.3.4 리뷰의 표기를 따른다.

  7,230 → 칠천이백삼십   0.94% → 영점구사 퍼센트   3.2% → 삼점이 퍼센트   18% → 십팔 퍼센트
  1950년 → 천구백오십년   5주 → 오주
범위: 0 ~ 9,999,999 정수, 소수는 한 자리씩 읽는다. 그 밖은 원문 그대로 둔다(추측해서 바꾸지 않는다).
"""
import re

DIGITS = "영일이삼사오육칠팔구"
UNITS = ["", "십", "백", "천"]


def _int_reading(n: int) -> str:
    if n == 0:
        return "영"
    if n >= 10_000_000:
        raise ValueError("범위 밖")
    man, rest = divmod(n, 10_000)
    out = (_under_10000(man) + "만") if man else ""
    return out + _under_10000(rest)


def _under_10000(n: int) -> str:
    s = ""
    for pos in range(3, -1, -1):
        d = (n // 10 ** pos) % 10
        if d == 0:
            continue
        # 십·백·천 앞의 '일'은 읽지 않는다 (일십 → 십)
        s += ("" if d == 1 and pos > 0 else DIGITS[d]) + UNITS[pos]
    return s


def read_number(token: str) -> str:
    """'7,230' / '0.94' / '18' 같은 숫자 토큰 하나를 읽는다."""
    t = token.replace(",", "")
    if "." in t:
        whole, frac = t.split(".", 1)
        return _int_reading(int(whole)) + "점" + "".join(DIGITS[int(c)] for c in frac)
    return _int_reading(int(t))


NUM = re.compile(r"(?<![\w.])(\d{1,3}(?:,\d{3})+|\d+)(\.\d+)?(%?)")


def to_phonetic(text: str) -> str:
    """문장 안의 숫자만 한국어 읽기로 바꾼다. 퍼센트 기호는 ' 퍼센트'로."""
    def sub(m: re.Match) -> str:
        num = m.group(1) + (m.group(2) or "")
        try:
            spoken = read_number(num)
        except ValueError:
            return m.group(0)
        return spoken + (" 퍼센트" if m.group(3) else "")
    return NUM.sub(sub, text)
