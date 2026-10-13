import Link from "next/link";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

type Product = {
  id: string;
  slug: string;
  name: string;
  summary: string;
  product_type: string;
  price_minor: number;
  currency: string;
  license_type: string;
  tags: string[];
};

function formatPrice(amountMinor: number, currency: string) {
  try {
    return new Intl.NumberFormat("en", { style: "currency", currency }).format(amountMinor / 100);
  } catch {
    return `${currency} ${(amountMinor / 100).toFixed(2)}`;
  }
}

async function loadProducts(query: string): Promise<{ products: Product[]; configured: boolean }> {
  try {
    const supabase = await createSupabaseServerClient();
    let request = supabase
      .from("products")
      .select("id,slug,name,summary,product_type,price_minor,currency,license_type,tags")
      .eq("status", "published")
      .order("name", { ascending: true })
      .limit(48);

    if (query) request = request.textSearch("search_document", query, { type: "websearch", config: "english" });
    const { data, error } = await request;
    if (error) return { products: [], configured: true };
    return { products: (data ?? []) as Product[], configured: true };
  } catch {
    return { products: [], configured: false };
  }
}

export default async function CataloguePage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string }>;
}) {
  const params = await searchParams;
  const query = (params.q ?? "").trim().slice(0, 80);
  const { products, configured } = await loadProducts(query);

  return (
    <main className="page-shell catalog-shell">
      <header className="site-header">
        <Link className="wordmark" href="/" aria-label="Web-Temify home">
          Web-Temify<span className="wordmark-dot" aria-hidden="true">.</span>
        </Link>
        <Link className="button button-secondary" href="/">Home</Link>
      </header>
      <section className="catalog-heading" aria-labelledby="catalog-title">
        <p className="eyebrow">Verified releases only</p>
        <h1 id="catalog-title">Product catalogue</h1>
        <p className="hero-copy">
          Explore products only after their publication, rights review, and release artifact evidence are verified.
        </p>
        <form className="catalog-search" action="/catalog" method="get" role="search">
          <label htmlFor="catalog-query">Search product names</label>
          <div className="catalog-search-row">
            <input id="catalog-query" name="q" type="search" maxLength={80} defaultValue={query} placeholder="Search templates, scripts, kits…" />
            <button className="button button-primary" type="submit">Search</button>
          </div>
        </form>
      </section>
      {!configured ? (
        <p className="notice" role="status">The live catalogue is not configured yet. No products are offered for sale from this preview.</p>
      ) : products.length === 0 ? (
        <p className="notice" role="status">{query ? "No verified products matched this search." : "No verified product releases are published yet."}</p>
      ) : (
        <section className="catalog-grid" aria-label="Verified products">
          {products.map((product) => (
            <article className="catalog-card" key={product.id}>
              <p className="eyebrow">{product.product_type.replaceAll("_", " ")}</p>
              <h2><Link href={`/catalog/${encodeURIComponent(product.slug)}`}>{product.name}</Link></h2>
              <p>{product.summary || "Verified product release."}</p>
              <p className="catalog-meta">{product.license_type.replaceAll("_", " ")} license · {formatPrice(product.price_minor, product.currency)}</p>
              {product.tags.length > 0 && <ul className="catalog-tags">{product.tags.slice(0, 5).map((tag) => <li key={tag}>{tag}</li>)}</ul>}
            </article>
          ))}
        </section>
      )}
      <footer className="site-footer">
        <span>© {new Date().getFullYear()} Web-Temify LTD.</span>
        <span>Published only with evidence.</span>
      </footer>
    </main>
  );
}
