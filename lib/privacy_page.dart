part of 'main.dart';

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 36,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SimpleHeader(
                      title: 'Privacy',
                      onBack: () => context.go(AppRoutes.home),
                    ),
                    const SizedBox(height: 34),
                    Text(
                      'Privacy',
                      style: text.displayMedium?.copyWith(color: AppColors.ink),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Updated July 3, 2026',
                      style: editorialKicker(color: AppColors.accent),
                    ),
                    const SizedBox(height: 28),
                    const Divider(color: AppColors.ink, thickness: 1.5),
                    const SizedBox(height: 28),
                    const _PrivacySection(
                      title: 'FIBS connection',
                      body:
                          'When you create an account or log in, your FIBS '
                          'username, password, commands, and server replies '
                          'pass through '
                          'proxy.playfibs.com so this browser app can reach '
                          'fibs.com:4321. The proxy bridges the connection and '
                          'records operational counts only. It does not log or '
                          'store raw FIBS traffic, passwords, chat, emails, '
                          'hostnames, or game commands.',
                    ),
                    const _PrivacySection(
                      title: 'Stored credentials',
                      body:
                          'If you choose Remember me, your credentials stay in '
                          'this browser using the app credential store. Logout '
                          'clears the remembered credentials for this app.',
                    ),
                    const _PrivacySection(
                      title: 'Analytics',
                      body:
                          'The public build sends sanitized app events to the '
                          'proxy analytics endpoint. Events include the '
                          'screen, '
                          'mode, app version, platform, and counts such as how '
                          'many FIBS rows or bots were visible. They do not '
                          'include usernames, passwords, raw FIBS messages, '
                          'chat, emails, hostnames, or game commands.',
                    ),
                    const _PrivacySection(
                      title: 'Hosting and errors',
                      body:
                          'Firebase Hosting serves the web app. Cloudflare '
                          'runs the FIBS proxy and analytics endpoint. The '
                          'playfibs.com build does not enable remote crash '
                          'reporting; errors are shown locally in the app.',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrivacySection extends StatelessWidget {
  const _PrivacySection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: text.headlineSmall),
          const SizedBox(height: 8),
          Text(
            body,
            style: text.bodyLarge?.copyWith(
              color: AppColors.inkSoft,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _SimpleHeader extends StatelessWidget {
  const _SimpleHeader({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        tooltip: 'Back',
        icon: const Icon(Icons.arrow_back),
        onPressed: onBack,
      ),
      const SizedBox(width: 8),
      Text(title, style: Theme.of(context).textTheme.headlineSmall),
    ],
  );
}
