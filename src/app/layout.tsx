import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: {
    default: "Web-Temify — Templates, Tools & the Web Product Ecosystem",
    template: "%s | Web-Temify",
  },
  description:
    "Explore verified digital-product releases and the Web-Temify ecosystem roadmap for hosting, AI site building, automation, specialist suppliers, and implementation services. Planned capabilities are clearly identified.",
  icons: {
    icon: "/icon.svg",
  },
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
