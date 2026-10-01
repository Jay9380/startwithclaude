// 책 2.5.1의 디자인 브리프 항목이 생성된 index.html에 반영됐는지 점검한다. 사용: node check_brief.js <index.html>
// 정적 검사(소스 문자열) + jsdom DOM 검사. 결과는 JSON 한 줄.
const { JSDOM } = require("jsdom");
const fs = require("fs");
const html = fs.readFileSync(process.argv[2], "utf8");
const low = html.toLowerCase();
const dom = new JSDOM(html);
const doc = dom.window.document;
const text = doc.body ? doc.body.textContent.replace(/\s+/g, " ") : "";
const idx = (s) => text.indexOf(s);
const has = (re) => re.test(html);
const extCss = [...doc.querySelectorAll('link[rel="stylesheet"]')].map((l) => l.href);
const r = {
  "단일 파일(외부 CSS는 폰트만)": extCss.every((h) => /font|pretendard/i.test(h)),
  "배경 그라데이션 #F8FAFC→#E0F2FE": /gradient[^;]*#f8fafc[^;]*#e0f2fe/.test(low),
  "강조색 #0EA5E9": low.includes("#0ea5e9"),
  "본문 글자색 #1E293B": low.includes("#1e293b"),
  "순서 이니셜→이름→소개→태그→링크": idx("홍길동") >= 0 && idx("홍길동") < idx("코드와 커피") && idx("코드와 커피") < idx("독서") && idx("독서") < idx("GitHub"),
  "관심 태그 4개": ["독서", "여행", "사진", "커피"].every((t) => text.includes(t)),
  "리스트 마커 없음": !doc.querySelector("li") || /list-style(-type)?\s*:\s*none/.test(low),
  "GitHub·LinkedIn 링크": !!doc.querySelector('a[href*="github.com/claudecode-gilbut"]') && !!doc.querySelector('a[href*="linkedin.com/in/claudecode-gilbut"]'),
  "글래스모피즘(backdrop-filter blur)": /backdrop-filter\s*:\s*blur/.test(low),
  "카드 호버 떠오름(translateY)": /:hover[^}]*translatey\(-/.test(low.replace(/\n/g, " ")),
  "모바일 480px 반응형": /@media[^{]*max-width\s*:\s*480px/.test(low),
  "Pretendard 로드": /pretendard/.test(low) && doc.querySelectorAll('link[href*="retendard"], style').length > 0,
};
// 폰트를 어디서 불러오는가 — 브리프는 'Google Fonts CDN'이라 했지만 Google Fonts에는 Pretendard가 없다(400)
const fontLinks = [...doc.querySelectorAll("link[href]")].map((l) => l.href).concat((html.match(/@import\s+url\(([^)]+)\)/g) || []));
const pret = fontLinks.filter((h) => /retendard/.test(h));
const fontSource = pret.length === 0 ? "없음" : pret.some((h) => /fonts\.googleapis\.com/.test(h)) ? "Google Fonts(없는 폰트 — 깨짐)" : pret.some((h) => /jsdelivr|unpkg|cdnjs/.test(h)) ? "jsDelivr 등 실제 CDN" : "기타";
// 2.5.4 후속 수정 항목 (있을 때만 의미)
const extra = {
  "prefers-reduced-motion 처리": /prefers-reduced-motion/.test(low),
  "stagger(태그별 지연)": /transition-delay|animation-delay|nth-child\(\d\)[^}]*delay/.test(low.replace(/\n/g, " ")),
};
console.log(JSON.stringify({ brief: r, fontSource, extra }));
