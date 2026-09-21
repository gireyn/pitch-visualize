import 'package:flutter/material.dart';

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
        appBar: AppBar(title: const Text('设置')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              children: [
                const _Section('音高检测'),
                _slider(
                  '音量阈值',
                  'threshold',
                  s.threshold,
                  0,
                  50,
                  '${s.threshold.toStringAsFixed(1)}%',
                  subtitle: '过滤轻微环境噪声；较低阈值可检测轻声',
                  divisions: 100,
                ),
                _slider(
                  '调音器平滑',
                  'smoothing',
                  s.smoothing.toDouble(),
                  1,
                  5,
                  '${s.smoothing}',
                  divisions: 4,
                  integer: true,
                ),
                const _Section('图表'),
                _switch(
                  'FFT 频谱',
                  'showSpectrum',
                  s.showSpectrum,
                  subtitle: '对数频率纵轴、调律音名；关闭后显示音高曲线',
                ),
                _slider(
                  '水平缩放',
                  'horizontalZoom',
                  s.horizontalZoom,
                  1,
                  2,
                  '${s.horizontalZoom.toStringAsFixed(1)}×',
                  divisions: 10,
                ),
                _slider(
                  '垂直缩放',
                  'verticalZoom',
                  s.verticalZoom,
                  MonitorSettings.minVerticalZoom,
                  MonitorSettings.maxVerticalZoom,
                  '${s.verticalZoom.toStringAsFixed(1)}×',
                  subtitle: '也可在图表上双指竖直捏合或拉开',
                  divisions: 15,
                ),
                _slider(
                  '滚动速度',
                  'scrollSpeed',
                  s.scrollSpeed.toDouble(),
                  1,
                  10,
                  '${s.scrollSpeed}',
                  divisions: 9,
                  integer: true,
                ),
                _switch(
                  '自动跟随音域',
                  'autoScroll',
                  s.autoScroll,
                  subtitle: '拖动或捏合图表会暂停跟随，可在图表中一键恢复',
                ),
                _switch(
                  '显示调音器刻度',
                  'showTuner',
                  s.showTuner,
                  subtitle: '显示音名刻度和当前音高指针，默认关闭',
                ),
                const _Section('节拍'),
                _slider(
                  '速度 BPM',
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
                      const Text('拍号'),
                      SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 0, label: Text('无')),
                          ButtonSegment(value: 3, label: Text('3/4')),
                          ButtonSegment(value: 4, label: Text('4/4')),
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
                _switch('显示节拍线', 'showBeats', s.showBeats),
                _switch(
                  '视觉节拍器',
                  'flashBeat',
                  s.flashBeat,
                  subtitle: '用闪光指示节拍，不发出声音',
                ),
                const _Section('颜色'),
                _ColorChoices(
                  title: '音高曲线',
                  value: s.pitchColor,
                  onChanged: (value) =>
                      controller.updateSetting('pitchColor', value),
                ),
                _ColorChoices(
                  title: '节拍线',
                  value: s.beatColor,
                  onChanged: (value) =>
                      controller.updateSetting('beatColor', value),
                ),
                _ColorChoices(
                  title: '视觉节拍器',
                  value: s.metronomeColor,
                  onChanged: (value) =>
                      controller.updateSetting('metronomeColor', value),
                ),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    '音阶网格与音名的颜色由调律文件中的灰度值决定。',
                    style: TextStyle(color: AppColors.muted),
                  ),
                ),
                const _Section('快捷操作'),
                _switch('显示冻结按钮', 'showHold', s.showHold),
                _switch('显示调律按钮', 'showScale', s.showScale),
                _switch('显示速度按钮', 'showTempo', s.showTempo),
                const _Section('关于 PitchVisual'),
                const ListTile(
                  title: Text('离线音高监测 · Flutter'),
                  subtitle: Text(
                    'iOS 与 Android 使用同一套调律和音高算法。\n录音仅保存在此设备，最长 5 分钟。\n支持的输入：人声或单音乐器。',
                  ),
                ),
                ListTile(
                  title: const Text('开源许可'),
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
