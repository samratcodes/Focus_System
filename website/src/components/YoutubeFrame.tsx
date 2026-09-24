"use client";

import { youtubeId } from "@/lib/shared/logic";

export function youtubeSrc(url: string, autoplay: boolean) {
  const id = youtubeId(url);
  if (!id) return "";
  return `https://www.youtube.com/embed/${id}?rel=0&playsinline=1&autoplay=${autoplay ? 1 : 0}&loop=1&playlist=${id}`;
}

export default function YoutubeFrame({ url, autoplay }: { url: string; autoplay: boolean }) {
  const src = youtubeSrc(url, autoplay);
  if (!src) return <div className="music-empty">Save a YouTube link to use background music.</div>;
  return (
    <iframe
      key={src}
      title="Focus background music"
      src={src}
      allow="autoplay; encrypted-media"
      allowFullScreen
    />
  );
}
