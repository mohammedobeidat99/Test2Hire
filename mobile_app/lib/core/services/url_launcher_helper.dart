import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_colors.dart';

class UrlLauncherHelper {
  /// Robustly launches any web or file URL on mobile devices, with emulator host
  /// mapping (10.0.2.2 for localhost) and automatic clipboard copy fallback.
  static Future<bool> openUrl(
    BuildContext context,
    String urlString, {
    String? successMessage,
  }) async {
    final rawUrl = urlString.trim();
    if (rawUrl.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No URL link available to open (لا يوجد رابط متاح للفتح).'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      return false;
    }

    // Determine target URIs (original and Android emulator fallback if localhost)
    final candidateUrls = <String>[rawUrl];
    if (!kIsWeb && Platform.isAndroid && rawUrl.contains('localhost:3001')) {
      candidateUrls.add(rawUrl.replaceAll('localhost:3001', '10.0.2.2:3001'));
    }

    bool launched = false;

    for (final candidate in candidateUrls) {
      final uri = Uri.tryParse(candidate);
      if (uri == null) continue;

      // 1. Try external application (default browser / system PDF viewer)
      try {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (launched) break;
      } catch (_) {}

      // 2. Try platform default
      if (!launched) {
        try {
          launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
          if (launched) break;
        } catch (_) {}
      }

      // 3. Try in-app browser view
      if (!launched) {
        try {
          launched = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
          if (launched) break;
        } catch (_) {}
      }
    }

    if (launched) {
      if (successMessage != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      // Guaranteed fallback: Copy URL to clipboard so the user can easily open it on PC or browser
      await Clipboard.setData(ClipboardData(text: rawUrl));
      if (context.mounted) {
        final isExam = rawUrl.contains('/exam/');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isExam
                ? 'تم نسخ رابط الامتحان إلى الحافظة! افتحه في متصفح الكمبيوتر:\n$rawUrl'
                : 'تم نسخ الرابط إلى الحافظة:\n$rawUrl',
            ),
            backgroundColor: AppColors.primary,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'حسناً',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    }

    return launched;
  }
}
