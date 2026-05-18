class NetworkInvite {
  const NetworkInvite({
    required this.networkId,
    required this.appLink,
    required this.webFallbackLink,
  });

  final String networkId;
  final String appLink;
  final String webFallbackLink;

  String get qrData => appLink;
}

class InviteService {
  const InviteService();

  NetworkInvite createInvite(String networkId) {
    return NetworkInvite(
      networkId: networkId,
      appLink: 'maskan://join/$networkId',
      webFallbackLink: 'https://karamixlabs.com/maskan/join?network=$networkId',
    );
  }

  String? parseNetworkId(String link) {
    final uri = Uri.tryParse(link.trim());
    if (uri == null) return null;
    if (uri.scheme == 'maskan' && uri.host == 'join') {
      return uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
    }
    if ((uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host == 'karamixlabs.com' &&
        uri.path == '/maskan/join') {
      return uri.queryParameters['network'];
    }
    return null;
  }
}
