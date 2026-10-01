type ProfileProps = {
  name: string;
  bio: string;
  imageUrl: string;
};

export default function Profile({ name, bio, imageUrl }: ProfileProps) {
  return (
    <header className="flex flex-col items-center gap-3 text-center">
      {/* placehold.co는 SVG를 반환하므로 next/image 대신 img 사용 */}
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img
        src={imageUrl}
        alt={`${name} 프로필 사진`}
        width={150}
        height={150}
        className="h-28 w-28 rounded-full object-cover sm:h-36 sm:w-36"
      />
      <h1 className="text-2xl font-bold text-zinc-900 dark:text-zinc-50">
        {name}
      </h1>
      <p className="text-sm text-zinc-600 dark:text-zinc-400">{bio}</p>
    </header>
  );
}
