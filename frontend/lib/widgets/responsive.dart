import 'package:flutter/material.dart';

/// Inset adaptif: hasilnya IDENTIK dengan EdgeInsets biasa di HP
/// (lebar < maxWidth), dan menambah margin samping agar konten selebar
/// maxWidth serta rata tengah di tablet/landscape.
class ResponsiveInsets {
  static const double defaultMaxWidth = 640;

  static EdgeInsets only(
    BuildContext context, {
    double left = 0,
    double top = 0,
    double right = 0,
    double bottom = 0,
    double maxWidth = defaultMaxWidth,
  }) {
    final extra = (MediaQuery.sizeOf(context).width - maxWidth) / 2;
    if (extra <= 0) {
      return EdgeInsets.only(
          left: left, top: top, right: right, bottom: bottom);
    }
    return EdgeInsets.only(
      left: left + extra,
      top: top,
      right: right + extra,
      bottom: bottom,
    );
  }

  static EdgeInsets all(BuildContext context, double value,
          {double maxWidth = defaultMaxWidth}) =>
      only(context,
          left: value,
          top: value,
          right: value,
          bottom: value,
          maxWidth: maxWidth);

  static EdgeInsets symmetric(
    BuildContext context, {
    double horizontal = 0,
    double vertical = 0,
    double maxWidth = defaultMaxWidth,
  }) =>
      only(context,
          left: horizontal,
          top: vertical,
          right: horizontal,
          bottom: vertical,
          maxWidth: maxWidth);
}

/// Kolom grid adaptif: [mobile] di HP, [wide] di layar ≥ breakpoint.
class ResponsiveGrid {
  static int columns(BuildContext context,
          {int mobile = 2, int wide = 4, double breakpoint = 600}) =>
      MediaQuery.sizeOf(context).width >= breakpoint ? wide : mobile;
}
