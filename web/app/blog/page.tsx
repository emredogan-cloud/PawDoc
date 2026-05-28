import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = {
  title: "Blog",
  description: "Practical, vet-reviewed guidance for common pet-health questions.",
  alternates: { canonical: "/blog" },
};

// ONE article ships to prove the MDX + SEO infra (Phase 4.3 strict rule).
// Add more by creating app/blog/<slug>/page.mdx and a row here.
const posts = [
  {
    slug: "when-to-take-your-dog-to-the-vet-for-vomiting",
    title: "When to Take Your Dog to the Vet for Vomiting",
    description: "How to tell normal tummy upset from a real emergency — and when to call the vet.",
    date: "2026-05-28",
  },
];

export default function BlogIndex() {
  return (
    <article>
      <h1>PawDoc Blog</h1>
      <p className="note">Information &amp; guidance — not a veterinary diagnosis.</p>
      <ul>
        {posts.map((p) => (
          <li key={p.slug} style={{ marginBottom: 16 }}>
            <Link href={`/blog/${p.slug}/`}>{p.title}</Link>
            <div className="note">
              {p.date} — {p.description}
            </div>
          </li>
        ))}
      </ul>
    </article>
  );
}
