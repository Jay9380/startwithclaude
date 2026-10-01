#!/usr/bin/env python3
"""책 9.2.2의 '잡음 많은 서버 로그'를 결정적으로 만든다 (책의 server.js를 5분 돌린 결과와 같은 모양).

- heartbeat 1초, cache stats 2.5초, slow query 7초 (잡음)
- 4초마다 결제 게이트웨이 재시도, 30% 확률로 PaymentGatewayTimeout (+ 스택 3줄)
- 책에는 없는 것 하나: 40초쯤 단 한 번 나는 다른 에러(DatabaseConnectionReset).
  '가공하면 무엇을 잃나'를 재기 위한 바늘이다.
사용: python3 gen_log.py > app.log
"""
import random
from datetime import datetime, timedelta

random.seed(9)
t0 = datetime(2026, 5, 18, 23, 16, 30)
events = []
for s in range(0, 300):
    events.append((s, "INFO", 'heartbeat {"uptime":%d.0}' % s))
for k in range(0, 120):
    events.append((k * 2.5, "INFO", 'cache stats {"hits":1240,"misses":87}'))
for k in range(1, 43):
    events.append((k * 7, "WARN", 'slow query detected {"ms":1200,"table":"orders"}'))
for k in range(1, 75):
    if random.random() < 0.3:
        events.append((k * 4, "ERROR", "background payment retry failed\nError: PaymentGatewayTimeout: upstream did not respond in 5000ms\n"
                       "    at fetchPaymentGateway (server.js:14:31)\n    at Timeout._onTimeout (server.js:31:11)"))
events.append((40.5, "ERROR", "order sync failed\nError: DatabaseConnectionReset: connection to orders-db reset by peer\n"
               "    at syncOrders (sync.js:88:9)"))
for s, lvl, msg in sorted(events, key=lambda e: e[0]):
    ts = (t0 + timedelta(seconds=s)).isoformat(timespec="milliseconds") + "Z"
    print(f"{ts} [{lvl}] {msg}")
