import createMDX from "@next/mdx";

/**
 * Static export so the whole site (landing + MDX blog) is plain HTML/JS hosted
 * for free on Cloudflare Pages — NO Node server (Phase 4.3 strict rule).
 * Cloudflare Pages: build command `npm run build`, output directory `out`.
 * @type {import('next').NextConfig}
 */
const nextConfig = {
  output: "export", // -> emits ./out as fully static files
  trailingSlash: true, // stable directory-style URLs on Pages
  images: { unoptimized: true }, // required: no Image Optimization server in a static export
  pageExtensions: ["ts", "tsx", "md", "mdx"], // let .mdx files be pages (the blog)
};

const withMDX = createMDX({});

export default withMDX(nextConfig);
