import Link from "next/link";

export default function ProductNotFound() {
  return (
    <main className="page-shell catalog-shell">
      <header className="site-header">
        <Link className="wordmark" href="/" aria-label="Web-Temify home">
          Web-Temify
          <span className="wordmark-dot" aria-hidden="true">
            .
          </span>
        </Link>
      </header>
      <section className="product-detail" aria-labelledby="not-found-title">
        <p className="eyebrow">Verified releases only</p>
        <h1 id="not-found-title">Product not found</h1>
        <p className="hero-copy">
          This product is not available as a verified release.
        </p>
        <div className="hero-actions">
          <Link className="button button-primary" href="/catalog">
            Return to catalogue
          </Link>
        </div>
      </section>
      <footer className="site-footer">
        <span>© {new Date().getFullYear()} Web-Temify LTD.</span>
        <span>Published only with evidence.</span>
      </footer>
    </main>
  );
}
