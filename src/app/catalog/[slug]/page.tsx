import Link from "next/link";
import { notFound } from "next/navigation";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

type Product = {
  id: string;
  slug: string;
  name: string;
  summary: string;
  description: string;
  product_type: string;
  price_minor: number;
  currency: string;
  license_type: string;
  release_version: string;
  compatibility: Record<string, unknown>;
  tech_stack: string[];
  docs_url: string | null;
  demo_url: string | null;
};

function formatPrice(amountMinor: number, currency: string) {
  try {
    return new Intl.NumberFormat("en", { style: "currency", currency }).format(amountMinor / 100);
  } catch {
    return `${currency} ${(amountMinor / 100).toFixed(2)}`;
  }
}

export default async function ProductDetailPage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  let product: Product | null = null;
  try {
    const supabase = await createSupabaseServerClient();
    const { data, error } = await supabase
      .from("products")
      .select("id,slug,name,summary,description,product_type,price_minor,currency,license_type,release_version,compatibility,tech_stack,docs_url,demo_url")
      .eq("slug", slug)
      .eq("status", "published")
      .eq("rights_status", "verified")
      .not("artifact_sha256", "is", null)
      .maybeSingle();
    if (!error && data) product = data as Product;
  } catch {
    product = null;
  }
  if (!product) notFound();

  return (
    <main className="page-shell catalog-shell">
      <header className="site-header">
        <Link className="wordmark" href="/" aria-label="Web-Temify home">Web-Temify<span className="wordmark-dot" aria-hidden="true">.</span></Link>
        <Link className="button button-secondary" href="/catalog">Back to catalogue</Link>
      </header>
      <article className="product-detail">
        <p className="eyebrow">{product.product_type.replaceAll("_", " ")} · Verified release</p>
        <h1>{product.name}</h1>
        <p className="hero-copy">{product.summary}</p>
        <p className="product-price">{formatPrice(product.price_minor, product.currency)}</p>
        <p className="notice" role="status">Purchasing is not enabled in this phase. This page displays verified release metadata only.</p>
        <section aria-labelledby="description-title">
          <h2 id="description-title">About this product</h2>
          <p>{product.description}</p>
        </section>
        <dl className="product-facts">
          <div><dt>Release version</dt><dd>{product.release_version}</dd></div>
          <div><dt>License</dt><dd>{product.license_type.replaceAll("_", " ")}</dd></div>
          <div><dt>Compatibility</dt><dd>{Object.keys(product.compatibility).length ? JSON.stringify(product.compatibility) : "Not specified"}</dd></div>
          <div><dt>Technology stack</dt><dd>{product.tech_stack.length ? product.tech_stack.join(", ") : "Not specified"}</dd></div>
        </dl>
        <div className="hero-actions">
          {product.docs_url && <a className="button button-secondary" href={product.docs_url} rel="noreferrer">Documentation ↗</a>}
          {product.demo_url && <a className="button button-secondary" href={product.demo_url} rel="noreferrer">Live demo ↗</a>}
        </div>
      </article>
      <footer className="site-footer"><span>© {new Date().getFullYear()} Web-Temify LTD.</span><span>Published only with evidence.</span></footer>
    </main>
  );
}
