type LinkCardProps = {
  title: string;
  url: string;
  count: number;
  onClick?: () => void;
};

export default function LinkCard({ title, url, count, onClick }: LinkCardProps) {
  const isExternal = url.startsWith("http");

  return (
    <a
      href={url}
      onClick={onClick}
      {...(isExternal && { target: "_blank", rel: "noopener noreferrer" })}
      className="relative block w-full rounded-lg border border-zinc-200 bg-white px-5 py-4 text-center font-medium text-zinc-900 transition-colors hover:bg-zinc-100 dark:border-zinc-800 dark:bg-zinc-900 dark:text-zinc-50 dark:hover:bg-zinc-800"
    >
      {title}
      <span className="absolute right-5 top-1/2 -translate-y-1/2 text-xs font-normal text-zinc-500 dark:text-zinc-400">
        {count}회
      </span>
    </a>
  );
}
