import 'package:flutter/material.dart';

import '../../../../core/widgets/widgets.dart';

/// "Status" tab (design). 24h stories shared with contacts, with ads interleaved.
/// The backend for this does not exist yet (see BACKEND_REQUIREMENTS D1 —
/// `GET/POST /stories`), so the tab shows a "coming soon" state for now.
class StatusPage extends StatelessWidget {
  const StatusPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Status')),
      body: const EmptyView(
        title: 'Coming soon',
        subtitle:
            'Share 24-hour photo and video updates with your contacts. This lands '
            'once the backend supports stories.',
        icon: Icons.motion_photos_on_outlined,
      ),
    );
  }
}
