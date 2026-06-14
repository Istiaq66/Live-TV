// Generates the app-icon source PNGs used by flutter_launcher_icons.
//
//   dart run tool/gen_icon.dart
//   dart run flutter_launcher_icons
//
// Produces:
//   assets/icon/app_icon.png     1024² — green field + soccer ball (full bleed)
//   assets/icon/app_icon_fg.png  1024² — ball only, transparent (adaptive fg)
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const int size = 1024;
final green = img.ColorRgb8(0x1B, 0x5E, 0x20);
final greenLight = img.ColorRgb8(0x2E, 0x7D, 0x32);
final white = img.ColorRgb8(0xFF, 0xFF, 0xFF);
final black = img.ColorRgb8(0x14, 0x14, 0x14);

void main() {
  Directory('assets/icon').createSync(recursive: true);

  // Full icon: rounded green background + large ball.
  final full = img.Image(width: size, height: size, numChannels: 4);
  img.fill(full, color: img.ColorRgba8(0, 0, 0, 0));
  _verticalGradientRoundRect(full, radius: 180);
  _drawBall(full, size / 2, size / 2, size * 0.36);
  File('assets/icon/app_icon.png').writeAsBytesSync(img.encodePng(full));

  // Adaptive foreground: transparent, ball sized within the inner safe zone.
  final fg = img.Image(width: size, height: size, numChannels: 4);
  img.fill(fg, color: img.ColorRgba8(0, 0, 0, 0));
  _drawBall(fg, size / 2, size / 2, size * 0.30);
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

/// Classic black-and-white soccer ball: white disc, outline, centre pentagon,
/// five outer pentagons joined by seams.
void _drawBall(img.Image im, double cx, double cy, double r) {
  img.fillCircle(im, x: cx.round(), y: cy.round(), radius: r.round(), color: white);
  // Outline ring.
  for (var i = 0; i < 10; i++) {
    img.drawCircle(im, x: cx.round(), y: cy.round(), radius: r.round() - i, color: black);
  }

  final centre = _pentagon(cx, cy, r * 0.28, -math.pi / 2);
  // Outer pentagons + seams first (so the centre pentagon sits on top).
  for (var i = 0; i < 5; i++) {
    final a = -math.pi / 2 + i * 2 * math.pi / 5;
    final ox = cx + r * 0.62 * math.cos(a);
    final oy = cy + r * 0.62 * math.sin(a);
    // Seam from ball centre outward.
    img.drawLine(
      im,
      x1: cx.round(),
      y1: cy.round(),
      x2: (cx + r * math.cos(a)).round(),
      y2: (cy + r * math.sin(a)).round(),
      color: black,
      thickness: (r * 0.05).round(),
    );
    final outer = _pentagon(ox, oy, r * 0.20, a + math.pi);
    img.fillPolygon(im, vertices: outer, color: black);
  }
  img.fillPolygon(im, vertices: centre, color: black);
}

/// Five vertices of a regular pentagon centred at (cx,cy).
List<img.Point> _pentagon(double cx, double cy, double radius, double rot) {
  return [
    for (var i = 0; i < 5; i++)
      img.Point(
        cx + radius * math.cos(rot + i * 2 * math.pi / 5),
        cy + radius * math.sin(rot + i * 2 * math.pi / 5),
      ),
  ];
}

int _lerp(num a, num b, double t) => (a + (b - a) * t).round().clamp(0, 255);