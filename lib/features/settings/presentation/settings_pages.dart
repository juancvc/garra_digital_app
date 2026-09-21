import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/api_config.dart';
import '../../../core/config/app_config_service.dart';
import '../../../core/design/garra_colors.dart';
import '../../../core/design/garra_spacing.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/garra_error.dart';
import '../../../core/telemetry/telemetry.dart';
import '../../../core/widgets/garra_card.dart';
import '../../../core/widgets/garra_ui.dart';
import '../../auth/data/auth_service.dart';

class SettingsHubPage extends StatelessWidget {
  const SettingsHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(GarraSpacing.lg),
        children: [
          _tile(
            context,
            title: 'Privacidad',
            subtitle: 'Consentimientos y datos',
            icon: Icons.privacy_tip_outlined,
            route: '/settings/privacy',
          ),
          _tile(
            context,
            title: 'Legal y privacidad',
            subtitle: 'Políticas, términos y normas',
            icon: Icons.gavel_outlined,
            route: '/settings/legal',
          ),
          _tile(
            context,
            title: 'Ayuda',
            subtitle: 'Diagnóstico y feedback beta',
            icon: Icons.help_outline,
            route: '/settings/help',
          ),
          const SizedBox(height: GarraSpacing.xl),
          GarraSecondaryButton(
            label: 'Cerrar sesión',
            onPressed: () async {
              await AuthService().logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required String route,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: GarraSpacing.sm),
      child: GarraCard(
        child: ListTile(
          leading: Icon(icon, color: const Color(GarraColors.gold)),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(route),
        ),
      ),
    );
  }
}

class PrivacySettingsPage extends StatefulWidget {
  const PrivacySettingsPage({super.key});

  @override
  State<PrivacySettingsPage> createState() => _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends State<PrivacySettingsPage> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await privacyConsentStore.load();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(title: const Text('Privacidad')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(GarraSpacing.lg),
              children: [
                const Text(
                  'Essential services',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                SwitchListTile(
                  title: const Text('Servicios esenciales'),
                  subtitle: const Text(
                    'Autenticación, API y notificaciones operativas. Necesarios para usar Garra.',
                  ),
                  value: true,
                  onChanged: null,
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('Analytics'),
                  subtitle: const Text(
                    'Métricas de producto agregadas. Opt-in explícito en beta.',
                  ),
                  value: privacyConsentStore.analyticsEnabled,
                  onChanged: (v) async {
                    await privacyConsentStore.setAnalytics(v);
                    setState(() {});
                  },
                ),
                SwitchListTile(
                  title: const Text('Diagnostics'),
                  subtitle: const Text(
                    'Reportes de fallos (Crashlytics). Opt-in explícito en beta.',
                  ),
                  value: privacyConsentStore.diagnosticsEnabled,
                  onChanged: (v) async {
                    await privacyConsentStore.setDiagnostics(v);
                    setState(() {});
                  },
                ),
                const SizedBox(height: GarraSpacing.lg),
                GarraSecondaryButton(
                  label: 'Descargar mis datos',
                  onPressed: () => context.push('/settings/data-export'),
                ),
                const SizedBox(height: GarraSpacing.sm),
                GarraSecondaryButton(
                  label: 'Eliminar mi cuenta',
                  onPressed: () => context.push('/settings/delete-account'),
                ),
              ],
            ),
    );
  }
}

class LegalSettingsPage extends StatelessWidget {
  const LegalSettingsPage({super.key});

  Uri _resolve(String? pathOrUrl) {
    if (pathOrUrl == null || pathOrUrl.isEmpty) {
      return Uri.parse(ApiConfig.baseUrl.replaceAll('/api/v1', '/legal/privacy'));
    }
    if (pathOrUrl.startsWith('http')) return Uri.parse(pathOrUrl);
    final root = ApiConfig.baseUrl.replaceAll(RegExp(r'/api/v1/?$'), '');
    return Uri.parse('$root$pathOrUrl');
  }

