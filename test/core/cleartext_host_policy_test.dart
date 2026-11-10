import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/config/cleartext_host_policy.dart';
import 'package:hermes_mobile/core/config/hermes_connection.dart';
import 'package:hermes_mobile/data/gateway/dashboard_gateway_repository.dart';

void main() {
  test('private LAN IPv4 and mDNS hosts are local network', () {
    for (final host in [
      '192.168.15.5',
      '10.0.0.2',
      '172.16.0.1',
      '172.31.255.255',
      'macbook.local',
    ]) {
      expect(isLocalNetworkHost(host), isTrue, reason: host);
    }
  });

  test('public, CGNAT and malformed hosts are not local network', () {
    for (final host in [
      '100.64.0.1',
      '100.0.0.1',
      '8.8.8.8',
      '172.32.0.1',
      '192.169.0.1',
      'example.com',
      '.local',
      '192.168.1',
      '192.168.1.256',
    ]) {
      expect(isLocalNetworkHost(host), isFalse, reason: host);
    }
  });

  test('API server accepts HTTP only on the local network', () {
    String? check(String url) =>
        HermesConnection(baseUrl: url, apiKey: 'k').validate();
    expect(check('http://192.168.15.5:8642'), isNull);
    expect(check('https://hermes.example.ts.net'), isNull);
    expect(check('http://100.64.0.1:8642'), isNotNull);
    expect(check('http://example.com:8642'), isNotNull);
  });

  test('dashboard accepts HTTP on Tailnet and local network', () {
    expect(
      DashboardGatewayRepository.supportsBaseUrl('http://192.168.15.5:9119'),
      isTrue,
    );
    expect(
      DashboardGatewayRepository.supportsBaseUrl('http://mac.local:9119'),
      isTrue,
    );
    expect(
      DashboardGatewayRepository.supportsBaseUrl('http://100.64.0.1:9119'),
      isFalse,
    );
  });
}
