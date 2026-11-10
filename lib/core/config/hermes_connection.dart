import 'cleartext_host_policy.dart';

/// Configuração de acesso do cliente nativo ao Hermes API Server.
///
/// A chave nunca é incluída no APK: ela é informada pelo dono do aparelho e
/// persistida somente no armazenamento seguro da plataforma.
class HermesConnection {
  const HermesConnection({required this.baseUrl, required this.apiKey});

  final String baseUrl;
  final String apiKey;

  String? validate() {
    final uri = Uri.tryParse(baseUrl);
    final scheme = uri?.scheme.toLowerCase();
    final ok =
        uri != null &&
        uri.hasAuthority &&
        (scheme == 'https' ||
            (scheme == 'http' && isLocalNetworkHost(uri.host)));
    if (!ok) {
      return 'Use uma URL HTTPS válida (ou HTTP na rede local) para o gateway.';
    }
    if (apiKey.trim().isEmpty) {
      return 'Informe a chave da API do Hermes.';
    }
    return null;
  }

  HermesConnection normalized() => HermesConnection(
    baseUrl: baseUrl.trim().replaceFirst(RegExp(r'/+$'), ''),
    apiKey: apiKey.trim(),
  );
}
