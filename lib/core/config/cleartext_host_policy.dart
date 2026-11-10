/// Hosts onde o cliente aceita HTTP sem TLS.
///
/// Upstream só aceita HTTP em MagicDNS do Tailnet (`*.ts.net`). O fork iOS
/// acrescenta a rede doméstica: IPv4 privado (RFC 1918) e nomes mDNS
/// (`*.local`). O iOS deixa isso passar via `NSAllowsLocalNetworking` no ATS;
/// IPs públicos e o CGNAT do Tailscale (`100.64.0.0/10`) continuam exigindo
/// HTTPS, porque ali o tráfego pode sair da rede local.
bool isCleartextAllowedHost(String host) {
  final h = host.toLowerCase().replaceFirst(RegExp(r'\.$'), '');
  if (h.endsWith('.ts.net')) return true;
  return isLocalNetworkHost(h);
}

/// `true` para IPv4 privado (10/8, 172.16/12, 192.168/16) e `*.local`.
bool isLocalNetworkHost(String host) {
  final h = host.toLowerCase().replaceFirst(RegExp(r'\.$'), '');
  if (h.endsWith('.local') && h.length > '.local'.length) return true;
  final parts = h.split('.');
  if (parts.length != 4) return false;
  final octets = <int>[];
  for (final p in parts) {
    final n = int.tryParse(p);
    if (n == null || n < 0 || n > 255 || p.isEmpty || p.length > 3) {
      return false;
    }
    octets.add(n);
  }
  final a = octets[0];
  final b = octets[1];
  if (a == 10) return true;
  if (a == 172 && b >= 16 && b <= 31) return true;
  if (a == 192 && b == 168) return true;
  return false;
}
