import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'catalog.dart';
import 'composer.dart';
import 'spec.dart';

/// Draws one critter from a [spec]. Static for now (phase 2); the animation layer wraps these layers later.
///
/// Fills the width it is given at a fixed 4:3 aspect, feet near the bottom edge. Every critter shares
/// the same frame, so an evolved form renders bigger than a baby one at the same widget size.
/// Recomposes only when [spec] changes.
class CritterView extends StatefulWidget {
  const CritterView({super.key, required this.catalog, required this.spec});

  final CritterCatalog catalog;
  final CritterSpec spec;

  @override
  State<CritterView> createState() => _CritterViewState();
}

class _CritterViewState extends State<CritterView> {
  late CritterComposition? _comp = compose(widget.catalog, widget.spec);

  @override
  void didUpdateWidget(CritterView old) {
    super.didUpdateWidget(old);
    if (old.spec != widget.spec || old.catalog != widget.catalog) _comp = compose(widget.catalog, widget.spec);
  }

  @override
  Widget build(BuildContext context) {
    final vb = CritterComposition.viewBox;
    final comp = _comp;
    return AspectRatio(
      aspectRatio: vb.width / vb.height,
      child: comp == null
          ? const SizedBox.shrink()
          : Stack(fit: StackFit.expand, children: [
              for (final layer in [comp.base, comp.eyes, comp.overlay, ?comp.prop])
                SvgPicture.string(layer, fit: BoxFit.contain),
            ]),
    );
  }
}
