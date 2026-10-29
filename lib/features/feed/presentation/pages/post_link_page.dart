import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/models/load.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/repositories/feed_repository.dart';
import 'post_detail_page.dart';

/// Entry point for an inbound post deep link — `post://posts/{id}` or the web
/// App Link `https://nexveero.com/p/{id}` — so a shared post opens inside the
/// app instead of the browser. Fetches the post by id (`GET /loads/{id}`) and
/// shows its detail; on failure it offers a retry or a jump to the feed.
class PostLinkPage extends StatefulWidget {
  const PostLinkPage({super.key, required this.id});

  final int id;

  @override
  State<PostLinkPage> createState() => _PostLinkPageState();
}

class _PostLinkPageState extends State<PostLinkPage> {
  late Future<Result<Load>> _future;

  @override
  void initState() {
    super.initState();
    _future = sl<FeedRepository>().getLoad(widget.id);
  }

  void _reload() => setState(() {
        _future = sl<FeedRepository>().getLoad(widget.id);
      });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Result<Load>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: LoadingView());
        }
        final result = snapshot.data;
        if (result case Success(value: final load)) {
          return PostDetailPage(load: load);
        }
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go(AppRoutes.feed),
            ),
          ),
          body: ErrorView(
            message: result?.failureOrNull?.message ?? 'Post not found',
            onRetry: _reload,
          ),
        );
      },
    );
  }
}
