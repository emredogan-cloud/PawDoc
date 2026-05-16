"""Per-breed risk-factor snippets injected into the user prompt.

Phase 1B ships ~20 of the most common breeds. The dictionary is keyed by a
normalised lowercase breed name. Unknown breeds fall through to an empty
string — the LLM still has species + age + weight to work with.

Phase 6 (personalization engine) replaces this static table with a richer
source backed by analytics. Keeping it static here is intentional: the
text is reviewable, the failure mode is "no context injected" (safe), and
there is no external lookup at request time.
"""

from __future__ import annotations

_BREED_CONTEXT: dict[str, str] = {
    "french bulldog": (
        "Brachycephalic breed — labored breathing, heat sensitivity, and panting "
        "are concerning even at lower intensities than in long-snouted breeds."
    ),
    "english bulldog": (
        "Brachycephalic breed — labored breathing, heat sensitivity, and panting "
        "are concerning even at lower intensities than in long-snouted breeds."
    ),
    "pug": (
        "Brachycephalic breed — breathing difficulty, snoring at rest, and "
        "exercise intolerance are escalated risks."
    ),
    "boxer": (
        "Predisposed to mast cell tumours, bloat, and cardiomyopathy. Any new "
        "lump or sudden lethargy warrants prompt vet review."
    ),
    "golden retriever": (
        "Predisposed to lymphoma, hemangiosarcoma, and hip dysplasia. New "
        "lameness in adults aged 6+ deserves attention."
    ),
    "labrador retriever": (
        "Predisposed to obesity-related joint issues and hereditary cataracts. "
        "Weight changes can mask underlying conditions."
    ),
    "german shepherd": (
        "Predisposed to hip and elbow dysplasia, exocrine pancreatic "
        "insufficiency, and bloat. Bloat is a true emergency."
    ),
    "dachshund": (
        "Long-backed breed at high IVDD risk. Sudden back pain, hind-limb "
        "weakness, or unwillingness to climb stairs may indicate disc disease."
    ),
    "chihuahua": (
        "Toy breed — at risk for hypoglycaemia (especially puppies), patellar "
        "luxation, and tracheal collapse."
    ),
    "yorkshire terrier": (
        "Toy breed — at risk for hypoglycaemia, dental disease, and tracheal collapse."
    ),
    "poodle": (
        "Predisposed to Addison's disease and cataracts. Acute weakness or "
        "vomiting could reflect adrenal insufficiency."
    ),
    "cocker spaniel": (
        "Predisposed to chronic ear infections (heavy ears), and certain "
        "autoimmune conditions. Any ear redness/discharge merits attention."
    ),
    "doberman": (
        "Predisposed to dilated cardiomyopathy and von Willebrand disease. "
        "Unexplained collapse or bruising is concerning."
    ),
    "great dane": (
        "Giant breed — bloat (gastric dilatation-volvulus) is a true emergency. "
        "Restlessness, retching, and a distended abdomen warrant immediate care."
    ),
    "siamese": (
        "Asthma-prone cat breed. Open-mouth breathing or persistent coughing "
        "is a strong sign to escalate."
    ),
    "persian": (
        "Brachycephalic cat breed — breathing, tearing, and dental concerns "
        "appear earlier than in domestic shorthairs."
    ),
    "maine coon": (
        "Predisposed to hypertrophic cardiomyopathy. Lethargy, panting (rare "
        "for cats), or sudden hindlimb weakness should escalate to vet care."
    ),
    "ragdoll": (
        "Predisposed to hypertrophic cardiomyopathy. Sudden hindlimb paralysis "
        "is a saddle thrombus emergency."
    ),
    "rabbit": (
        "Rabbits hide illness; any drop in appetite or absence of stool for "
        ">12h is potentially life-threatening (GI stasis)."
    ),
}


def breed_context_for(species: str, breed: str | None) -> str:
    """Return the risk-factor text for a (species, breed) pair, or ''.

    The breed key is normalised to lowercase. The species check is light:
    rabbits use a species-level fallback even when ``breed`` is None.
    """
    if species == "rabbit" and not breed:
        return _BREED_CONTEXT.get("rabbit", "")
    if not breed:
        return ""
    key = breed.strip().lower()
    return _BREED_CONTEXT.get(key, "")
