import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'data/repositories/recording_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/services/platform_service.dart';
import 'ui/core/app_theme.dart';
import 'ui/features/monitor/monitor_controller.dart';
import 'ui/features/monitor/monitor_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(
      ['PitchVisual pitch monitor'],
      'Based on VocalPitchMonitor, copyright tadaoyamaoka, Apache License 2.0.\n'
      'Tuning grammar derived from musescore-xen-tuner, copyright euwbah, GPL-3.0.\n'
      'See docs/legacy-android.md for provenance.',
    );
  });
  final platform = PlatformService();
  final controller = MonitorController(
    platform: platform,
    settingsRepository: SettingsRepository(platform),
    recordingRepository: RecordingRepository(platform),
  );
  runApp(PitchVisualApp(controller: controller));
}

class PitchVisualApp extends StatefulWidget {
  const PitchVisualApp({
    super.key,
    required this.controller,
    this.initialize = true,
  });
  final MonitorController controller;
  final bool initialize;
  @override
  State<PitchVisualApp> createState() => _PitchVisualAppState();
}

class _PitchVisualAppState extends State<PitchVisualApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.initialize) unawaited(widget.controller.initialize());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(widget.controller.suspend());
    } else if (state == AppLifecycleState.resumed) {
      unawaited(widget.controller.resume());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'PitchVisual',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    locale: const Locale('zh'),
    supportedLocales: const [Locale('zh'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: MonitorScreen(controller: widget.controller),
  );
}
