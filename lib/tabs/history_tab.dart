import 'package:flutter/material.dart';

class HistoryTab extends StatelessWidget {
  const HistoryTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Text(
          'History - last actions (read, add, download, move, delete)',
        ),
      ),
    );
  }
}
