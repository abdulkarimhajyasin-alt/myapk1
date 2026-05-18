import 'package:expense_network/services/invite_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('creates HTTPS invite link as QR and share payload', () {
    final invite = const InviteService().createInvite('network_1');

    expect(invite.appLink, 'maskan://join/network_1');
    expect(
      invite.httpsLink,
      'https://karamixlabs.com/maskan/join?network=network_1',
    );
    expect(invite.qrData, invite.httpsLink);
    expect(invite.shareText, startsWith('Join my Maskan network:'));
    expect(invite.shareText, contains(invite.httpsLink));
    expect(invite.shareText, isNot(contains(invite.appLink)));
  });

  test('encodes network ids for invite links', () {
    final invite = const InviteService().createInvite('network 1/arabic');

    expect(invite.appLink, 'maskan://join/network%201%2Farabic');
    expect(
      invite.httpsLink,
      'https://karamixlabs.com/maskan/join?network=network%201%2Farabic',
    );
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
