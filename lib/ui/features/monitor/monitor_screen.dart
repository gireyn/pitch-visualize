import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
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
                'Pitch Visual',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: context.l10n.recordingLibrary,
            icon: const Icon(Icons.library_music_outlined),
            onPressed: controller.initialized
                ? () => _showLibrary(context)
                : null,
          ),
          IconButton(
            tooltip: context.l10n.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SettingsScreen(controller: controller),
              ),
            ),
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
                    Text(
                      controller.message?.resolve(context.l10n) ??
                          context.l10n.preparingMonitor,
                    ),
                    if (!controller.busy)
                      TextButton(
                        onPressed: controller.initialize,
                        child: Text(context.l10n.retry),
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
                            if (controller.analyzingRecording)
                              const _RecordingAnalysisStatus(),
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
                            _Transport(
                              controller: controller,
                              tools: _tools(context),
                            ),
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
  List<Widget> _tools(BuildContext context) => [
    IconButton.filledTonal(
      tooltip: controller.settings.showSpectrum
          ? context.l10n.showPitchHistory
          : context.l10n.showFftSpectrum,
      isSelected: controller.settings.showSpectrum,
      onPressed: () => controller.updateSetting(
        'showSpectrum',
        !controller.settings.showSpectrum,
      ),
      icon: const Icon(Icons.show_chart),
      selectedIcon: const Icon(Icons.graphic_eq),
    ),
    if (controller.settings.showHold)
      IconButton.filledTonal(
        tooltip: controller.held
            ? context.l10n.resumeGraph
            : context.l10n.freezeGraph,
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
    // When idle, resume the source shown by the graph rather than a recording
    // that may still be selected from an earlier session.
    final startsListening =
        controller.mode == MonitorMode.idle && !controller.hasRecordingOverview;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          if (controller.hasPendingRecording)
            OutlinedButton(
              onPressed: controller.busy ? null : controller.retrySaveRecording,
              child: Text(context.l10n.retrySaveRecording),
            ),
          if (!controller.isCapturing && !startsListening)
            IconButton.filled(
              tooltip: context.l10n.startListening,
              onPressed: controller.busy ? null : controller.startListening,
              icon: const Icon(Icons.mic_none),
            ),
          if (controller.isRecording)
            FilledButton.icon(
              onPressed: controller.busy ? null : controller.toggleRecording,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xffffb4ab),
              ),
              icon: const Icon(Icons.save_outlined),
              label: Text(
                recordingTime,
                semanticsLabel: context.l10n.saveRecordingSemantics(
                  recordingTime,
                ),
                style: const TextStyle(
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            )
          else if (controller.isCapturing)
            IconButton.filled(
              tooltip: context.l10n.record,
              onPressed: controller.busy ? null : controller.toggleRecording,
              icon: const Icon(Icons.fiber_manual_record),
            ),
          IconButton.filledTonal(
            tooltip: context.l10n.stop,
            onPressed: controller.busy || controller.mode == MonitorMode.idle
                ? null
                : controller.stop,
            icon: const Icon(Icons.stop),
          ),
          IconButton.filledTonal(
            tooltip: startsListening
                ? context.l10n.startListening
                : controller.isPlaying
                ? context.l10n.pausePlayback
                : context.l10n.playRecording,
            onPressed:
                controller.busy ||
                    controller.isRecording ||
                    (!startsListening && !controller.canPlay)
                ? null
                : startsListening
                ? controller.startListening
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
            controller.message!.resolve(context.l10n),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
        ),
        IconButton(
          tooltip: context.l10n.dismissMessage,
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
        title: Text(context.l10n.recordingLibrary),
        actions: [
          IconButton(
            tooltip: context.l10n.importWav,
            onPressed: controller.busy ? null : controller.importRecording,
            icon: const Icon(Icons.file_open_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          if (controller.analyzingRecording) const _RecordingAnalysisStatus(),
          if (controller.message != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: _MessageBanner(controller: controller),
            ),
          Expanded(
            child: controller.recordings.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        context.l10n.noRecordings,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.muted,
                          height: 1.8,
                        ),
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
                          tooltip: context.l10n.deleteRecording,
                          icon: const Icon(Icons.delete_outline),
                          onPressed: controller.busy
                              ? null
                              : () async {
                                  final remove = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text(
                                        context
                                            .l10n
                                            .deleteRecordingConfirmation,
                                      ),
                                      content: Text(entry.name),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: Text(context.l10n.cancel),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: Text(context.l10n.delete),
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

class _RecordingAnalysisStatus extends StatelessWidget {
  const _RecordingAnalysisStatus();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12),
    child: Semantics(
      liveRegion: true,
      child: Row(
        children: [
          const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(context.l10n.analyzingRecording)),
        ],
      ),
    ),
  );
}
