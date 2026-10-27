import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const Color paperColor = Color(0xfffaf8f0);
const Color paperInk = Color(0xff1f2430);

/// يفتح رابط http/https خارج التطبيق. يرجع false عند الفشل.
Future<bool> openExternalUrl(String raw) async {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
    return false;
  }
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

void showMessage(BuildContext context, String text) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(content: Text(text)));
}
