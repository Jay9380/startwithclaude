"""책 6.3 1차 리뷰가 지적한 '처음 버전'의 모양을 재현한 것 (일부러 결함이 있다).

- C3: 자막을 글자 수(14자)로만 잘라서 어절 중간에서 끊긴다.
- H1: TTS가 읽은 그대로(숫자를 한글 음차로 바꾼 문장)를 자막에도 써서 숫자 정보가 사라진다.
"""
from md2short_mini.numbers import to_phonetic


def make_caption_lines(sentence: str, chunk_size: int = 14) -> list[str]:
    tts = to_phonetic(sentence)          # TTS용 문장을 만들고
    return [tts[i:i + chunk_size] for i in range(0, len(tts), chunk_size)]   # 그것을 그대로 글자 수로 자른다
