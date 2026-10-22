import 'dart:ui' as ui;

/// Top of the score, pause button, and timer.
///
/// Phones without a cutout keep the old 24px margin. A notch or Dynamic
/// Island reports its height as [statusBarInset], and the HUD sits 8px under
/// that so the score is not sliced in half.
double playHudTop(double statusBarInset) {
  final cleared = statusBarInset + 8;
  return cleared < 24 ? 24 : cleared;
}

double statusBarInset() {
  final views = ui.PlatformDispatcher.instance.views;
  if (views.isEmpty) return 0;
  final view = views.first;
  final ratio = view.devicePixelRatio <= 0 ? 1.0 : view.devicePixelRatio;
  return view.padding.top / ratio;
}
