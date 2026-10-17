import type { MetadataRoute } from "next";
import { createSupabaseServerClient } from "@/lib/supabase/server";

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

export const dynamic = "force-dynamic";

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const baseUrl = (
    process.env.NEXT_PUBLIC_SITE_URL ?? "https://web-temify.vercel.app"
  ).replace(/\/$/, "");
  const lastModified = new Date();
  const routes: MetadataRoute.Sitemap = publicRoutes.map((route) => ({
    url: `${baseUrl}${route}`,
    lastModified,
    changeFrequency: route === "/" ? "weekly" : "monthly",
    priority: route === "/" ? 1 : route === "/catalog" ? 0.9 : 0.65,
  }));

  // Include only publicly published listings. If the catalogue backend is
  // unavailable, the stable public routes still produce a valid sitemap.
  try {
    const supabase = await createSupabaseServerClient();
    const { data, error } = await supabase
      .from("products")
      .select("slug,updated_at")
      .eq("status", "published")
      .order("updated_at", { ascending: false })
      .limit(1000);

    if (!error && data) {
      for (const product of data) {
        if (!/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(product.slug)) continue;
        routes.push({
          url: `${baseUrl}/catalog/${encodeURIComponent(product.slug)}`,
          lastModified: product.updated_at
            ? new Date(product.updated_at)
            : lastModified,
          changeFrequency: "monthly",
          priority: 0.7,
        });
      }
    }
  } catch {
    // Keep the public route sitemap available when Supabase is not configured.
  }

  return routes;
}
