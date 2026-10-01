"""자막 줄바꿈 — 책 6.3 리뷰 C3·H1의 개선 방향을 그대로 구현한 기준 구현.

- 자막은 원문(숫자 표기 그대로), TTS 입력만 한국어 읽기 — '표시 문자열과 발음 문자열의 분리'(H1, 6.3.4 2순위)
- 어절(공백) 경계에서만 줄을 바꾼다. 한 줄 최대 14자, 한 화면 최대 2줄(C3)
- 한 어절이 14자를 넘으면 그 어절만 단독 줄로 둔다(쪼개지 않는다)
"""
from md2short_mini.numbers import to_phonetic

MAX_CHARS = 14
MAX_LINES = 2


def wrap_korean_caption(text: str, max_chars: int = MAX_CHARS) -> list[str]:
    lines, cur = [], ""
    for word in text.split():
        cand = f"{cur} {word}" if cur else word
        if len(cand) <= max_chars or not cur:
            cur = cand
        else:
            lines.append(cur)
            cur = word
    if cur:
        lines.append(cur)
    return lines


def make_screens(sentence: str) -> list[list[str]]:
    """한 문장을 화면 단위(최대 2줄)로 나눈다."""
    lines = wrap_korean_caption(sentence)
    return [lines[i:i + MAX_LINES] for i in range(0, len(lines), MAX_LINES)]


def split_display_and_speech(sentence: str) -> tuple[str, str]:
    """(자막에 쓸 문자열, TTS에 넘길 문자열)."""
    return sentence, to_phonetic(sentence)
