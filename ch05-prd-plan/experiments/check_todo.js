// 생성된 할 일 앱(index.html 한 파일)을 jsdom으로 열어 요구사항 5가지를 기능 테스트한다.
// 사용: node check_todo.js <index.html>   → JSON 한 줄 출력
// 앱마다 마크업이 달라서 '사람이 찾는 방식'으로 찾는다: 첫 텍스트 입력칸, '추가/Add' 버튼 또는 Enter,
// 항목 안의 체크박스(없으면 항목 클릭), '삭제/Delete/×' 버튼.
const { JSDOM } = require("jsdom");
const fs = require("fs");
const html = fs.readFileSync(process.argv[2], "utf8");
const result = { add: false, toggle: false, delete: false, completedToBottom: false, persist: false, viewport: false, error: null };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function boot(storage) {
  // 스크립트는 생성자 안에서 바로 돈다 → 저장소는 beforeParse에서 먼저 채워야 '새로고침'이 된다
  return new JSDOM(html, { runScripts: "dangerously", pretendToBeVisual: true, url: "http://localhost/",
    beforeParse(win) { if (storage) for (const [k, v] of Object.entries(storage)) win.localStorage.setItem(k, v); } });
}
function input(doc) {
  return [...doc.querySelectorAll("input")].find((i) => !i.type || ["text", "search", ""].includes(i.type));
}
function addItem(win, text) {
  const doc = win.document, el = input(doc);
  if (!el) throw new Error("입력칸 없음");
  el.value = text;
  el.dispatchEvent(new win.Event("input", { bubbles: true }));
  const btn = [...doc.querySelectorAll("button, input[type=submit]")].find((b) => /추가|add|\+|등록/i.test(b.textContent + (b.value || "")));
  if (el.form) el.form.dispatchEvent(new win.Event("submit", { bubbles: true, cancelable: true }));
  else if (btn) btn.click();
  else for (const t of ["keydown", "keypress", "keyup"]) el.dispatchEvent(new win.KeyboardEvent(t, { key: "Enter", code: "Enter", keyCode: 13, which: 13, bubbles: true }));
}
function itemNode(doc, text) {
  // 클래스 이름은 앱마다 다르다(li, .task-item, .todo …) → '그 텍스트를 담고, 체크박스나 버튼을 품은 가장 작은 요소'
  const nodes = [...doc.body.querySelectorAll("*")].filter((n) => n.textContent.includes(text)
    && n.querySelector("input[type=checkbox], button, [role=button]"));
  return nodes.sort((a, b) => a.textContent.length - b.textContent.length)[0];
}
function order(doc, a, b) {
  const t = doc.body.textContent; return t.indexOf(a) < t.indexOf(b);
}

(async () => {
  try {
    let dom = boot(); await sleep(150);
    const doc = () => dom.window.document;
    result.viewport = !!doc().querySelector('meta[name="viewport"]');
    addItem(dom.window, "우유 사기"); await sleep(50);
    addItem(dom.window, "운동 하기"); await sleep(50);
    result.add = doc().body.textContent.includes("우유 사기") && doc().body.textContent.includes("운동 하기");
    // 완료 체크: 첫 항목
    const first = itemNode(doc(), "우유 사기");
    if (first) {
      const cb = first.querySelector("input[type=checkbox]");
      const before = first.outerHTML;
      if (cb) cb.click(); else (first.querySelector("span, label") || first).click();
      await sleep(50);
      const after = itemNode(doc(), "우유 사기");
      result.toggle = !!after && (after.outerHTML !== before || (after.querySelector("input[type=checkbox]") || {}).checked === true);
      result.completedToBottom = result.toggle && order(doc(), "운동 하기", "우유 사기");
    }
    // 새로고침 후 유지: localStorage를 넘겨 다시 부팅
    const saved = {}; const ls = dom.window.localStorage;
    for (let i = 0; i < ls.length; i++) saved[ls.key(i)] = ls.getItem(ls.key(i));
    const dom2 = boot(saved); await sleep(150);
    result.persist = dom2.window.document.body.textContent.includes("운동 하기");
    // 삭제: '운동 하기'
    const target = itemNode(doc(), "운동 하기");
    const del = target && [...target.querySelectorAll("button, [role=button], .delete, .remove")].find((b) => /삭제|delete|remove|×|✕|✖|x|🗑/i.test(b.textContent + b.className + (b.getAttribute("aria-label") || "")));
    if (del) { del.click(); await sleep(50); result.delete = !doc().body.textContent.includes("운동 하기"); }
  } catch (e) { result.error = String(e.message || e); }
  console.log(JSON.stringify(result));
  process.exit(0);
})();
