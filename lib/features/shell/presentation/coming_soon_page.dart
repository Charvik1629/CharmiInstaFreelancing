import 'package:flutter/material.dart';

import '../../../core/widgets/widgets.dart';

/// Placeholder for bottom-nav tabs whose screens land in a later module
/// (Search, Marketplace, Chats, Profile). Kept honest — clearly a stub.
class ComingSoonPage extends StatelessWidget {
  const ComingSoonPage({super.key, required this.title, required this.icon, required this.module});

  final String title;
  final IconData icon;
  final String module;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: EmptyView(
        title: title,
        subtitle: 'This screen arrives in $module.',
        icon: icon,
      ),
    );
  }
}
