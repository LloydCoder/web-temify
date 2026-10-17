import type { MetadataRoute } from "next";

export default function robots(): MetadataRoute.Robots {
  const baseUrl = (
    process.env.NEXT_PUBLIC_SITE_URL ?? "https://web-temify.vercel.app"
  ).replace(/\/$/, "");

  return {
    rules: {
      userAgent: "*",
      allow: "/",
      disallow: [
        "/admin/",
        "/account/",
        "/checkout/",
        "/api/",
        "/internal/",
        "/creator/",
      ],
    },
    sitemap: `${baseUrl}/sitemap.xml`,
  };
}
