import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../state/app_info.dart';

/// Shows the bundled privacy policy (assets/legal/privacy_policy.md), the
/// same text that is published at [kPrivacyPolicyUrl], so it works offline.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Privacy Policy"),
        actions: [
          IconButton(
            tooltip: "Open in browser",
            icon: const Icon(Icons.open_in_new),
            onPressed: () => launchUrl(
              Uri.parse(kPrivacyPolicyUrl),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ],
      ),
      body: FutureBuilder<String>(
        future: rootBundle.loadString('assets/legal/privacy_policy.md'),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return SelectionArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: _render(context, snapshot.data!),
            ),
          );
        },
      ),
    );
  }

  /// Renders the small Markdown subset the policy uses: #/## headings,
  /// "- " bullets, **bold** and paragraphs.
  List<Widget> _render(BuildContext context, String markdown) {
    final theme = Theme.of(context).textTheme;
    final widgets = <Widget>[];

    for (final block in markdown.split(RegExp(r'\n\s*\n'))) {
      final lines = block.trim().split('\n');
      if (lines.first.isEmpty) continue;

      if (lines.first.startsWith('# ')) {
        widgets.add(Text(lines.first.substring(2), style: theme.headlineSmall));
      } else if (lines.first.startsWith('## ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(lines.first.substring(3), style: theme.titleLarge),
          ),
        );
      } else if (lines.every((l) => l.startsWith('- '))) {
        for (final l in lines) {
          widgets.add(
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("•  "),
                  Expanded(child: _richText(l.substring(2))),
                ],
              ),
            ),
          );
        }
      } else {
        widgets.add(_richText(lines.join(' ')));
      }
      widgets.add(const SizedBox(height: 12));
    }
    return widgets;
  }

  Widget _richText(String text) {
    final parts = text.split('**');
    return Text.rich(
      TextSpan(
        children: [
          for (int i = 0; i < parts.length; i++)
            TextSpan(
              text: parts[i],
              style: i.isOdd
                  ? const TextStyle(fontWeight: FontWeight.bold)
                  : null,
            ),
        ],
      ),
    );
  }
}
