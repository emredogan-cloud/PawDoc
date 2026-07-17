/// Copy for Paywall Variant C (Phase 4.2). Kept here so it can be swapped for a
/// CMS / strings source later WITHOUT touching the widget — just replace these
/// values (or repoint them at remote config).
///
/// HONESTY REBUILD (Phase B): pre-launch, PawDoc has NO real customers, so this
/// card must NOT show a fabricated persona testimonial or an
/// unsubstantiated "Veterinary Advisory team" claim — both are App Store / FTC
/// deception risks, the same class of defect as the onboarding "★ 4.8" line.
/// It now shows truthful value/trust copy instead. Replace [valueLine] with a
/// REAL, approved testimonial only when one genuinely exists; never imply a
/// person or endorsement that isn't real. Final wording pending owner/legal
/// sign-off.
class PaywallSocialProof {
  const PaywallSocialProof._();

  static const String trustTitle = 'Built to err on the safe side';
  static const String trustSubtitle =
      'PawDoc flags possible emergencies first';
  static const String valueLine =
      'Get a calm, clear read on your pet’s symptoms in seconds — '
      'and know when it’s time to call the vet.';
}