  Future<void> _open(String? url) async {
    final uri = _resolve(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final cfg = appConfigService.current;
    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(title: const Text('Legal y privacidad')),
      body: ListView(
        padding: const EdgeInsets.all(GarraSpacing.lg),
        children: [
          ListTile(
            title: const Text('Política de privacidad'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => _open(cfg.privacyUrl ?? '/legal/privacy'),
          ),
          ListTile(
            title: const Text('Términos'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => _open(cfg.termsUrl ?? '/legal/terms'),
          ),
          ListTile(
            title: const Text('Normas de comunidad'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => _open('/legal/community'),
          ),
          ListTile(
            title: const Text('Eliminar cuenta'),
            onTap: () => context.push('/settings/delete-account'),
          ),
          ListTile(
            title: const Text('Exportar mis datos'),
            onTap: () => context.push('/settings/data-export'),
          ),
        ],
      ),
    );
  }
}

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _confirm() async {
    if (_controller.text.trim() != 'ELIMINAR') {
      setState(() => _error = 'Escribe ELIMINAR para confirmar.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await DioClient.instance.post('/me/account-deletion');
      await AuthService().logout();
      if (mounted) context.go('/login');
    } catch (e) {
      final info = classifyDioError(e);
      setState(() => _error = info.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(title: const Text('Eliminar mi cuenta')),
      body: Padding(
        padding: const EdgeInsets.all(GarraSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Esta acción desactiva tu cuenta, revoca sesiones y anonimiza datos identificables. '
              'No se puede deshacer fácilmente.',
            ),
            const SizedBox(height: GarraSpacing.lg),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Escribe ELIMINAR',
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            if (_error != null) ...[
              const SizedBox(height: GarraSpacing.sm),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
            const Spacer(),
            GarraPrimaryButton(
              label: _busy ? 'Procesando…' : 'Eliminar definitivamente',
              onPressed: _busy ? null : _confirm,
            ),
          ],
        ),
      ),
    );
  }
}

class DataExportPage extends StatefulWidget {
  const DataExportPage({super.key});

  @override
  State<DataExportPage> createState() => _DataExportPageState();
}

class _DataExportPageState extends State<DataExportPage> {
  bool _busy = false;
  String? _error;

  Future<void> _export() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await DioClient.instance.get('/me/data-export');
      final data = response.data['data'] ?? response.data;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/garra_data_export.json');
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(data),
      );
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: 'Mis datos Garra'),
      );
    } catch (e) {
      setState(() => _error = classifyDioError(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(title: const Text('Descargar mis datos')),
      body: Padding(
        padding: const EdgeInsets.all(GarraSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Exportamos un JSON acotado con tus datos personales y actividad propia. '
              'No incluye información privada de otros usuarios.',
            ),
            if (_error != null) ...[
              const SizedBox(height: GarraSpacing.sm),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
            const Spacer(),
            GarraPrimaryButton(
              label: _busy ? 'Preparando…' : 'Descargar / compartir',
              onPressed: _busy ? null : _export,
            ),
          ],
        ),
      ),
    );
  }
}

class HelpDiagnosticsPage extends StatefulWidget {
  const HelpDiagnosticsPage({super.key});

  @override
  State<HelpDiagnosticsPage> createState() => _HelpDiagnosticsPageState();
}

class _HelpDiagnosticsPageState extends State<HelpDiagnosticsPage> {
  String _diag = 'Cargando…';

  @override
  void initState() {
    super.initState();
    _build();
  }

  Future<void> _build() async {
    final info = await PackageInfo.fromPlatform();
    final buf = StringBuffer()
      ..writeln('appVersion=${info.version}')
      ..writeln('buildNumber=${info.buildNumber}')
      ..writeln('environment=${appConfigService.current.environment}')
      ..writeln('apiHost=${Uri.tryParse(ApiConfig.baseUrl)?.host}')
      ..writeln('lastCorrelationId=${DioClient.lastCorrelationId ?? 'n/a'}')
      ..writeln('os=${Platform.operatingSystem} ${Platform.operatingSystemVersion}')
      ..writeln('pushPermission=unknown')
      ..writeln('maps=configured');
    try {
      await DioClient.instance.get('/app-config');
      buf.writeln('apiConnectivity=ok');
    } on DioException catch (e) {
      buf.writeln('apiConnectivity=fail status=${e.response?.statusCode}');
    } catch (_) {
      buf.writeln('apiConnectivity=fail');
    }
    if (mounted) setState(() => _diag = buf.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(title: const Text('Diagnóstico')),
      body: Padding(
        padding: const EdgeInsets.all(GarraSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(
                  _diag,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
              ),
            ),
            GarraPrimaryButton(
              label: 'Copiar diagnóstico',
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: _diag));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Diagnóstico copiado')),
                  );
                }
              },
            ),
            const SizedBox(height: GarraSpacing.sm),
            GarraSecondaryButton(
              label: 'Enviar feedback beta',
              onPressed: () => context.push('/settings/feedback'),
            ),
          ],
        ),
      ),
    );
  }
}

class BetaFeedbackPage extends StatefulWidget {
  const BetaFeedbackPage({super.key});

  @override
  State<BetaFeedbackPage> createState() => _BetaFeedbackPageState();
}

class _BetaFeedbackPageState extends State<BetaFeedbackPage> {
  String _type = 'Bug';
  final _message = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _send() async {
    if (_message.text.trim().isEmpty) {
      setState(() => _error = 'Escribe un mensaje.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final info = await PackageInfo.fromPlatform();
      await DioClient.instance.post('/me/beta-feedback', data: {
        'type': _type,
        'message': _message.text.trim(),
        'screen': 'settings/feedback',
        'appVersion': '${info.version}+${info.buildNumber}',
        'correlationId': DioClient.lastCorrelationId,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gracias. Feedback enviado.')),
        );
        context.pop();
      }
    } catch (e) {
      setState(() => _error = classifyDioError(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(GarraColors.charcoal),
      appBar: AppBar(title: const Text('Feedback Beta')),
      body: Padding(
        padding: const EdgeInsets.all(GarraSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _type,
              items: const [
                DropdownMenuItem(value: 'Bug', child: Text('Bug')),
                DropdownMenuItem(value: 'Idea', child: Text('Idea')),
                DropdownMenuItem(value: 'Otro', child: Text('Otro')),
              ],
              onChanged: (v) => setState(() => _type = v ?? 'Bug'),
              decoration: const InputDecoration(labelText: 'Tipo'),
            ),
            const SizedBox(height: GarraSpacing.md),
            TextField(
              controller: _message,
              maxLines: 6,
              maxLength: 2000,
              decoration: const InputDecoration(
                labelText: 'Mensaje',
                alignLabelWithHint: true,
              ),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            const Spacer(),
            GarraPrimaryButton(
              label: _busy ? 'Enviando…' : 'Enviar',
              onPressed: _busy ? null : _send,
            ),
          ],
        ),
      ),
    );
  }
}
