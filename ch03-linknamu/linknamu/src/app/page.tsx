import LinkList from "@/components/LinkList";
import Profile from "@/components/Profile";
import { links } from "@/lib/links";

const profile = {
  name: "김개발",
  bio: "풀스택 개발자 | 요즘에는 AI 개발에 관심이 많아요",
  imageUrl: "https://placehold.co/150x150/orange/white",
};

export default function Home() {
  return (
    <main className="mx-auto flex w-full max-w-xl flex-1 flex-col gap-8 px-4 py-12 sm:py-16">
      <Profile {...profile} />
      <LinkList links={links} />
    </main>
  );
}
