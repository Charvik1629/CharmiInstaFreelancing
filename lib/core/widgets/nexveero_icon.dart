import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Renders a bundled Material Symbols outline SVG from the design handoff
/// (`assets/icons/outline/<name>.svg`) tinted to [color] (defaults to the
/// ambient [IconTheme]). Use this when a design-exact SVG glyph is needed;
/// Flutter's built-in `Icons.*` render the same symbols for everyday use.
class NexveeroIcon extends StatelessWidget {
  const NexveeroIcon(this.name, {super.key, this.size = 24, this.color});

  final String name;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? IconTheme.of(context).color;
    return SvgPicture.asset(
      'assets/icons/outline/$name.svg',
      width: size,
      height: size,
      colorFilter:
          resolved == null ? null : ColorFilter.mode(resolved, BlendMode.srcIn),
      semanticsLabel: name,
    );
  }
}

/// Names of every bundled outline icon, so references are typo-safe.
class NexveeroIcons {
  NexveeroIcons._();
  static const bolt = 'bolt';
  static const home = 'home';
  static const search = 'search';
  static const storefront = 'storefront';
  static const chatBubble = 'chat_bubble';
  static const person = 'person';
  static const addBox = 'add_box';
  static const notifications = 'notifications';
  static const settings = 'settings';
  static const sell = 'sell';
  static const flag = 'flag';
  static const share = 'ios_share';
  static const help = 'help_outline';
  static const rocket = 'rocket_launch';
  static const verified = 'verified';
  static const wallet = 'account_balance_wallet';
  // …113 icons available under assets/icons/outline/. Add names as used.
}
