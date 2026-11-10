# Hermes Mobile para iOS

Este fork (`farrulla-darze/hermes-mobile-ios`) mantém a versão iOS do
[Hermes Mobile](https://github.com/M1gue11/hermes-mobile). O código Flutter é o
mesmo do upstream; o fork acrescenta o alvo iOS pronto para uso, CI que gera
o IPA e sincronização automática com o upstream.

## O que muda em relação ao upstream

| Área | Mudança |
| --- | --- |
| Identidade | Bundle id `com.farrulladarze.hermesmobile`, nome "Hermes", ícone e launch screen do Hermes (gerados a partir da arte Android por `tools/ios/generate_ios_assets.py`). |
| Rede | ATS com `NSAllowsLocalNetworking` + `NSLocalNetworkUsageDescription`; o app aceita HTTP para IPv4 privado (RFC 1918) e `*.local`, além de HTTPS e `*.ts.net` (`lib/core/config/cleartext_host_policy.dart`). |
| Sistema | Deep link `hermes://app/chat/<id>`, `UIBackgroundModes=audio` (ler em voz alta com a tela bloqueada), microfone, `ITSAppUsesNonExemptEncryption=false`, `Podfile` iOS 13. |
| CI | `.github/workflows/ios.yml`: analyze + testes + `flutter build ios --no-codesign` em `macos-15`, IPA não assinado como artefato; tag `ios-v*` publica uma release. |
| Upstream | `.github/workflows/sync-upstream.yml`: todo dia faz merge de `M1gue11/hermes-mobile@main` num PR `upstream-sync` e dispara o build iOS; conflito vira issue. |

## Instalar no iPhone (Apple ID gratuito)

Sem conta paga de desenvolvedor a assinatura vale **7 dias**; depois é preciso
reassinar (mesmo processo, os dados do app são mantidos).

1. Baixe `HermesMobile-unsigned.ipa` da última release
   (`gh release download --repo farrulla-darze/hermes-mobile-ios --pattern '*.ipa'`)
   ou do artefato do último run do workflow *iOS build*.
2. Instale o [Sideloadly](https://sideloadly.io) no Mac, conecte o iPhone por
   cabo e toque em *Confiar neste computador*.
3. No Sideloadly: arraste o IPA, informe o Apple ID e clique *Start*. A senha
   é digitada por você no Sideloadly (use uma senha de app se tiver 2FA
   com chave de segurança).
4. No iPhone:
   - *Ajustes > Privacidade e Segurança > Modo de Desenvolvedor* → ativar e
     reiniciar (só na primeira vez).
   - *Ajustes > Geral > VPN e Gerenciamento de Dispositivo* → confiar no
     certificado do seu Apple ID.
5. Abra o app "Hermes". Na primeira conexão o iOS pede acesso à **rede local**:
   permita.

Para renovar a cada 7 dias: abra o Sideloadly com o iPhone conectado (ou na
mesma rede Wi-Fi com "Wi-Fi sync" ligado) e repita o passo 3. O Sideloadly
também tem *Auto refresh*.

## Servidor Hermes na rede de casa

O app precisa de dois acessos ao Hermes: o **API Server** (Bearer token,
porta 8642) e o **Dashboard** (usuário/senha, porta 9119). No Mac que roda o
Hermes, num Terminal comum (fora de um chat do Hermes, porque o gateway é
reiniciado):

```sh
tools/ios/hermes-lan-server.sh
```

O script gera chave e senha (se ainda não existirem), sobe o dashboard como
LaunchAgent `ai.hermes.dashboard-lan`, reinicia o gateway e grava as
credenciais em `~/.hermes/hermes-mobile-ios-credentials.txt` (modo 600).

No app, preencha:

| Campo | Valor |
| --- | --- |
| URL HTTPS | `http://<ip-do-mac>:8642` |
| Chave da API | `API key` do arquivo de credenciais |
| URL do Dashboard | `http://<ip-do-mac>:9119` |
| Usuário / Senha do Dashboard | do arquivo de credenciais |

Dica: dê ao Mac um IP fixo (reserva DHCP no roteador) para a URL não mudar.
Fora de casa use Tailscale (`https://<maquina>.<tailnet>.ts.net`), que o app
já suporta.

## Build local (opcional)

Precisa de macOS com Xcode compatível com a versão do iOS do aparelho e
Flutter 3.44.x:

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter test
flutter run -d <iphone>          # assinatura: abra ios/Runner.xcworkspace e escolha seu Team
```

## Manutenção

- Upstream novo: revise e faça merge do PR `Sync upstream hermes-mobile`
  depois que o *iOS build* passar.
- Nova versão para o iPhone: `git tag ios-v1.0.1 && git push origin ios-v1.0.1`
  gera a release com o IPA; reassine com o Sideloadly.
- Arte nova no upstream: `uv run --with pillow tools/ios/generate_ios_assets.py`.
