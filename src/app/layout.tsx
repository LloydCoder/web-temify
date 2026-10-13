import type { Metadata, Viewport } from "next";
import type { ReactNode } from "react";
import "./globals.css";
export const metadata: Metadata = { title: { default: "Web-Temify — From idea to deployable web product", template: "%s | Web-Temify" }, description: "Discover digital products, templates, scripts, and launch kits for builders.", applicationName: "Web-Temify", metadataBase: new URL(process.env.NEXT_PUBLIC_SITE_URL ?? "http://localhost:3000") };
export const viewport: Viewport = { width: "device-width", initialScale: 1, themeColor: "#fffbf4" };
export default function RootLayout({ children }: Readonly<{ children: ReactNode }>) { return <html lang="en" suppressHydrationWarning><body>{children}</body></html>; }
