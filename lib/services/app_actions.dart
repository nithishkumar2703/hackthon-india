import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Helper functions to open links, calls, WhatsApp, email and share.
class AppActions {
  /// Open a website in the phone's browser.
  static Future<void> openWebsite(String url) async {
    if (url.isEmpty) return;
    final u = Uri.tryParse(url.startsWith('http') ? url : 'https://$url');
    if (u == null) return;
    final ok = await launchUrl(u, mode: LaunchMode.externalApplication);
    if (!ok) await launchUrl(u);
  }

  /// Compose an email to the organizer.
  static Future<void> emailOrganizer(String email) async {
    if (email.isEmpty) return;
    final u = Uri(scheme: 'mailto', path: email);
    await launchUrl(u, mode: LaunchMode.externalApplication);
  }

  /// Open a WhatsApp chat with the organizer.
  /// Phone must be stored as 91XXXXXXXXXX.
  static Future<void> openWhatsApp(String phone) async {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;
    final normalized = digits.length == 10 ? '91$digits' : digits;
    await launchUrl(
      Uri.parse('https://wa.me/$normalized'),
      mode: LaunchMode.externalApplication,
    );
  }

  /// Call the organizer's phone number.
  static Future<void> callOrganizer(String phone) async {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;
    await launchUrl(
      Uri.parse('tel:+$digits'),
      mode: LaunchMode.externalApplication,
    );
  }

  /// Share the hackathon with friends (WhatsApp, etc.).
  static Future<void> shareHackathon(String title, String url) async {
    await SharePlus.instance.share(
      '$title\n$url',
    );
  }
}
