import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/paw_ui.dart';

/// Canonical user-facing label + colour for a contract-v2 ladder action token
/// (`GET_HELP_NOW` | `CALL_TODAY` | `BOOK_VISIT` | `WATCH_AND_RECHECK`).
///
/// One source of truth so the raw wire token never reaches a user — an RC
/// on-device audit found `GET_HELP_NOW` rendered verbatim in the pets-list
/// "last check" chip. Deliberately NO "Healthy"/"Normal" label: the record
/// never reassures (contract v2 has no "do nothing" rung).
String actionLabel(String action) => switch (action) {
      'GET_HELP_NOW' => 'Urgent',
      'CALL_TODAY' => 'Call today',
      'BOOK_VISIT' => 'Book visit',
      'WATCH_AND_RECHECK' => 'Watching',
      _ => 'Check',
    };

/// The brand colour paired with each ladder action (mirrors the timeline chip).
Color actionColor(String action) => switch (action) {
      'GET_HELP_NOW' => AppColors.emergencyLight,
      'CALL_TODAY' => AppColors.monitorLight,
      'BOOK_VISIT' => AppColors.actionBookVisit,
      'WATCH_AND_RECHECK' => AppColors.actionWatch,
      _ => PawPalette.mint,
    };
