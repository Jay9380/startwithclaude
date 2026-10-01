#!/bin/bash
# 3장: 클로드 코드가 만든 링크나무 클릭 API를 실제 MongoDB(인메모리)에 붙여 검증한다. 과금 없음.
#  1) 동시 클릭 200개(50개 병렬) → count가 정확히 200인가 (원자적 증가인가)
#  2) 없는 링크 ID → 404인가
#  3) MONGODB_URI에 DB 이름을 빼면 어디에 쌓이나 (책 3.5.4 NOTE: 'test' DB 사고)
# 사용: ./click_test.sh      (처음엔 npm install·build로 2~3분)
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd); APP=$HERE/../linknamu; WORK=$(mktemp -d)
# npx는 next-server를 자식으로 띄우므로 npx의 PID만 죽이면 서버가 남는다 → 내가 쓴 포트의 리스너만 정리한다
stop_port() { for p in $(lsof -nP -iTCP:"$1" -sTCP:LISTEN -t 2>/dev/null); do kill "$p" 2>/dev/null; done; }
cleanup() { stop_port 3917; stop_port 3918; [ -n "${MPID:-}" ] && kill "$MPID" 2>/dev/null; rm -f "$APP/.env.local"; true; }
trap cleanup EXIT
(cd "$WORK" && npm init -y >/dev/null && npm i -s mongodb-memory-server@10 mongodb@6 >/dev/null 2>&1)
cat > "$WORK/m.mjs" <<'JS'
import { MongoMemoryServer } from "mongodb-memory-server";
const m = await MongoMemoryServer.create(); console.log(m.getUri()); setInterval(() => {}, 1 << 30);
JS
(cd "$WORK" && node m.mjs > uri 2>/dev/null) & MPID=$!
for i in $(seq 1 60); do [ -s "$WORK/uri" ] && break; sleep 2; done; URI=$(cat "$WORK/uri")
peek() { (cd "$WORK" && node -e "const {MongoClient}=require('mongodb');(async()=>{const c=await new MongoClient('$URI').connect();
for (const n of ['linknamu','test']) console.log('  '+n+'.clicks', JSON.stringify(await c.db(n).collection('clicks').find().toArray()));await c.close()})()"); }
serve() {  # serve <MONGODB_URI> <port>
  printf 'MONGODB_URI=%s\n' "$1" > "$APP/.env.local"
  (cd "$APP" && npx next start -p "$2" > "$WORK/next.log" 2>&1) & NPID=$!
  for i in $(seq 1 40); do curl -s -o /dev/null "http://localhost:$2/api/clicks" && return; sleep 1; done; echo "서버 기동 실패"; exit 1
}
cd "$APP"; [ -d node_modules ] || npm ci -s >/dev/null 2>&1; npm run build >/dev/null 2>&1
echo "== 1·2) URI에 DB 이름 포함: ${URI}linknamu"
serve "${URI}linknamu" 3917
seq 1 200 | xargs -P 50 -I{} curl -s -o /dev/null -X POST http://localhost:3917/api/clicks/github
echo "  GET /api/clicks → $(curl -s http://localhost:3917/api/clicks)"
echo "  POST /api/clicks/evil → $(curl -s -o /dev/null -w '%{http_code}' -X POST http://localhost:3917/api/clicks/evil)"
stop_port 3917; sleep 1
echo "== 3) URI에 DB 이름 없음: $URI"
serve "$URI" 3918
seq 1 5 | xargs -P 5 -I{} curl -s -o /dev/null -X POST http://localhost:3918/api/clicks/blog
echo "  GET /api/clicks → $(curl -s http://localhost:3918/api/clicks)"
peek
