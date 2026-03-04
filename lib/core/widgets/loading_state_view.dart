import 'package:flutter/material.dart';

class LoadingStateView extends StatelessWidget {
  const LoadingStateView({
    super.key,
    this.message = 'Yukleniyor...',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(message),
        ],
      ),
    );
  }
}
