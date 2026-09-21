import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../settings/settings_screen.dart';
import 'monitor_controller.dart';
import 'pitch_graph.dart';

class MonitorScreen extends StatelessWidget {
  const MonitorScreen({super.key, required this.controller});
  final MonitorController controller;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.graphic_eq, color: AppColors.accent),
            SizedBox(width: 10),
            Flexible(
              child: Text(
                'PitchVisual',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '录音库',
            icon: const Icon(Icons.library_music_outlined),
            onPressed: controller.initialized
                ? () => _showLibrary(context)
                : null,
          ),
          PopupMenuButton<String>(
            tooltip: '更多选项',
            onSelected: (action) {
              if (action == 'settings') {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SettingsScreen(controller: controller),
                  ),
                );
              }
              if (action == 'hold') controller.toggleHold();
              if (action == 'spectrum') {
                controller.updateSetting(
                  'showSpectrum',
                  !controller.settings.showSpectrum,
                );
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'spectrum',
                child: Text(
                  controller.settings.showSpectrum ? '切换为音高曲线' : '切换为 FFT 频谱',
                ),
              ),
              PopupMenuItem(value: 'settings', child: Text('设置')),
              PopupMenuItem(value: 'hold', child: Text('冻结 / 继续图表')),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: !controller.initialized
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (controller.busy) const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(controller.message ?? '正在准备音高监测器…'),
                    if (!controller.busy)
                      TextButton(
                        onPressed: controller.initialize,
                        child: const Text('重试'),
                      ),
                  ],
                ),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final wide =
                      constraints.maxWidth >= 760 &&
                      constraints.maxHeight >= 420;
                  final largeText =
                      MediaQuery.textScalerOf(context).scale(16) > 24;
                  final compact = constraints.maxHeight < 620 || largeText;
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1400),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          wide ? 24 : 16,
                          4,
                          wide ? 24 : 16,
                          12,
                        ),
                        child: Column(
                          children: [
                            if (controller.message != null)
                              _MessageBanner(controller: controller),
                            if (wide)
                              Expanded(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (controller.settings.showTuner ||
                                        controller.settings.flashBeat) ...[
                                      SizedBox(
                                        width: 280,
                                        child: SingleChildScrollView(
                                          child: Column(
                                            children: [
                                              if (controller.settings.showTuner)
                                                TunerStrip(
                                                  controller: controller,
                                                ),
                                              if (controller
                                                      .settings
                                                      .showTuner &&
                                                  controller.settings.flashBeat)
                                                const SizedBox(height: 24),
                                              if (controller.settings.flashBeat)
                                                _BeatIndicator(
                                                  controller: controller,
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 24),
                                    ],
                                    Expanded(
                                      child: PitchGraph(controller: controller),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Expanded(
                                child: compact
                                    ? SingleChildScrollView(
                                        child: Column(
                                          children: [
                                            if (controller
                                                .settings
                                                .showTuner) ...[
                                              TunerStrip(
                                                controller: controller,
                                              ),
                                              const SizedBox(height: 8),
                                            ],
                                            SizedBox(
                                              height: 240,
                                              child: PitchGraph(
                                                controller: controller,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : Column(
                                        children: [
                                          if (controller
                                              .settings
                                              .showTuner) ...[
                                            TunerStrip(controller: controller),
                                            const SizedBox(height: 16),
                                          ],
                                          Expanded(
                                            child: PitchGraph(
                                              controller: controller,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            const SizedBox(height: 12),
                            if (!wide &&
                                !largeText &&
                                controller.settings.flashBeat) ...[
                              _BeatIndicator(controller: controller),
                              const SizedBox(height: 8),
                            ],
                            _Transport(controller: controller, tools: _tools()),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    ),
  );
  List<Widget> _tools() => [
    if (controller.settings.showHold)
      IconButton.filledTonal(
        tooltip: controller.held ? '继续图表' : '冻结图表',
        isSelected: controller.held,
        onPressed: controller.toggleHold,
        icon: Icon(controller.held ? Icons.lock : Icons.lock_open),
      ),
  ];
  void _showLibrary(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _RecordingLibrary(controller: controller),
    ),
  );
}

class _BeatIndicator extends StatelessWidget {
  const _BeatIndicator({required this.controller});
  final MonitorController controller;
  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        controller.settings.beatsPerBar == 0
            ? 1
            : controller.settings.beatsPerBar,
        (index) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:
                controller.beat == index &&
                    controller.beatPhase < .25 &&
                    !reduceMotion &&
                    (controller.isCapturing || controller.isPlaying)
                ? Color(controller.settings.metronomeColor)
                : AppColors.line,
          ),
        ),
      ),
    );
  }
}

class _Transport extends StatelessWidget {
  const _Transport({required this.controller, required this.tools});
  final MonitorController controller;
  final List<Widget> tools;
  @override
  Widget build(BuildContext context) {
    final seconds = controller.recordingSeconds.toInt();
    final recordingTime =
        '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          if (controller.hasPendingRecording)
            OutlinedButton(
              onPressed: controller.busy ? null : controller.retrySaveRecording,
              child: const Text('重试保存录音'),
            ),
          if (!controller.isCapturing)
            IconButton.filled(
              tooltip: '开始监听',
              onPressed: controller.busy ? null : controller.startListening,
              icon: const Icon(Icons.mic_none),
            ),
          if (controller.isCapturing)
            FilledButton.icon(
              onPressed: controller.busy ? null : controller.toggleRecording,
              style: controller.isRecording
                  ? FilledButton.styleFrom(
                      backgroundColor: const Color(0xffffb4ab),
                    )
                  : null,
              icon: Icon(
                controller.isRecording
                    ? Icons.save_outlined
                    : Icons.fiber_manual_record,
              ),
              label: Text(
                controller.isRecording ? recordingTime : '录音',
                semanticsLabel: controller.isRecording
                    ? '保存录音，已录制 $recordingTime'
                    : null,
                style: const TextStyle(
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          IconButton.filledTonal(
            tooltip: '停止',
            onPressed: controller.busy || controller.mode == MonitorMode.idle
                ? null
                : controller.stop,
            icon: const Icon(Icons.stop),
          ),
          IconButton.filledTonal(
            tooltip: controller.isPlaying ? '暂停回放' : '播放录音',
            onPressed:
                controller.busy || !controller.canPlay || controller.isRecording
                ? null
                : controller.togglePlayback,
            icon: Icon(controller.isPlaying ? Icons.pause : Icons.play_arrow),
          ),
          ...tools,
        ],
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({required this.controller});
  final MonitorController controller;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.only(left: 12),
    decoration: BoxDecoration(
      color: AppColors.raised,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            controller.message!,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
        ),
        IconButton(
          tooltip: '关闭提示',
          onPressed: controller.clearMessage,
          icon: const Icon(Icons.close, size: 18),
        ),
      ],
    ),
  );
}

class _RecordingLibrary extends StatelessWidget {
  const _RecordingLibrary({required this.controller});
  final MonitorController controller;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const Text('录音库'),
        actions: [
          IconButton(
            tooltip: '导入 WAV',
            onPressed: controller.busy ? null : controller.importRecording,
            icon: const Icon(Icons.file_open_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          if (controller.message != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: _MessageBanner(controller: controller),
            ),
          Expanded(
            child: controller.recordings.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        '还没有录音\n在监测页面录制，或导入 PCM 16 位 WAV',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.muted, height: 1.8),
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: controller.recordings.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, index) {
                      final entry = controller.recordings[index];
                      return ListTile(
                        leading: const Icon(Icons.audio_file_outlined),
                        title: Text(entry.name),
                        subtitle: Text(
                          '${entry.modified.toLocal().toString().substring(0, 16)} · ${(entry.size / 1024).round()} KB',
                        ),
                        selected:
                            controller.selectedRecording?.path == entry.path,
                        onTap: controller.busy
                            ? null
                            : () async {
                                await controller.selectRecording(entry);
                                if (context.mounted &&
                                    controller.selectedRecording?.path ==
                                        entry.path) {
                                  Navigator.pop(context);
                                }
                              },
                        trailing: IconButton(
                          tooltip: '删除录音',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: controller.busy
                              ? null
                              : () async {
                                  final remove = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('删除录音？'),
                                      content: Text(entry.name),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('取消'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text('删除'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (remove == true) {
                                    await controller.deleteRecording(entry);
                                  }
                                },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
  );
}
