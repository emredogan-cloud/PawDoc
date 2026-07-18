/// Client-side emergency keyword router (evolution Phase 3).
///
/// GENERATED to byte-match `ai-service/app/safety.py` and
/// `supabase/functions/_shared/emergency_keywords.mjs` — the three lists
/// must stay identical (guarded by test/emergency_keywords_parity_test.dart).
/// The CLIENT router makes the red path instant and OFFLINE-capable; the
/// server override remains authoritative for anything submitted online.
/// Substring match errs toward over-triage — the SAFE direction.
library;

const Map<String, List<String>> emergencyKeywordsByLocale = {
  'en': [
    'not breathing',
    'stopped breathing',
    'can\'t breathe',
    'labored breathing',
    'blue gums',
    'grey gums',
    'pale gums',
    'seizure',
    'seizing',
    'convulsing',
    'collapse',
    'collapsed',
    'can\'t stand',
    'grapes',
    'xylitol',
    'rat poison',
    'antifreeze',
    'suspected poisoning',
    'ate something toxic',
    'hit by car',
    'severe bleeding',
    'broken bone',
    'compound fracture',
  ],
  'de': [
    'atmet nicht',
    'hat aufgehört zu atmen',
    'kann nicht atmen',
    'atemnot',
    'schwere atmung',
    'atmet schwer',
    'blaues zahnfleisch',
    'graues zahnfleisch',
    'blasses zahnfleisch',
    'krampfanfall',
    'krampft',
    'anfall',
    'konvulsionen',
    'zuckungen',
    'kollaps',
    'zusammengebrochen',
    'kann nicht stehen',
    'weintrauben',
    'trauben',
    'xylit',
    'xylitol',
    'rattengift',
    'frostschutzmittel',
    'frostschutz',
    'verdacht auf vergiftung',
    'vergiftet',
    'etwas giftiges gefressen',
    'etwas giftiges gegessen',
    'vom auto angefahren',
    'angefahren',
    'starke blutung',
    'blutet stark',
    'knochenbruch',
    'gebrochener knochen',
    'offener bruch',
    'offene fraktur',
  ],
};

const Map<String, Map<String, List<String>>> speciesEmergencyKeywordsByLocale = {
  'en': {
    'rabbit': [
      'not eating',
      'won\'t eat',
      'stopped eating',
      'not pooping',
      'no poop',
      'no droppings',
      'not drinking',
      'won\'t drink',
      'bloated',
      'hard belly',
      'head tilt',
      'tilting head',
      'gi stasis',
      'stasis',
      'not moving',
    ],
    'guinea_pig': [
      'not eating',
      'won\'t eat',
      'stopped eating',
      'not pooping',
      'no poop',
      'not drinking',
      'won\'t drink',
      'bloated',
      'gi stasis',
      'stasis',
      'labored breathing',
      'not moving',
    ],
    'bird': [
      'fluffed',
      'fluffed up',
      'puffed',
      'puffed up',
      'bottom of the cage',
      'on the cage floor',
      'sitting on the bottom',
      'tail bobbing',
      'open mouth breathing',
      'open-mouth breathing',
      'not eating',
      'won\'t eat',
      'fell off perch',
      'not perching',
    ],
    'reptile': [
      'open mouth breathing',
      'open-mouth breathing',
      'mouth rot',
      'prolapse',
      'unresponsive',
      'not moving',
      'gasping',
    ],
  },
  'de': {
    'rabbit': [
      'frisst nicht',
      'isst nicht',
      'frisst kein heu',
      'frisst kein futter',
      'kein kot',
      'keine köttel',
      'kein köttel',
      'keinen kot abgesetzt',
      'verstopfung',
      'trinkt nicht',
      'aufgebläht',
      'aufgeblähter bauch',
      'harter bauch',
      'kopfschiefhaltung',
      'schiefer kopf',
      'kippt den kopf',
      'magen-darm-stase',
      'darmstase',
      'bewegt sich nicht',
    ],
    'guinea_pig': [
      'frisst nicht',
      'isst nicht',
      'kein kot',
      'keine köttel',
      'trinkt nicht',
      'aufgebläht',
      'aufgeblähter bauch',
      'schwere atmung',
      'atmet schwer',
      'darmstase',
      'bewegt sich nicht',
    ],
    'bird': [
      'aufgeplustert',
      'plustert sich auf',
      'sitzt am käfigboden',
      'auf dem käfigboden',
      'auf dem boden des käfigs',
      'schwanzwippen',
      'wippt mit dem schwanz',
      'atmet mit offenem schnabel',
      'öffnet den schnabel zum atmen',
      'frisst nicht',
      'vom ast gefallen',
      'vom sitzast gefallen',
      'sitzt nicht auf',
    ],
    'reptile': [
      'atmet mit offenem maul',
      'atmet mit offenem mund',
      'schnappt nach luft',
      'maulfäule',
      'prolaps',
      'reagiert nicht',
      'bewegt sich nicht',
    ],
  },
};

String _normLocale(String? locale) {
  if (locale == null || locale.isEmpty) return 'en';
  final code = locale.trim().toLowerCase().split('-').first;
  return emergencyKeywordsByLocale.containsKey(code) ? code : 'en';
}

String _normSpecies(String? species) =>
    (species ?? '').trim().toLowerCase().replaceAll(' ', '_');

/// Returns the first matching emergency keyword, or null. Mirrors
/// `check_emergency_override` in safety.py: global keywords first, then the
/// species-specific set, in the user's locale (unknown locale -> 'en').
String? matchEmergencyKeyword(String? text, {String? species, String? locale}) {
  if (text == null || text.isEmpty) return null;
  final lowered = text.toLowerCase();
  final lkey = _normLocale(locale);
  for (final k in emergencyKeywordsByLocale[lkey]!) {
    if (lowered.contains(k)) return k;
  }
  final speciesMap = speciesEmergencyKeywordsByLocale[lkey] ?? const {};
  for (final k in speciesMap[_normSpecies(species)] ?? const <String>[]) {
    if (lowered.contains(k)) return k;
  }
  return null;
}
