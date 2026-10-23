/// Renders critters from a JSON spec using the catalog compiled by `../compiler`.
library;

export 'src/catalog.dart';
export 'src/composer.dart';
export 'src/critter_view.dart';
export 'src/glow.dart';
export 'src/growth.dart' show levelOf, xpForLevel, formScale;
export 'src/item.dart';
export 'src/money_transfer.dart' show MoneyTransferView, formatIndian;
export 'src/mood.dart' show CritterMood;
export 'src/placement.dart' show placeItem, place;
export 'src/spec.dart';
