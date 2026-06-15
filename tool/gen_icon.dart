// Generates the app-icon source PNGs used by flutter_launcher_icons.
//
//   dart run tool/gen_icon.dart
//   dart run flutter_launcher_icons
//
// Produces:
//   assets/icon/app_icon.png     1024² — green field + TV/live glyph (full bleed)
//   assets/icon/app_icon_fg.png  1024² — TV only, transparent (adaptive fg)
import 'dart:io';

import 'package:image/image.dart' as img;

const int size = 1024;
final green = img.ColorRgb8(0x1B, 0x5E, 0x20);
final greenLight = img.ColorRgb8(0x2E, 0x7D, 0x32);
final white = img.ColorRgb8(0xFF, 0xFF, 0xFF);
final screenDark = img.ColorRgb8(0x10, 0x2A, 0x14);
final red = img.ColorRgb8(0xFF, 0x45, 0x57); // "live" accent

void main() {
  Directory('assets/icon').createSync(recursive: true);

  // Full icon: rounded green background + TV glyph.
  final full = img.Image(width: size, height: size, numChannels: 4);
  img.fill(full, color: img.ColorRgba8(0, 0, 0, 0));
  _verticalGradientRoundRect(full, radius: 180);
  _drawTv(full, size / 2, size * 0.54, size * 0.62);
  File('assets/icon/app_icon.png').writeAsBytesSync(img.encodePng(full));

  // Adaptive foreground: transparent, TV sized within the inner safe zone.
  final fg = img.Image(width: size, height: size, numChannels: 4);
  img.fill(fg, color: img.ColorRgba8(0, 0, 0, 0));
  _drawTv(fg, size / 2, size * 0.52, size * 0.52);
  File('assets/icon/app_icon_fg.png').writeAsBytesSync(img.encodePng(fg));

  stdout.writeln('Wrote assets/icon/app_icon.png + app_icon_fg.png');
}

/// Rounded square filled with a vertical green gradient.
void _verticalGradientRoundRect(img.Image im, {required int radius}) {
  for (var y = 0; y < size; y++) {
    final t = y / size;
    final c = img.ColorRgb8(
      _lerp(greenLight.r, green.r, t),
      _lerp(greenLight.g, green.g, t),
      _lerp(greenLight.b, green.b, t),
    );
    img.drawLine(im, x1: 0, y1: y, x2: size - 1, y2: y, color: c);
  }
  // Knock out the corners to fake a rounded rect (transparent outside radius).
  final clear = img.ColorRgba8(0, 0, 0, 0);
  void corner(int cx, int cy, int sx, int sy) {
    for (var dy = 0; dy < radius; dy++) {
      for (var dx = 0; dx < radius; dx++) {
        final px = cx + sx * dx, py = cy + sy * dy;
        if (dx * dx + dy * dy > radius * radius) {
          im.setPixel(px, py, clear);
        }
      }
    }
  }

  corner(radius, radius, -1, -1);
  corner(size - 1 - radius, radius, 1, -1);
  corner(radius, size - 1 - radius, -1, 1);
  corner(size - 1 - radius, size - 1 - radius, 1, 1);
}

/// A television set with two antennas and a red "play/live" triangle on a dark
/// screen. [w] is the body width; height follows a 4:3-ish ratio.
void _drawTv(img.Image im, double cx, double cy, double w) {
  final h = w * 0.74;
  final left = cx - w / 2, top = cy - h / 2;
  final right = left + w, bottom = top + h;
  final t = (w * 0.045).round(); // antenna / stroke thickness

  // Antennas: V from a point above the set down to the top edge.
  final apexX = cx.round();
  final apexY = (top - h * 0.34).round();
  img.drawLine(im, x1: apexX, y1: apexY,
      x2: (cx - w * 0.20).round(), y2: top.round(), color: white, thickness: t);
  img.drawLine(im, x1: apexX, y1: apexY,
      x2: (cx + w * 0.20).round(), y2: top.round(), color: white, thickness: t);
  img.fillCircle(im, x: apexX, y: apexY, radius: (w * 0.04).round(), color: white);

  // TV body (white) with rounded corners knocked out, then dark screen inset.
  final bodyR = (w * 0.10).round();
  _roundRect(im, left.round(), top.round(), right.round(), bottom.round(),
      bodyR, white);

  final inset = w * 0.085;
  final sL = (left + inset).round(), sT = (top + inset).round();
  final sR = (right - inset).round(), sB = (bottom - inset).round();
  _roundRect(im, sL, sT, sR, sB, (w * 0.05).round(), screenDark);

  // Centred "play" triangle (points right) = live video.
  final tri = w * 0.13;
  final tcx = cx, tcy = cy;
  img.fillPolygon(im, vertices: [
    img.Point(tcx - tri * 0.55, tcy - tri),
    img.Point(tcx - tri * 0.55, tcy + tri),
    img.Point(tcx + tri * 0.95, tcy),
  ], color: red);
}

/// Filled rounded rectangle (axis-aligned).
void _roundRect(img.Image im, int x1, int y1, int x2, int y2, int r,
    img.Color color) {
  img.fillRect(im, x1: x1 + r, y1: y1, x2: x2 - r, y2: y2, color: color);
  img.fillRect(im, x1: x1, y1: y1 + r, x2: x2, y2: y2 - r, color: color);
  img.fillCircle(im, x: x1 + r, y: y1 + r, radius: r, color: color);
  img.fillCircle(im, x: x2 - r, y: y1 + r, radius: r, color: color);
  img.fillCircle(im, x: x1 + r, y: y2 - r, radius: r, color: color);
  img.fillCircle(im, x: x2 - r, y: y2 - r, radius: r, color: color);
}

int _lerp(num a, num b, double t) => (a + (b - a) * t).round().clamp(0, 255);