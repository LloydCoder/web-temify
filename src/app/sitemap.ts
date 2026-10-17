import type { MetadataRoute } from "next";

const publicRoutes = [
  "/",
  "/catalog",
  "/hosting",
  "/ai-site-builder",
  "/directory",
  "/automations",
  "/specialists",
  "/implementation",
  "/platform",
  "/tech-hub",
] as const;

export default function sitemap(): MetadataRoute.Sitemap {
  const baseUrl = (
    process.env.NEXT_PUBLIC_SITE_URL ?? "https://web-temify.vercel.app"
  ).replace(/\/$/, "");
  const lastModified = new Date();

  return publicRoutes.map((route) => ({
    url: `${baseUrl}${route}`,
    lastModified,
    changeFrequency: route === "/" ? "weekly" : "monthly",
    priority: route === "/" ? 1 : route === "/catalog" ? 0.9 : 0.65,
  }));
}
