class NetworkInvite {
  const NetworkInvite({
    required this.networkId,
    required this.appLink,
    required this.httpsLink,
  });

  final String networkId;
  final String appLink;
  final String httpsLink;

  String get qrData => httpsLink;
  String get shareText => 'Join my Maskan network:\n$httpsLink';

  @Deprecated('Use httpsLink.')
  String get compatibilityLink => httpsLink;

  @Deprecated('Use httpsLink.')
  String get webFallbackLink => httpsLink;
}

class InviteService {
  const InviteService();

  NetworkInvite createInvite(String networkId) {
    final encodedNetworkId = Uri.encodeComponent(networkId);
    return NetworkInvite(
      networkId: networkId,
      appLink: 'maskan://join/$encodedNetworkId',
      httpsLink:
          'https://karamixlabs.com/maskan/join?network=$encodedNetworkId',
    );
  }

  String? parseNetworkId(String link) {
    final uri = Uri.tryParse(link.trim());
    if (uri == null) return null;
    if (uri.scheme == 'maskan' && uri.host == 'join') {
      final networkId = uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
      return _cleanNetworkId(networkId);
    }
    if ((uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host == 'karamixlabs.com' &&
        uri.path == '/maskan/join') {
      return _cleanNetworkId(uri.queryParameters['network']);
    }
    return null;
  }

  String? _cleanNetworkId(String? networkId) {
    final trimmed = networkId?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
