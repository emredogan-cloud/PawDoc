import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../analytics/analytics.dart';
import '../models/analysis_result.dart';

/// EMERGENCY result: warm red, urgent copy, a vet-finder deep link, and an
/// explicit acknowledgment gate — the user MUST acknowledge before leaving
/// (back is blocked until then). Never paywalled.
class EmergencyResultScreen extends ConsumerStatefulWidget {
  const EmergencyResultScreen({super.key, required this.result});
  final AnalysisResult result;

  @override
  ConsumerState<EmergencyResultScreen> createState() => _EmergencyResultScreenState();
}

class _EmergencyResultScreenState extends ConsumerState<EmergencyResultScreen> {
  bool _acknowledged = false;

  @override
  void initState() {
    super.initState();
    Analytics.emergencyTriggered();
    Analytics.resultViewed('EMERGENCY');
  }

  Future<void> _findVet() async {
    final uri = Uri.parse('https://www.google.com/maps/search/emergency+vet+near+me');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFC62828); // warm, urgent red
    final r = widget.result;

    return PopScope(
      canPop: _acknowledged, // acknowledgment gate
      child: Scaffold(
        backgroundColor: red,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 64),
                const SizedBox(height: 12),
                const Text('This may be an emergency',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text(r.primaryConcern,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 18)),
                const SizedBox(height: 8),
                Text('Recommended: ${r.urgencyTimeframe}.',
                    textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 24),
                FilledButton.icon(
                  key: const Key('emergency_find_vet'),
                  style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: red),
                  onPressed: _findVet,
                  icon: const Icon(Icons.local_hospital),
                  label: const Text('Find an emergency vet now'),
                ),
                const SizedBox(height: 24),
                if (r.disclaimerRequired)
                  const Text(
                    'PawDoc provides information, not a diagnosis. In an emergency, contact a veterinarian immediately.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  key: const Key('emergency_ack_checkbox'),
                  value: _acknowledged,
                  onChanged: (v) => setState(() => _acknowledged = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  tileColor: Colors.white24,
                  title: const Text('I understand this needs urgent attention',
                      style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  key: const Key('emergency_continue'),
                  style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: red),
                  onPressed: _acknowledged ? () => Navigator.of(context).maybePop() : null,
                  child: const Text('Continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
