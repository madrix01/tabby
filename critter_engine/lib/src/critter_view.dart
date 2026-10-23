import 'dart:ui' show ImageFilter, TileMode;

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'catalog.dart';
import 'composer.dart';
import 'spec.dart';

/// Draws one critter from a [spec]. Static for now (phase 2); the animation layer wraps these layers later.
///
/// Fills the width it is given at a fixed 4:3 aspect, feet near the bottom edge. Every critter shares
/// the same frame, so an evolved form renders bigger than a baby one at the same widget size.
/// Recomposes only when [spec] or [look] changes.
///
/// [look] overrides `spec.look`. [CritterLook.glow] adds shading, gloss, a contact shadow and a colour
/// halo (a blurred copy of the critter behind it); it reads best on a dark background.
class CritterView extends StatefulWidget {
  const CritterView({super.key, required this.catalog, required this.spec, this.look});

  final CritterCatalog catalog;
  final CritterSpec spec;
  final CritterLook? look;

  @override
  State<CritterView> createState() => _CritterViewState();
}

class _CritterViewState extends State<CritterView> {
  late CritterComposition? _comp = _compose();

  CritterComposition? _compose() => compose(widget.catalog, widget.spec, look: widget.look);

  @override
  void didUpdateWidget(CritterView old) {
    super.didUpdateWidget(old);
    if (old.spec != widget.spec || old.catalog != widget.catalog || old.look != widget.look) _comp = _compose();
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
          if (comp.look == CritterLook.glow)
            // halo: the critter itself, blurred and brightened, behind the sharp copy
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: box.maxWidth * .03, sigmaY: box.maxWidth * .03, tileMode: TileMode.decal),
              child: ColorFiltered(
                colorFilter: const ColorFilter.matrix([1.35, 0, 0, 0, 18, 0, 1.35, 0, 0, 18, 0, 0, 1.35, 0, 18, 0, 0, 0, .85, 0]),
                child: Stack(fit: StackFit.expand, children: [layer(comp.base), layer(comp.overlay)]),
              ),
            ),
          for (final svg in [comp.base, comp.eyes, comp.overlay, ?comp.prop]) layer(svg),
        ]),
      ),
    );
  }
}
