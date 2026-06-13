import Link from "next/link";

// Placeholder marketing copy + assets (Phase 4.3). Swap the badge hrefs for the
// real store URLs and drop real screenshots into web/public/ (see the note).
const STORE = {
  appStore: "https://apps.apple.com/app/pawdoc", // TODO: real App Store URL at launch
  googlePlay: "https://play.google.com/store/apps/details?id=app.pawdoc", // TODO: real Play URL
};

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
        <p style={{ marginTop: 16 }}>
          <Link href="/check/">Or try the free web symptom checker &rarr;</Link>
        </p>
        <p className="note">
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
        <h2>Built to put safety first</h2>
        <div className="cards">
          <div className="card">
            <p className="quote">Possible emergencies are flagged before anything else — and emergency guidance is never behind a paywall.</p>
          </div>
          <div className="card">
            <p className="quote">When the AI isn&rsquo;t confident, PawDoc says so instead of guessing.</p>
          </div>
          <div className="card">
            <p className="quote">Private by design — delete your account and data anytime, right in the app.</p>
          </div>
        </div>
      </section>

      <section className="section container">
        <h2>From the PawDoc blog</h2>
        <p style={{ textAlign: "center" }}>
          Practical guidance for common pet-health questions.{" "}
          <Link href="/blog/">Read the blog &rarr;</Link>
        </p>
      </section>

      <footer>
        <div className="container">
          <Link href="/blog/">Blog</Link>
          <a href="mailto:support@pawdoc.app">Support</a>
          <span className="note">
            Terms &amp; Privacy are published at pawdoc.app/terms and /privacy.
          </span>
        </div>
      </footer>
    </main>
  );
}
