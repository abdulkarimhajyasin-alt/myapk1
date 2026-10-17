import type { MetadataRoute } from "next";
export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "مسكن — المصاريف المشتركة",
    short_name: "مسكن",
    description: "إدارة مصاريف السكن المشتركة",
    start_url: "/",
    display: "standalone",
    background_color: "#f5f7f8",
    theme_color: "#0c7161",
    lang: "ar",
    dir: "rtl",
    icons: [
      {
        src: "/icon-192.png",
        sizes: "192x192",
        type: "image/png",
        purpose: "any",
      },
      {
        src: "/icon-512.png",
        sizes: "512x512",
        type: "image/png",
        purpose: "maskable",
      },
    ],
  };
}
