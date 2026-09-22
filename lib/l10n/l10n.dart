import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

extension AppLocalizationContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

extension TuningLocalization on AppLocalizations {
  // Keep persisted tuning names and note labels stable across language changes.
  String scaleName(String name) => switch (name) {
    '天干音阶' => tianganScale,
    '自定义调律' => customScale,
    '八度刻度' => octaveScale,
    _ => name,
  };
}
