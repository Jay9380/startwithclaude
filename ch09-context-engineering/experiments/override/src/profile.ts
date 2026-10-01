import type { User } from "./api-types";

// 서버는 이제 nickname을 함께 내려준다 (openapi.yaml 반영 전).
export function displayName(u: User): string {
  return u.nickname ?? u.name;
}
