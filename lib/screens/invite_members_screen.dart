import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../services/invite_service.dart';
import '../widgets/app_scaffold.dart';

class InviteMembersScreen extends StatelessWidget {
  const InviteMembersScreen({
    required this.networkName,
    required this.networkId,
    super.key,
  });

  final String networkName;
  final String networkId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final invite = const InviteService().createInvite(networkId);

    return AppScaffold(
      title: l10n.inviteMembers,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    networkName,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.inviteInstructions,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: QrImageView(
                  data: invite.qrData,
                  version: QrVersions.auto,
                  size: 220,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            l10n.inviteLinkLabel,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 6),
          SelectableText(invite.httpsLink),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: invite.httpsLink));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.inviteCopied)),
              );
            },
            icon: const Icon(Icons.copy_rounded),
            label: Text(l10n.copyLink),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Share.share(
              '${l10n.joinMyMaskanNetwork}\n${invite.httpsLink}',
              subject: networkName,
            ),
            icon: const Icon(Icons.ios_share_rounded),
            label: Text(l10n.share),
          ),
        ],
      ),
    );
  }
}
