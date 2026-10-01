import { links } from "@/lib/links";
import { getClicksCollection } from "@/lib/mongodb";

// 모든 링크의 클릭 수를 { [id]: count } 형태로 반환
export async function GET() {
  try {
    const collection = await getClicksCollection();
    const docs = await collection.find().toArray();
    const stored = new Map(docs.map((doc) => [doc._id, doc.count]));
    const counts = Object.fromEntries(
      links.map((link) => [link.id, stored.get(link.id) ?? 0]),
    );
    return Response.json(counts);
  } catch (error) {
    console.error(error);
    return Response.json({ error: "클릭 수를 불러오지 못했습니다." }, { status: 500 });
  }
}
