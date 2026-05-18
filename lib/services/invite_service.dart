class NetworkInvite {
  const NetworkInvite({
    required this.networkId,
    required this.appLink,
    required this.compatibilityLink,
  });

  final String networkId;
  final String appLink;
  final String compatibilityLink;

  String get qrData => appLink;
  String get shareText =>
      'Install Maskan first, then open this invite:\n$appLink';

  @Deprecated('Use compatibilityLink only for parsing existing links.')
  String get webFallbackLink => compatibilityLink;
}

class InviteService {
  const InviteService();

  NetworkInvite createInvite(String networkId) {
    final encodedNetworkId = Uri.encodeComponent(networkId);
    return NetworkInvite(
      networkId: networkId,
      appLink: 'maskan://join/$encodedNetworkId',
      compatibilityLink:
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
