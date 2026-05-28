import type { Metadata } from "next";
import "./globals.css";

// metadataBase makes per-page `alternates.canonical: '/path'` resolve to absolute
// https://pawdoc.app/path URLs (used by the blog articles).
export const metadata: Metadata = {
  metadataBase: new URL("https://pawdoc.app"),
  title: {
    default: "PawDoc — Know When to Call the Vet",
    template: "%s · PawDoc",
  },
  description:
    "AI-assisted pet health triage in seconds. Add a photo or describe the symptom and get clear guidance — emergency, monitor, or likely normal. Not a substitute for a vet.",
  applicationName: "PawDoc",
  openGraph: {
    title: "PawDoc — Know When to Call the Vet",
    description: "AI-assisted pet health triage in seconds.",
    url: "https://pawdoc.app",
    siteName: "PawDoc",
    type: "website",
  },
  twitter: { card: "summary_large_image" },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
