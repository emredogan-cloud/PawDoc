import type { MDXComponents } from "mdx/types";

// Required by @next/mdx (App Router). Map MDX elements to custom components here
// if needed; defaults are fine for the blog.
export function useMDXComponents(components: MDXComponents): MDXComponents {
  return { ...components };
}
