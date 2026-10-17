import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  metadataBase: new URL(
    process.env.NEXT_PUBLIC_SITE_URL ?? "https://web-temify.vercel.app",
  ),
  title: {
    default: "Web-Temify — Templates, Tools & the Web Product Ecosystem",
    template: "%s | Web-Temify",
  },
  description:
    "Explore verified digital-product releases and the Web-Temify ecosystem roadmap for hosting, AI site building, automation, specialist suppliers, and implementation services. Planned capabilities are clearly identified.",
  openGraph: {
    type: "website",
    siteName: "Web-Temify",
    title: "Web-Temify — Templates, Tools & the Web Product Ecosystem",
    description:
      "Explore verified digital-product releases and the Web-Temify ecosystem roadmap. Planned capabilities are clearly identified.",
  },
  twitter: { card: "summary" },
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
