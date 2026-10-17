import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Web-Temify — Marketplace Preview",
  description:
    "Explore the Web-Temify marketplace preview. Verified product releases will appear after publication and rights review; purchases and checkout are not live yet.",
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
