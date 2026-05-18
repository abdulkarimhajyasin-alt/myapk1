import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../l10n/app_localizations.dart';
import '../services/expense_network_repository.dart';
import '../services/invite_service.dart';
import '../services/session_repository.dart';
import 'join_network_screen.dart';

class ScanInviteScreen extends StatefulWidget {
  const ScanInviteScreen({
    required this.repository,
    required this.sessionRepository,
    super.key,
  });

  final ExpenseNetworkRepository repository;
  final SessionRepository sessionRepository;

  @override
  State<ScanInviteScreen> createState() => _ScanInviteScreenState();
}

class _ScanInviteScreenState extends State<ScanInviteScreen> {
  final MobileScannerController _controller = MobileScannerController();
  final InviteService _inviteService = const InviteService();
  bool _handledScan = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDetect(BarcodeCapture capture) {
    if (_handledScan) return;
    String? rawValue;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.trim().isNotEmpty) {
        rawValue = value;
        break;
      }
    }
    if (rawValue == null) return;

    final networkId = _inviteService.parseNetworkId(rawValue);
    if (networkId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.invalidInviteQr)),
      );
      return;
    }

    _handledScan = true;
    _controller.stop();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => JoinNetworkScreen(
          repository: widget.repository,
          sessionRepository: widget.sessionRepository,
          inviteNetworkId: networkId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.inviteScannerTitle)),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleDetect,
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black54, width: 36),
                ),
              ),
            ),
          ),
          Align(
            alignment: AlignmentDirectional.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
              color: colorScheme.surface.withValues(alpha: 0.92),
              child: Text(
                l10n.inviteScannerHint,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
