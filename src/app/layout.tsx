import type { Metadata } from "next";
import "./globals.css";
export const metadata: Metadata = {
  title: "Web-Temify — Build with a better starting point",
  description:
    "A growing home for practical templates, scripts, launch kits, and tools.",
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
