import Link from "next/link";

// Placeholder marketing copy + assets (Phase 4.3). Swap the badge hrefs for the
// real store URLs and drop real screenshots into web/public/ (see the note).
const STORE = {
  appStore: "https://apps.apple.com/app/pawdoc", // TODO: real App Store URL at launch
  googlePlay: "https://play.google.com/store/apps/details?id=app.pawdoc", // TODO: real Play URL
};

// TODO(cms): replace with real, approved testimonials before any paid push.
const testimonials = [
  { quote: "PawDoc helped me decide to get my dog to the vet that night.", author: "Sarah M., dog parent" },
  { quote: "Less panic at 2am. Clear, calm guidance in seconds.", author: "Diego R., cat parent" },
  { quote: "The peace of mind is worth it.", author: "Priya K., two dogs" },
];

export default function Home() {
  return (
    <main>
      <section className="hero container">
        <h1>Know when to call the vet — in seconds.</h1>
        <p className="sub">
          Add a photo or describe the symptom and PawDoc&rsquo;s AI gives you clear triage
          guidance: <strong>Emergency</strong>, <strong>Monitor</strong>, or{" "}
          <strong>Likely normal</strong> — so you can act with confidence.
        </p>
        <div className="badges">
          <a className="badge" href={STORE.appStore}>Download on the App Store</a>
          <a className="badge" href={STORE.googlePlay}>Get it on Google Play</a>
        </div>
        <p className="note" style={{ marginTop: 16 }}>
          PawDoc provides information and triage guidance — not a veterinary diagnosis. In an
          emergency, contact your vet immediately.
        </p>
      </section>

      <section className="section container">
        <h2>See it in action</h2>
        {/* Placeholder phone shots — drop real images in web/public/screenshots/ and
            replace these boxes with <img>/<Image>. Order mirrors the store listing. */}
        <div className="shots">
          <div className="shot">Screenshot 1 — &ldquo;Know exactly what your pet needs.&rdquo;</div>
          <div className="shot">Screenshot 2 — Camera &rarr; AI &rarr; result</div>
          <div className="shot">Screenshot 3 — &ldquo;No more 2am anxiety spirals.&rdquo;</div>
        </div>
      </section>

      <section className="section container">
        <h2>Pet parents trust PawDoc</h2>
        <div className="cards">
          {testimonials.map((t) => (
            <div className="card" key={t.author}>
              <p className="quote">&ldquo;{t.quote}&rdquo;</p>
              <p className="note">— {t.author}</p>
            </div>
          ))}
        </div>
      </section>

      <section className="section container">
        <h2>From the PawDoc blog</h2>
        <p style={{ textAlign: "center" }}>
          Practical, vet-reviewed guidance for common pet-health questions.{" "}
          <Link href="/blog/">Read the blog &rarr;</Link>
        </p>
      </section>

      <footer>
        <div className="container">
          <Link href="/blog/">Blog</Link>
          <a href="mailto:support@pawdoc.app">Support</a>
          <span className="note">
            Terms &amp; Privacy are published at pawdoc.app/terms and /privacy (attorney-reviewed; Phase 2.2 gate).
          </span>
        </div>
      </footer>
    </main>
  );
}
