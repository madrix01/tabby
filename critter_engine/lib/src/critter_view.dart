import 'dart:ui' show ImageFilter, TileMode;

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'catalog.dart';
import 'composer.dart';
import 'glow.dart';
import 'spec.dart';

/// Draws one critter from a [spec]. Static for now (phase 2); the animation layer wraps these layers later.
///
/// Fills the width it is given at a fixed 4:3 aspect, feet near the bottom edge. Every critter shares
/// the same frame, so an evolved form renders bigger than a baby one at the same widget size.
/// Recomposes only when [spec] or [look] changes.
///
/// [look] / [glow] override the spec's. [CritterLook.glow] adds shading, gloss, a contact shadow and a colour
/// halo (a blurred copy of the critter behind it), each tunable through [CritterGlow]; it reads best on a dark background.
class CritterView extends StatefulWidget {
  const CritterView({super.key, required this.catalog, required this.spec, this.look, this.glow});

  final CritterCatalog catalog;
  final CritterSpec spec;
  final CritterLook? look;
  final CritterGlow? glow;

  @override
  State<CritterView> createState() => _CritterViewState();
}

class _CritterViewState extends State<CritterView> {
  late CritterComposition? _comp = _compose();

  CritterComposition? _compose() => compose(widget.catalog, widget.spec, look: widget.look, glow: widget.glow);

  @override
  void didUpdateWidget(CritterView old) {
    super.didUpdateWidget(old);
    if (old.spec != widget.spec || old.catalog != widget.catalog || old.look != widget.look || old.glow != widget.glow) _comp = _compose();
  }

  @override
  Widget build(BuildContext context) {
    final vb = CritterComposition.viewBox;
    final comp = _comp;
    if (comp == null) return AspectRatio(aspectRatio: vb.width / vb.height);
    Widget layer(String svg) => SvgPicture.string(svg, fit: BoxFit.contain);
    return AspectRatio(
      aspectRatio: vb.width / vb.height,
      child: LayoutBuilder(
        builder: (context, box) => Stack(fit: StackFit.expand, children: [
          if (comp.look == CritterLook.glow && comp.glow.hasHalo)
            // halo: the critter itself, blurred and brightened (or tinted), behind the sharp copy
            ImageFiltered(
              imageFilter: ImageFilter.blur(
                  sigmaX: box.maxWidth * .03 * comp.glow.blur, sigmaY: box.maxWidth * .03 * comp.glow.blur, tileMode: TileMode.decal),
              child: ColorFiltered(
                colorFilter: ColorFilter.matrix(_haloMatrix(comp.glow)),
                child: Stack(fit: StackFit.expand, children: [layer(comp.base), layer(comp.overlay)]),
              ),
            ),
          for (final svg in [comp.base, comp.eyes, comp.overlay, ?comp.prop]) layer(svg),
        ]),
      ),
    );
  }
}

/// Brighten the critter's own colours, or paint everything in [CritterGlow.color]; alpha scaled by halo.
List<double> _haloMatrix(CritterGlow g) {
  final c = g.color;
  if (c != null) {
    final v = int.parse(c.substring(1), radix: 16);
    final r = ((v >> 16) & 255).toDouble(), gr = ((v >> 8) & 255).toDouble(), b = (v & 255).toDouble();
    return [0, 0, 0, 0, r, 0, 0, 0, 0, gr, 0, 0, 0, 0, b, 0, 0, 0, g.halo, 0];
  }
  final k = g.brightness, lift = (k - 1) * 51; // 1.35 -> +18, as before
  return [k, 0, 0, 0, lift, 0, k, 0, 0, lift, 0, 0, k, 0, lift, 0, 0, 0, g.halo, 0];
}
