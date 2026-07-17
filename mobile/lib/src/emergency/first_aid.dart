/// Bundled first-aid reference cards (evolution Phase 3 / C5).
///
/// STATIC, OFFLINE, NO AI. This is educational first-aid content about
/// emergency situations in general — the most defensible content class a pet
/// app can ship. Every card ends the same way: first aid buys time, the
/// veterinarian treats. Nothing here names a medication, a dose, or a
/// diagnosis.
///
/// FOUNDER GATE: have a licensed veterinarian review this copy before public
/// launch (tracked in the evolution report's founder checklist).
library;

class FirstAidTopic {
  const FirstAidTopic({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.steps,
    required this.never,
  });

  final String id;
  final String title;
  final String subtitle;

  /// Ordered do-this-now steps.
  final List<String> steps;

  /// Common mistakes that make things worse.
  final List<String> never;
}

const kFirstAidTopics = <FirstAidTopic>[
  FirstAidTopic(
    id: 'choking',
    title: 'Choking',
    subtitle: 'Pawing at the mouth, gagging, panic, noisy or no breathing',
    steps: [
      'Stay calm and restrain your pet gently — a choking animal may panic and bite.',
      'Open the mouth and look. If you can CLEARLY see and easily grasp an object, remove it with a sideways sweep of your fingers or tweezers.',
      'Do not push your fingers blindly down the throat — you can lodge the object deeper.',
      'If the object will not come free or breathing does not return to normal, go to the nearest veterinarian IMMEDIATELY — keep your pet as calm as possible on the way.',
      'Even if you remove the object, have your pet checked: the throat may be injured or swollen.',
    ],
    never: [
      'Never do a blind finger sweep you cannot see.',
      'Never wait to "see if it passes" when breathing is affected.',
    ],
  ),
  FirstAidTopic(
    id: 'bleeding',
    title: 'Heavy bleeding',
    subtitle: 'Blood that soaks through or does not slow within minutes',
    steps: [
      'Press a clean cloth, towel, or gauze firmly and DIRECTLY onto the wound.',
      'Keep pressing without lifting to check — constant pressure for at least 3–5 minutes. Lifting restarts the bleeding.',
      'If blood soaks through, add more cloth ON TOP; do not remove the soaked layer.',
      'If a limb is bleeding, keeping it raised above heart level can help while you travel.',
      'Go to a veterinarian now — heavy bleeding is always a professional visit, even if it slows.',
    ],
    never: [
      'Never apply a tourniquet unless a vet on the phone tells you exactly how.',
      'Never clean a heavily bleeding wound first — pressure comes first.',
    ],
  ),
  FirstAidTopic(
    id: 'seizure',
    title: 'Seizure',
    subtitle: 'Collapse with paddling, stiffening, twitching, or loss of awareness',
    steps: [
      'Do not touch the mouth — pets do not swallow their tongues, and you may be bitten.',
      'Move furniture and hard objects away; cushion the head if you can do it safely.',
      'Dim lights and reduce noise. Time the seizure if possible.',
      'When it ends, keep the room calm — your pet may be disoriented for a while.',
      'Contact a veterinarian now: any first seizure, a seizure over 2–3 minutes, or repeated seizures is an emergency visit.',
    ],
    never: [
      'Never restrain a seizing pet or hold their tongue.',
      'Never offer food or water until they are fully alert.',
    ],
  ),
  FirstAidTopic(
    id: 'bloat',
    title: 'Swollen, hard belly',
    subtitle: 'A visibly swollen or hard belly, retching that brings nothing up, restlessness',
    steps: [
      'Treat this as time-critical: go to the nearest veterinary clinic NOW — call ahead while traveling so they can prepare.',
      'Do not give food or water on the way.',
      'Keep your pet as calm and still as possible during transport.',
    ],
    never: [
      'Never wait to see if it improves — this combination of signs can become fatal within hours.',
      'Never try to relieve the swelling yourself.',
    ],
  ),
  FirstAidTopic(
    id: 'heatstroke',
    title: 'Overheating',
    subtitle: 'Heavy panting, drooling, weakness, bright-red gums after heat or exertion',
    steps: [
      'Move your pet to shade or a cool room immediately.',
      'Cool them with room-temperature (NOT ice-cold) water on the belly, paws, and ears — a wet towel that you keep re-wetting also works.',
      'Offer small amounts of cool water to drink; never force it.',
      'A fan over damp fur speeds cooling.',
      'Go to a veterinarian even if they seem to recover — internal effects of overheating can appear hours later.',
    ],
    never: [
      'Never use ice water or ice baths — rapid cooling causes its own damage.',
      'Never cover them with a soaked towel and leave it (it traps heat); keep re-wetting instead.',
    ],
  ),
];
