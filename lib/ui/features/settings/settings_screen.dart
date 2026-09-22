import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../core/app_theme.dart';
import '../../../domain/models/monitor_settings.dart';
import '../monitor/monitor_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});
  final MonitorController controller;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final s = controller.settings;
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.settingsTitle)),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              children: [
                _Section(context.l10n.settingsTuning),
                ListTile(
                  leading: const Icon(Icons.piano_outlined),
                  title: Text(context.l10n.settingsChooseTuning),
                  subtitle: Text(
                    controller.scale == null
                        ? context.l10n.settingsNoScaleSelected
                        : context.l10n.scaleName(controller.scale!.name),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: controller.busy ? null : () => _showScale(context),
                ),
                _slider(
                  context.l10n.settingsEdoScale,
                  'edo',
                  s.edo.toDouble(),
                  MonitorSettings.minEdo.toDouble(),
                  MonitorSettings.maxEdo.toDouble(),
                  s.edo == 0
                      ? context.l10n.settingsOctavesOnly
                      : context.l10n.settingsEdoDivisions(s.edo),
                  subtitle: controller.scale?.edo != null
                      ? context.l10n.settingsEdoActiveHint
                      : context.l10n.settingsEdoInactiveHint,
                  divisions: MonitorSettings.maxEdo - MonitorSettings.minEdo,
                  integer: true,
                ),
                _Section(context.l10n.settingsPitchDetection),
                _slider(
                  context.l10n.settingsVolumeThreshold,
                  'threshold',
                  s.threshold,
                  0,
                  50,
                  '${s.threshold.toStringAsFixed(1)}%',
                  subtitle: context.l10n.settingsVolumeThresholdHint,
                  divisions: 100,
                ),
                _slider(
                  context.l10n.settingsTunerSmoothing,
                  'smoothing',
                  s.smoothing.toDouble(),
                  1,
                  5,
                  '${s.smoothing}',
                  divisions: 4,
                  integer: true,
                ),
                _Section(context.l10n.settingsCharts),
                _switch(
                  context.l10n.settingsFftSpectrum,
                  'showSpectrum',
                  s.showSpectrum,
                  subtitle: context.l10n.settingsFftSpectrumHint,
                ),
                _slider(
                  context.l10n.settingsHorizontalZoom,
                  'horizontalZoom',
                  s.horizontalZoom,
                  1,
                  2,
                  '${s.horizontalZoom.toStringAsFixed(1)}×',
                  divisions: 10,
                ),
                _slider(
                  context.l10n.settingsVerticalZoom,
                  'verticalZoom',
                  s.verticalZoom,
                  MonitorSettings.minVerticalZoom,
                  MonitorSettings.maxVerticalZoom,
                  '${s.verticalZoom.toStringAsFixed(1)}×',
                  subtitle: context.l10n.settingsVerticalZoomHint,
                  divisions: 15,
                ),
                _slider(
                  context.l10n.settingsScrollSpeed,
                  'scrollSpeed',
                  s.scrollSpeed.toDouble(),
                  1,
                  10,
                  '${s.scrollSpeed}',
                  divisions: 9,
                  integer: true,
                ),
                _switch(
                  context.l10n.settingsAutoFollow,
                  'autoScroll',
                  s.autoScroll,
                  subtitle: context.l10n.settingsAutoFollowHint,
                ),
                _switch(
                  context.l10n.settingsShowTuner,
                  'showTuner',
                  s.showTuner,
                  subtitle: context.l10n.settingsShowTunerHint,
                ),
                _Section(context.l10n.settingsBeat),
                _slider(
                  context.l10n.settingsTempo,
                  'bpm',
                  s.bpm.toDouble(),
                  20,
                  250,
                  '${s.bpm}',
                  divisions: 230,
                  integer: true,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      Text(context.l10n.settingsTimeSignature),
                      SegmentedButton<int>(
                        segments: [
                          ButtonSegment(
                            value: 0,
                            label: Text(context.l10n.settingsNoTimeSignature),
                          ),
                          const ButtonSegment(value: 3, label: Text('3/4')),
                          const ButtonSegment(value: 4, label: Text('4/4')),
                        ],
                        selected: {s.beatsPerBar},
                        onSelectionChanged: (value) => controller.updateSetting(
                          'beatsPerBar',
                          value.first,
                        ),
                      ),
                    ],
                  ),
                ),
                _switch(
                  context.l10n.settingsShowBeatLines,
                  'showBeats',
                  s.showBeats,
                ),
                _switch(
                  context.l10n.settingsVisualMetronome,
                  'flashBeat',
                  s.flashBeat,
                  subtitle: context.l10n.settingsVisualMetronomeHint,
                ),
                _Section(context.l10n.settingsColors),
                _ColorChoices(
                  title: context.l10n.settingsPitchCurve,
                  value: s.pitchColor,
                  onChanged: (value) =>
                      controller.updateSetting('pitchColor', value),
                ),
                _ColorChoices(
                  title: context.l10n.settingsBeatLines,
                  value: s.beatColor,
                  onChanged: (value) =>
                      controller.updateSetting('beatColor', value),
                ),
                _ColorChoices(
                  title: context.l10n.settingsVisualMetronome,
                  value: s.metronomeColor,
                  onChanged: (value) =>
                      controller.updateSetting('metronomeColor', value),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    context.l10n.settingsScaleColorsHint,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ),
                _Section(context.l10n.settingsQuickActions),
                _switch(
                  context.l10n.settingsShowFreeze,
                  'showHold',
                  s.showHold,
                ),
                _Section(context.l10n.settingsAbout),
                ListTile(
                  title: Text(context.l10n.settingsOfflineMonitor),
                  subtitle: Text(context.l10n.settingsAboutDescription),
                ),
                ListTile(
                  title: Text(context.l10n.settingsOpenSourceLicenses),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'PitchVisual',
                    applicationVersion: '5.0.0',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  void _showScale(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                context.l10n.settingsTuning,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              subtitle: Text(
                controller.scale == null
                    ? context.l10n.settingsNoScaleSelected
                    : context.l10n.settingsCurrentTuning(
                        context.l10n.scaleName(controller.scale!.name),
                        controller.scale!.names.length,
                        controller.scale!.periodCents.toStringAsFixed(2),
                      ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.grid_on_outlined),
              title: Text(context.l10n.settingsUseEdoScale),
              subtitle: Text(
                controller.settings.edo == 0
                    ? context.l10n.settingsUseOctavesOnlyDescription
                    : context.l10n.settingsUseEdoDescription(
                        controller.settings.edo,
                      ),
              ),
              onTap: () {
                Navigator.pop(context);
                controller.useEdoScale();
              },
            ),
            ListTile(
              leading: const Icon(Icons.piano),
              title: const Text('7ed2 on C'),
              subtitle: Text(context.l10n.settingsDefaultTuningDescription),
              onTap: () {
                Navigator.pop(context);
                controller.useBundledScale(false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.music_note_outlined),
              title: Text(context.l10n.tianganScale),
              subtitle: const Text('甲 乙 丙 丁 戊 己 庚 辛 壬 癸'),
              onTap: () {
                Navigator.pop(context);
                controller.useBundledScale(true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.file_open_outlined),
              title: Text(context.l10n.settingsImportTuning),
              subtitle: Text(context.l10n.settingsTuningFileFormat),
              onTap: () {
                Navigator.pop(context);
                controller.importScale();
              },
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                context.l10n.settingsTuningImportHint,
                style: const TextStyle(color: AppColors.muted),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _switch(String label, String key, bool value, {String? subtitle}) =>
      SwitchListTile(
        title: Text(label),
        subtitle: subtitle == null ? null : Text(subtitle),
        value: value,
        onChanged: (next) => controller.updateSetting(key, next),
      );
  Widget _slider(
    String title,
    String key,
    double value,
    double min,
    double max,
    String label, {
    String? subtitle,
    int? divisions,
    bool integer = false,
  }) => _SettingSlider(
    title: title,
    value: value,
    min: min,
    max: max,
    label: label,
    subtitle: subtitle,
    divisions: divisions,
    onChanged: (next) =>
        controller.updateSetting(key, integer ? next.round() : next),
  );
}

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
    child: Text(
      title,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(color: AppColors.accent),
    ),
  );
}

class _SettingSlider extends StatefulWidget {
  const _SettingSlider({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.label,
    required this.onChanged,
    this.subtitle,
    this.divisions,
  });
  final String title, label;
  final String? subtitle;
  final double value, min, max;
  final int? divisions;
  final ValueChanged<double> onChanged;
  @override
  State<_SettingSlider> createState() => _SettingSliderState();
}

class _SettingSliderState extends State<_SettingSlider> {
  double? _drag;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 16,
          children: [
            Text(widget.title),
            Text(
              _drag?.toStringAsFixed(1) ?? widget.label,
              style: const TextStyle(color: AppColors.accent),
            ),
          ],
        ),
        if (widget.subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              widget.subtitle!,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ),
        Slider(
          value: _drag ?? widget.value,
          min: widget.min,
          max: widget.max,
          divisions: widget.divisions,
          semanticFormatterCallback: (value) => '${widget.title} $value',
          onChanged: (value) => setState(() => _drag = value),
          onChangeEnd: (value) {
            widget.onChanged(value);
            setState(() => _drag = null);
          },
        ),
      ],
    ),
  );
}

class _ColorChoices extends StatelessWidget {
  const _ColorChoices({
    required this.title,
    required this.value,
    required this.onChanged,
  });
  final String title;
  final int value;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    final colors = {
      value,
      0xffffd75e,
      0xff8de0cb,
      0xff8cbcff,
      0xffee9dab,
      0xffbb9efa,
      0xff8898aa,
      0xff495466,
    };
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: colors
                .map(
                  (color) => Semantics(
                    label:
                        '$title #${(color & 0xffffff).toRadixString(16).padLeft(6, '0')}',
                    selected: color == value,
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: Color(color),
                        ),
                        onPressed: () => onChanged(color),
                        icon: Icon(
                          color == value ? Icons.check : Icons.circle_outlined,
                          color:
                              ThemeData.estimateBrightnessForColor(
                                    Color(color),
                                  ) ==
                                  Brightness.light
                              ? Colors.black
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
