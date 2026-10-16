import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const rate = 44100;

void main() {
  Directory('assets/audio').createSync(recursive: true);
  writeWav('assets/audio/shot.wav', shot());
  writeWav('assets/audio/clear.wav', clear());
  writeWav('assets/audio/over.wav', over());
}

List<int> shot() {
  final n = (0.09 * rate).round();
  final rnd = Random(7);
  return List.generate(n, (i) {
    final t = i / rate;
    final env = exp(-t * 38);
    final click = i < rate * 0.012 ? (rnd.nextDouble() * 2 - 1) * 0.35 : 0.0;
    final tone = sin(2 * pi * 740 * t) * 0.42;
    return ((tone + click) * env * 32767).round();
  });
}

List<int> clear() {
  final n = (0.46 * rate).round();
  return List.generate(n, (i) {
    final t = i / rate;
    final attack = 1 - exp(-t * 45);
    final env = attack * exp(-t * 5.2);
    final s = sin(2 * pi * 523.25 * t) * 0.28 +
        sin(2 * pi * 659.25 * t) * 0.12 +
        sin(2 * pi * 783.99 * t) * 0.07;
    return (s * env * 32767).round();
  });
}

List<int> over() {
  final n = (0.48 * rate).round();
  return List.generate(n, (i) {
    final t = i / n;
    final freq = 230 + (96 - 230) * t;
    final env = (1 - t) * (1 - t);
    final s = sin(2 * pi * freq * i / rate) * 0.5 * env;
    return (s * 32767).round();
  });
}

List<int> tone(double seconds, double freq, {required double amp, required double decay}) {
  final n = (seconds * rate).round();
  return List.generate(n, (i) {
    final t = i / rate;
    final attack = min(1.0, i / (0.008 * rate));
    final s = sin(2 * pi * freq * t) * amp * attack * exp(-t * decay);
    return (s * 32767).round();
  });
}

void writeWav(String path, List<int> samples) {
  final pcm = BytesBuilder();
  for (final sample in samples) {
    final v = sample.clamp(-32767, 32767);
    pcm.addByte(v & 0xff);
    pcm.addByte((v >> 8) & 0xff);
  }
  final body = pcm.toBytes();
  final data = BytesBuilder();
  void ascii(String s) => data.add(s.codeUnits);
  void u16(int v) {
    data.addByte(v & 0xff);
    data.addByte((v >> 8) & 0xff);
  }

  void u32(int v) {
    data.addByte(v & 0xff);
    data.addByte((v >> 8) & 0xff);
    data.addByte((v >> 16) & 0xff);
    data.addByte((v >> 24) & 0xff);
  }

  ascii('RIFF');
  u32(36 + body.length);
  ascii('WAVE');
  ascii('fmt ');
  u32(16);
  u16(1);
  u16(1);
  u32(rate);
  u32(rate * 2);
  u16(2);
  u16(16);
  ascii('data');
  u32(body.length);
  data.add(body);
  File(path).writeAsBytesSync(data.toBytes());
}
