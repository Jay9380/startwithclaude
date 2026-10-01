import { MongoClient } from "mongodb";

const globalForMongo = globalThis as unknown as {
  mongoClientPromise?: Promise<MongoClient>;
};

export function getClient(): Promise<MongoClient> {
  const uri = process.env.MONGODB_URI;
  if (!uri) {
    throw new Error("MONGODB_URI 환경 변수가 설정되지 않았습니다.");
  }
  // 개발 모드 핫 리로드 때 연결이 중복 생성되지 않도록 전역에 보관
  globalForMongo.mongoClientPromise ??= new MongoClient(uri).connect();
  return globalForMongo.mongoClientPromise;
}

export async function getClicksCollection() {
  const client = await getClient();
  return client.db().collection<{ _id: string; count: number }>("clicks");
}
