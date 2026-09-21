import 'dart:typed_data';

/// Bounded, uncompressed mono PCM16 audio shared by both platforms.
class WaveData {
  WaveData({required this.pcm, required this.sampleRate});
  final Uint8List pcm;
  final int sampleRate;
  double get durationSeconds => pcm.length / (sampleRate * 2);
  static const maxSeconds = 300;
  static const maxFileBytes = 64 * 1024 * 1024;

  factory WaveData.decode(Uint8List bytes) {
    if (bytes.length < 44 || bytes.length > maxFileBytes) {
      throw const FormatException('WAV 文件为空、损坏或超过 64 MB');
    }
    final data = ByteData.sublistView(bytes);
    String tag(int offset) =>
        String.fromCharCodes(bytes.sublist(offset, offset + 4));
    if (tag(0) != 'RIFF' || tag(8) != 'WAVE') {
      throw const FormatException('请选择未压缩的 PCM 16 位 WAV 文件');
    }
    final end = data.getUint32(4, Endian.little) + 8;
    if (end > bytes.length || end < 12) {
      throw const FormatException('WAV 文件不完整');
    }
    int? rate, channels, blockAlign;
    Uint8List? samples;
    var offset = 12;
    for (; offset + 8 <= end;) {
      final length = data.getUint32(offset + 4, Endian.little);
      final start = offset + 8;
      if (length + (length & 1) > end - start) {
        throw const FormatException('WAV 数据长度无效');
      }
      if (tag(offset) == 'fmt ') {
        if (length < 16 ||
            data.getUint16(start, Endian.little) != 1 ||
            data.getUint16(start + 14, Endian.little) != 16) {
          throw const FormatException('仅支持 PCM 16 位 WAV，暂不支持压缩或浮点音频');
        }
        channels = data.getUint16(start + 2, Endian.little);
        rate = data.getUint32(start + 4, Endian.little);
        blockAlign = data.getUint16(start + 12, Endian.little);
      } else if (tag(offset) == 'data') {
        samples = Uint8List.sublistView(bytes, start, start + length);
      }
      offset = start + length + (length & 1);
    }
    if (offset != end) throw const FormatException('WAV 数据块不完整');
    if (rate == null ||
        rate < 8000 ||
        rate > 192000 ||
        channels == null ||
        (channels != 1 && channels != 2) ||
        blockAlign != channels * 2 ||
        samples == null ||
        samples.isEmpty ||
        samples.length % (channels * 2) != 0) {
      throw const FormatException('WAV 采样率、声道或音频数据无效');
    }
    if (samples.length / (rate * channels * 2) > maxSeconds) {
      throw const FormatException('录音最长支持 5 分钟');
    }
    if (channels == 1) {
      return WaveData(pcm: Uint8List.fromList(samples), sampleRate: rate);
    }
    final input = ByteData.sublistView(samples);
    final output = Uint8List(samples.length ~/ 2);
    final mono = ByteData.sublistView(output);
    for (var i = 0; i < samples.length; i += 4) {
      mono.setInt16(
        i ~/ 2,
        (input.getInt16(i, Endian.little) +
                input.getInt16(i + 2, Endian.little)) ~/
            2,
        Endian.little,
      );
    }
    return WaveData(pcm: output, sampleRate: rate);
  }

  Uint8List encode() {
    final bytes = Uint8List(44 + pcm.length);
    final data = ByteData.sublistView(bytes);
    void tag(int offset, String text) =>
        bytes.setRange(offset, offset + 4, text.codeUnits);
    tag(0, 'RIFF');
    tag(8, 'WAVE');
    tag(12, 'fmt ');
    tag(36, 'data');
    data.setUint32(4, bytes.length - 8, Endian.little);
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, 1, Endian.little);
    data.setUint32(24, sampleRate, Endian.little);
    data.setUint32(28, sampleRate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    data.setUint32(40, pcm.length, Endian.little);
    bytes.setRange(44, bytes.length, pcm);
    return bytes;
  }
}
