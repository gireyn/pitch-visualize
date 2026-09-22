// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get recordingLibrary => '录音库';

  @override
  String get moreOptions => '更多选项';

  @override
  String get showPitchHistory => '切换为音高曲线';

  @override
  String get showFftSpectrum => '切换为 FFT 频谱';

  @override
  String get settings => '设置';

  @override
  String get freezeResumeGraph => '冻结 / 继续图表';

  @override
  String get preparingMonitor => '正在准备音高监测器…';

  @override
  String get retry => '重试';

  @override
  String get resumeGraph => '继续图表';

  @override
  String get freezeGraph => '冻结图表';

  @override
  String get retrySaveRecording => '重试保存录音';

  @override
  String get startListening => '开始监听';

  @override
  String get record => '录音';

  @override
  String saveRecordingSemantics(String time) {
    return '保存录音，已录制 $time';
  }

  @override
  String get stop => '停止';

  @override
  String get pausePlayback => '暂停回放';

  @override
  String get playRecording => '播放录音';

  @override
  String get dismissMessage => '关闭提示';

  @override
  String get importWav => '导入 WAV';

  @override
  String get noRecordings => '还没有录音\n在监测页面录制，或导入 PCM 16 位 WAV';

  @override
  String get deleteRecording => '删除录音';

  @override
  String get deleteRecordingConfirmation => '删除录音？';

  @override
  String get cancel => '取消';

  @override
  String get delete => '删除';

  @override
  String get customScale => '自定义调律';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsTuning => '调律';

  @override
  String get settingsChooseTuning => '选择调律';

  @override
  String get settingsNoScaleSelected => '尚未选择';

  @override
  String get settingsPitchDetection => '音高检测';

  @override
  String get settingsVolumeThreshold => '音量阈值';

  @override
  String get settingsVolumeThresholdHint => '过滤轻微环境噪声；较低阈值可检测轻声';

  @override
  String get settingsEdoScale => 'EDO 刻度';

  @override
  String get settingsOctavesOnly => '仅八度';

  @override
  String get settingsEdoActiveHint => 'EDO 刻度生效；0 表示只显示八度刻度';

  @override
  String get settingsEdoInactiveHint => '当前优先使用调律配置。选择“使用 EDO 刻度”后生效；0 表示仅八度';

  @override
  String get settingsUseEdoScale => '使用 EDO 刻度';

  @override
  String get settingsUseOctavesOnlyDescription => '仅八度刻度 · 取消当前调律配置';

  @override
  String get settingsTunerSmoothing => '调音器平滑';

  @override
  String get settingsCharts => '图表';

  @override
  String get settingsFftSpectrum => 'FFT 频谱';

  @override
  String get settingsFftSpectrumHint => '对数频率纵轴、调律音名；关闭后显示音高曲线';

  @override
  String get settingsHorizontalZoom => '水平缩放';

  @override
  String get settingsVerticalZoom => '垂直缩放';

  @override
  String get settingsVerticalZoomHint => '也可在图表上双指竖直捏合或拉开';

  @override
  String get settingsScrollSpeed => '滚动速度';

  @override
  String get settingsAutoFollow => '自动跟随音域';

  @override
  String get settingsAutoFollowHint => '拖动或捏合图表会暂停跟随，可在图表中一键恢复';

  @override
  String get settingsShowTuner => '显示调音器刻度';

  @override
  String get settingsShowTunerHint => '显示音名刻度和当前音高指针，默认关闭';

  @override
  String get settingsBeat => '节拍';

  @override
  String get settingsTempo => '速度 BPM';

  @override
  String get settingsTimeSignature => '拍号';

  @override
  String get settingsNoTimeSignature => '无';

  @override
  String get settingsShowBeatLines => '显示节拍线';

  @override
  String get settingsVisualMetronome => '视觉节拍器';

  @override
  String get settingsVisualMetronomeHint => '用闪光指示节拍，不发出声音';

  @override
  String get settingsColors => '颜色';

  @override
  String get settingsPitchCurve => '音高曲线';

  @override
  String get settingsBeatLines => '节拍线';

  @override
  String get settingsScaleColorsHint => '使用调律文件时，音阶网格与音名的颜色由文件中的灰度值决定。';

  @override
  String get settingsQuickActions => '快捷操作';

  @override
  String get settingsShowFreeze => '显示冻结按钮';

  @override
  String get settingsAbout => '关于 PitchVisual';

  @override
  String get settingsOfflineMonitor => '离线音高监测 · Flutter';

  @override
  String get settingsAboutDescription =>
      'iOS 与 Android 使用同一套调律和音高算法。\n录音仅保存在此设备，最长 5 分钟。\n支持的输入：人声或单音乐器。';

  @override
  String get settingsOpenSourceLicenses => '开源许可';

  @override
  String get settingsDefaultTuningDescription => '默认 · 七等分八度';

  @override
  String get settingsImportTuning => '导入调律文件';

  @override
  String get settingsTuningFileFormat => 'xen-tuner 文本配置（.txt / .json）';

  @override
  String get settingsTuningImportHint => '调律会复制并保存在此设备。修改原文件后，请重新导入。';

  @override
  String get graphPitchRangeHint => '双指竖直拉开放大、捏合缩小，上下拖动调整音域；手动调整后暂停自动跟随。';

  @override
  String get graphNoPitch => '无音高';

  @override
  String get graphFrozen => '已冻结';

  @override
  String get graphResumeAutoFollow => '恢复自动跟随音域';

  @override
  String get graphRangeUp => '音域上移';

  @override
  String get graphRangeDown => '音域下移';

  @override
  String get graphSpectrumAxis => 'FFT · 音高 / log₂';

  @override
  String get graphSpectrumIntensity => '频谱强度：负90至0 dBFS';

  @override
  String get graphSpectrumEmpty => '开始监听，观察基频与泛音\n每个八度等高 · 亮度表示强度';

  @override
  String settingsEdoDivisions(int count) {
    return '$count 等分';
  }

  @override
  String settingsUseEdoDescription(int count) {
    return '$count 等分八度 · 取消当前调律配置';
  }

  @override
  String settingsCurrentTuning(String name, int count, String period) {
    return '当前：$name\n$count 个音 · 周期 $period 音分';
  }

  @override
  String graphCurrentTuning(String name) {
    return '当前调律：$name';
  }

  @override
  String graphTempo(int bpm) {
    return '速度：每分钟 $bpm 拍';
  }

  @override
  String graphPitchHistoryDescription(String note) {
    return '音高历史图。当前$note。纵轴为调律音名，横轴为时间。';
  }

  @override
  String graphDeviation(String cents) {
    return '偏差 $cents 音分';
  }

  @override
  String graphSpectrumDescription(String name) {
    return 'FFT 滚动频谱。纵轴为对数频率，以$name音高名标注，每个八度等高。横轴为时间，颜色从暗蓝到橙黄到白表示负90至0 dBFS。';
  }

  @override
  String get noticeTuningRestored => '已从缓存恢复调律';

  @override
  String get noticeSettingsRestored => '本地设置无法完整读取，已恢复默认调律';

  @override
  String noticeRecordingSaved(String name) {
    return '录音已保存：$name';
  }

  @override
  String noticeRecordingImported(String name) {
    return '已导入 $name';
  }

  @override
  String noticeScaleApplied(String name) {
    return '已应用 $name';
  }

  @override
  String get noticeAudioDeviceChanged => '音频设备已改变，录音已结束';

  @override
  String get noticePlaybackInterrupted => '回放已被系统中断，点击播放可继续';

  @override
  String get noticeAudioInterrupted => '音频已被系统中断，请点击开始继续';

  @override
  String get errorWavInvalidFile => 'WAV 文件为空、损坏或超过 64 MB';

  @override
  String get errorWavPcmRequired => '请选择未压缩的 PCM 16 位 WAV 文件';

  @override
  String get errorWavIncomplete => 'WAV 文件不完整';

  @override
  String get errorWavInvalidLength => 'WAV 数据长度无效';

  @override
  String get errorWavUnsupportedFormat => '仅支持 PCM 16 位 WAV，暂不支持压缩或浮点音频';

  @override
  String get errorWavIncompleteChunk => 'WAV 数据块不完整';

  @override
  String get errorWavInvalidAudio => 'WAV 采样率、声道或音频数据无效';

  @override
  String get errorRecordingTooLong => '录音最长支持 5 分钟';

  @override
  String get errorWavTooLarge => 'WAV 超过 64 MB';

  @override
  String get errorTuningTooLarge => '调律文件不能超过 1 MB';

  @override
  String get errorInvalidRecordingPath => '无效的录音路径';

  @override
  String get errorMicrophonePermission => '实时音高检测需要麦克风权限，请在系统设置中开启';

  @override
  String get errorRequestBusy => '另一个权限请求或文件选择器已打开';

  @override
  String get errorAppInactive => '请打开应用以使用麦克风';

  @override
  String get errorRequestCancelled => '请求已取消';

  @override
  String get errorCaptureFailed => '麦克风采集失败，请检查音频设备后重试';

  @override
  String get errorPlaybackFailed => '音频回放失败，请重新选择录音后重试';

  @override
  String get errorRecordingDecode => '无法解码录音文件';

  @override
  String get errorFileReadFailed => '无法读取所选文件';

  @override
  String errorDeviceDetails(String details) {
    return '设备操作失败：$details';
  }

  @override
  String errorInvalidFormat(String details) {
    return '文件格式无效：$details';
  }

  @override
  String errorFileOperation(String details) {
    return '文件操作失败：$details';
  }

  @override
  String errorUnexpected(String details) {
    return '操作失败：$details';
  }

  @override
  String get octaveScale => '八度刻度';

  @override
  String get errorAudioDevice => '音频设备出错';

  @override
  String get tianganScale => '天干音阶';

  @override
  String get errorTuningMissingLines => '调律文件需要包含参考音行和音高行';

  @override
  String get errorTuningInvalidReference => '参考音格式应为“C4: 261.63”';

  @override
  String errorTuningInvalidFrequency(String detail) {
    return '参考频率无效：$detail';
  }

  @override
  String get errorTuningMissingPitch => '调律文件至少需要一个音阶音高和一个周期音程';

  @override
  String get errorTuningTooManyNotes => '调律文件最多可包含 4096 个音符';

  @override
  String errorTuningInvalidPitch(String detail) {
    return '无法解析音高：$detail';
  }

  @override
  String get errorTuningZeroEquave => '周期音程不能为零';

  @override
  String errorTuningReferenceNotFound(String detail) {
    return '参考音“$detail”不在音阶中';
  }
}
