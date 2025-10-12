import 'package:flutter/material.dart';

class UpdatesTab extends StatelessWidget {
  const UpdatesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Text('Updates - works with lastSyncDate updated/hasUpdate flag'),
      ),
    );
  }
}
