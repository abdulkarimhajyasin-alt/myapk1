import 'package:expense_network/services/invite_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('creates app and fallback invite links with QR data', () {
    final invite = const InviteService().createInvite('network_1');

    expect(invite.appLink, 'maskan://join/network_1');
    expect(
      invite.webFallbackLink,
      'https://karamixlabs.com/maskan/join?network=network_1',
    );
    expect(invite.qrData, invite.appLink);
  });

  test('parses supported invite links', () {
    const service = InviteService();

    expect(service.parseNetworkId('maskan://join/network_1'), 'network_1');
    expect(
      service.parseNetworkId(
        'https://karamixlabs.com/maskan/join?network=network_2',
      ),
      'network_2',
    );
    expect(service.parseNetworkId('https://example.com'), isNull);
  });
}
