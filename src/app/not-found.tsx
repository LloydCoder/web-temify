import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = {
  title: "Page not found | Web-Temify",
  description: "The requested Web-Temify page could not be found.",
  robots: { index: false, follow: true },
};

export default function NotFound() {
  return (
    <main className="page-shell" style={{ paddingBlock: "6rem" }}>
      <p className="eyebrow">404 — Not found</p>
      <h1 style={{ fontSize: "clamp(3rem, 8vw, 5rem)" }}>Wrong turn.</h1>
      <p className="hero-copy">
        That page is not available in this foundation build.
      </p>
      <Link className="button button-primary" href="/">
        Back to home ↗
      </Link>
    </main>
  );
}
