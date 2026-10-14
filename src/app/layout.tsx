import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Web-Temify — From Idea to Deployable Web Product in Hours",
  description:
    "Discover website templates, launch kits, digital products, and tools for turning ideas into deployable web products.",
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
