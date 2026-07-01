import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'logging.dart';

/// A viewer for the retained [errorHistory]: the user can review recent errors
/// (they survive the transient SnackBar) and copy them all into a bug report --
/// on-device observability for a build with no remote crash sink.
class ErrorLogDialog extends StatelessWidget {
  const ErrorLogDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final entries = errorHistory.reversed.toList(); // newest first
    return AlertDialog(
      title: const Text('Recent errors'),
      content: SizedBox(
        width: 400,
        child: entries.isEmpty
            ? const Text('No errors recorded.')
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final e in entries)
                    ListTile(
                      dense: true,
                      title: Text(e.message),
                      subtitle: e.detail == null ? null : Text(e.detail!),
                    ),
                ],
              ),
      ),
      actions: [
        if (entries.isNotEmpty)
          TextButton(
            onPressed: () => unawaited(
              Clipboard.setData(
                ClipboardData(
                  text: entries.map((e) => e.clipboardText).join('\n\n'),
                ),
              ),
            ),
            child: const Text('Copy all'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
