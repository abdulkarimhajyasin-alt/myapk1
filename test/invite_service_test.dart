import 'package:expense_network/services/invite_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('creates app invite link as QR data without promoting website fallback',
      () {
    final invite = const InviteService().createInvite('network_1');

    expect(invite.appLink, 'maskan://join/network_1');
    expect(
      invite.webFallbackLink,
      'https://karamixlabs.com/maskan/join?network=network_1',
    );
    expect(invite.qrData, invite.appLink);
    expect(invite.shareText, contains('Install Maskan first'));
    expect(invite.shareText, contains(invite.appLink));
    expect(invite.shareText, isNot(contains(invite.webFallbackLink)));
  });

  test('encodes network ids for invite links', () {
    final invite = const InviteService().createInvite('network 1/arabic');

    expect(invite.appLink, 'maskan://join/network%201%2Farabic');
    expect(
      const InviteService().parseNetworkId(invite.appLink),
      'network 1/arabic',
    );
  });

  test('parses supported invite and deep link formats', () {
    const service = InviteService();

    expect(service.parseNetworkId('maskan://join/network_1'), 'network_1');
    expect(
      service.parseNetworkId(
        'https://karamixlabs.com/maskan/join?network=network_2',
      ),
      'network_2',
    );
    expect(service.parseNetworkId('https://example.com'), isNull);
    expect(service.parseNetworkId('maskan://open/network_1'), isNull);
    expect(service.parseNetworkId('not a link'), isNull);
  });
}
