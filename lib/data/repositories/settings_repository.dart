import 'dart:convert';
import 'package:flutter/services.dart';
import '../../domain/models/monitor_settings.dart';
import '../../domain/tuning/scale_config.dart';
import '../services/platform_service.dart';

class SavedSettings {
  const SavedSettings(this.settings, this.scale, {this.notice});
  final MonitorSettings settings;
  final ScaleConfig scale;
  final String? notice;
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
            return SavedSettings(settings, cached, notice: '已从缓存恢复调律');
          }
          rethrow;
        }
      }
      return SavedSettings(settings, cached ?? await bundledScale());
    } catch (_) {
      return SavedSettings(
        settings,
        await bundledScale(),
        notice: '本地设置无法完整读取，已恢复默认调律',
      );
    }
  }

  Future<void> save(MonitorSettings settings, ScaleConfig scale) =>
      platform.savePreferences(
        jsonEncode({
          'version': 1,
          'settings': settings.toJson(),
          'scaleName': scale.name,
          if (scale.source.isNotEmpty) 'scaleSource': scale.source,
          'scalePayload': scale.toPayload(),
        }),
      );
}
