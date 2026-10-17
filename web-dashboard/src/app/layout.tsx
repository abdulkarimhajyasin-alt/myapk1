import type { Metadata, Viewport } from "next";
import "./globals.css";
export const metadata: Metadata = {
  title: "مسكن | مصاريف مشتركة، حياة أبسط",
  description: "مساحتك لإدارة مصاريف السكن المشتركة والتسويات مع مجموعتك.",
  manifest: "/manifest.webmanifest",
  appleWebApp: { capable: true, title: "مسكن", statusBarStyle: "default" },
  icons: { icon: "/icon.svg", apple: "/apple-icon.png" },
};
export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
  themeColor: "#0c7161",
};
export default function Layout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ar" dir="rtl">
      <body>{children}</body>
    </html>
  );
}
