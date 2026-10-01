"""책 6.3 리뷰 항목을 테스트로 고정한다. 실행: python3 -m unittest -v md2short_mini.test_caption"""
import unittest

from md2short_mini import caption, naive, numbers

SAMPLE = [  # 책 sample.md의 문장들
    "지난 금요일 미국 증시, 강하게 상승 마감했습니다.",
    "4월 기준으로는 1950년 이후 두 번째로 좋은 성과입니다.",
    "S&P 500 종가 7,230 기록했습니다.",
    "나스닥은 0.94% 상승했습니다.",
    "애플, 호실적으로 3.2% 상승했습니다.",
    "로블록스, 18% 급락했습니다.",
    "오라클이 미 국방부 AI 네트워크 프로젝트에 공식 합류했습니다.",
]


def words_intact(lines: list[str], sentence: str) -> bool:
    """줄들을 이어 붙였을 때 원문의 어절이 하나도 쪼개지지 않았는가."""
    return " ".join(lines).split() == sentence.split()


class NumberReading(unittest.TestCase):
    def test_book_examples(self):  # 책 6.3.4 리뷰의 표
        self.assertEqual(numbers.read_number("7,230"), "칠천이백삼십")
        self.assertEqual(numbers.to_phonetic("0.94%"), "영점구사 퍼센트")
        self.assertEqual(numbers.to_phonetic("3.2%"), "삼점이 퍼센트")
        self.assertEqual(numbers.to_phonetic("18%"), "십팔 퍼센트")
        self.assertEqual(numbers.to_phonetic("1950년"), "천구백오십년")

    def test_out_of_range_is_left_alone(self):  # 실패 경로: 모르는 것은 추측하지 않는다
        self.assertEqual(numbers.to_phonetic("12345678원"), "12345678원")


class Captions(unittest.TestCase):
    def test_no_word_is_split(self):  # C3
        for s in SAMPLE:
            with self.subTest(s=s):
                self.assertTrue(words_intact(caption.wrap_korean_caption(s), s))

    def test_line_length(self):  # C3: 14자 이내 (14자 넘는 단일 어절은 예외)
        for s in SAMPLE:
            for line in caption.wrap_korean_caption(s):
                self.assertTrue(len(line) <= 14 or " " not in line, line)

    def test_screen_has_at_most_two_lines(self):
        for s in SAMPLE:
            for screen in caption.make_screens(s):
                self.assertLessEqual(len(screen), 2)

    def test_numbers_stay_in_caption_and_become_words_in_speech(self):  # H1
        display, speech = caption.split_display_and_speech("나스닥은 0.94% 상승했습니다.")
        self.assertIn("0.94%", display)
        self.assertIn("영점구사 퍼센트", speech)
        self.assertNotIn("0.94", speech)


class NaiveVersionReproducesTheBug(unittest.TestCase):
    """실패 경로: 처음 버전이 정말 리뷰가 지적한 결함을 갖는지 — 테스트가 결함을 '잡을 수 있음'을 증명"""

    def test_naive_splits_words(self):
        # 주의: 처음엔 '오라클이 미 국방부 AI …' 문장으로 썼는데, 우연히 14자마다 공백에서 끊겨 결함을 못 잡았다.
        # 숫자 하나가 두 줄로 갈리는 문장으로 바꿨다 → ['S&P 오백 종가 칠천이백', '삼십 기록했습니다.']
        s = "S&P 500 종가 7,230 기록했습니다."
        self.assertFalse(words_intact(naive.make_caption_lines(s), numbers.to_phonetic(s)))

    def test_naive_loses_numbers(self):
        lines = naive.make_caption_lines("나스닥은 0.94% 상승했습니다.")
        self.assertNotIn("0.94%", "".join(lines))


if __name__ == "__main__":
    unittest.main()
