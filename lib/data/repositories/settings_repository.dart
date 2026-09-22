import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/models/monitor_settings.dart';
import '../../domain/tuning/scale_config.dart';
import '../../l10n/app_message.dart';
import '../services/platform_service.dart';

class SavedSettings {
  const SavedSettings(this.settings, this.scale, {this.notice});
  final MonitorSettings settings;
  final ScaleConfig scale;
  final AppMessage? notice;
}

class SettingsRepository {
  SettingsRepository(this.platform);
  final PlatformService platform;
  Future<ScaleConfig> bundledScale([bool tiangan = false]) async =>
      ScaleConfig.parse(
        await rootBundle.loadString(
          tiangan
              ? 'assets/tunings/tiangan.txt'
              : 'assets/tunings/seven_ed2_on_c.txt',
        ),
        tiangan ? '天干音阶' : '7ed2 on C',
      );
  Future<SavedSettings> load() async {
    var settings = const MonitorSettings();
    try {
      final raw = await platform.loadPreferences();
      if (raw == null || raw.isEmpty) {
        return SavedSettings(settings, await bundledScale());
      }
      final json = Map<String, Object?>.from(jsonDecode(raw) as Map);
      settings = MonitorSettings.fromJson(
        json['settings'] is Map
            ? Map<String, Object?>.from(json['settings'] as Map)
            : json,
      );
      if (json['scaleMode'] == 'edo') {
        return SavedSettings(settings, ScaleConfig.equalDivision(settings.edo));
      }
      final payload = json['scalePayload'] ?? json['key_config_payload'];
      final cached = payload is String
          ? ScaleConfig.fromPayload(payload)
          : null;
      if (json['scaleSource'] case final String source) {
        try {
          return SavedSettings(
            settings,
            ScaleConfig.parse(source, json['scaleName'] as String? ?? '自定义调律'),
          );
        } on FormatException {
          if (cached != null) {
            return SavedSettings(
              settings,
              cached,
              notice: AppMessage((strings) => strings.noticeTuningRestored),
            );
          }
          rethrow;
        }
      }
      return SavedSettings(settings, cached ?? await bundledScale());
    } catch (_) {
      return SavedSettings(
        settings,
        await bundledScale(),
        notice: AppMessage((strings) => strings.noticeSettingsRestored),
      );
    }
  }

  Future<void> save(MonitorSettings settings, ScaleConfig scale) =>
      platform.savePreferences(
        jsonEncode({
          'version': 1,
          'settings': settings.toJson(),
          if (scale.edo != null)
            'scaleMode': 'edo'
          else ...{
            'scaleName': scale.name,
            if (scale.source.isNotEmpty) 'scaleSource': scale.source,
            'scalePayload': scale.toPayload(),
          },
        }),
      );
}
