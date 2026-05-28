import type { Metadata } from "next";
import SymptomChecker from "./symptom-checker";

// Server component => can export SEO metadata. The interactive form is a child
// Client Component (symptom-checker.tsx), so the page still statically exports
// (the shell prerenders; the fetch runs in the browser — no API route needed).
export const metadata: Metadata = {
  title: "Free Pet Symptom Checker",
  description:
    "Describe your pet's symptoms and get instant AI triage — emergency, monitor, or likely normal. Free, no account. Not a substitute for a vet.",
  alternates: { canonical: "/check" },
};

export default function CheckPage() {
  return (
    <main className="container" style={{ paddingTop: 32, paddingBottom: 48 }}>
      <h1>Free Pet Symptom Checker</h1>
      <p className="note">
        Describe what you&rsquo;re seeing and get instant AI triage. Information &amp; guidance — not a
        veterinary diagnosis. In an emergency, contact a vet immediately.
      </p>
      <SymptomChecker />
    </main>
  );
}
