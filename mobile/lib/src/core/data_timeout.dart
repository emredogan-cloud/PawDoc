/// Bound on a screen-gating table read.
///
/// Without one, an offline cold start never completes: the socket stalls, the
/// future never settles, and the screen sits on loading skeletons forever
/// instead of reaching its "couldn't load / try again" branch. Device-found on
/// a Redmi Note 11R in airplane mode.
///
/// Deliberately generous — a slow mobile network should finish inside it, and
/// every caller has a retry. Long operations (analysis, uploads, account
/// deletion) keep their own, larger bounds next to their own call sites.
const Duration kDataReadTimeout = Duration(seconds: 12);
