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
    required this.isCloudMode,
    super.key,
  });

  final String networkName;
  final String networkId;
  final bool isCloudMode;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final invite = const InviteService().createInvite(networkId);

    return AppScaffold(
      title: l10n.inviteMembers,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            networkName,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          if (!isCloudMode) ...[
            const SizedBox(height: 10),
            Text(
              l10n.cloudInviteRequired,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 18),
          Center(
            child: QrImageView(
              data: invite.qrData,
              version: QrVersions.auto,
              size: 220,
            ),
          ),
          const SizedBox(height: 18),
          SelectableText(invite.appLink),
          const SizedBox(height: 8),
          SelectableText(invite.webFallbackLink),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: invite.appLink));
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
              '${invite.appLink}\n${invite.webFallbackLink}',
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
