import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/garra_spacing.dart';
import '../../../core/widgets/garra_card.dart';

class GarraHelpPage extends StatelessWidget {
  const GarraHelpPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ayuda y soporte')),
    body: ListView(padding: const EdgeInsets.all(GarraSpacing.lg), children: [
      const Text('Encuentra tu camino en Garra',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: GarraSpacing.md),
      _entry(context, 'Cómo usar Garra', 'Una guía corta para empezar y explorar.',
        Icons.explore_outlined, '/settings/help/guide'),
      _entry(context, 'Preguntas frecuentes', 'Respuestas a las dudas más comunes.',
        Icons.quiz_outlined, '/settings/help/faq'),
      _entry(context, 'Escríbenos', 'Dudas, sugerencias o problemas con Garra.',
        Icons.mail_outline, '/settings/feedback'),
      _entry(context, 'Términos y condiciones', 'Consulta los textos legales.',
        Icons.gavel_outlined, '/settings/legal'),
      _entry(context, 'Privacidad', 'Revisa tus datos y preferencias.',
        Icons.privacy_tip_outlined, '/settings/privacy'),
      _entry(context, 'Diagnóstico', 'Información técnica para resolver problemas.',
        Icons.info_outline, '/settings/help/diagnostics'),
    ]),
  );

  Widget _entry(BuildContext context, String title, String subtitle,
      IconData icon, String route) => Padding(
    padding: const EdgeInsets.only(bottom: GarraSpacing.sm),
    child: GarraCard(child: ListTile(
      leading: Icon(icon), title: Text(title), subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(route),
    )),
  );
}

class GarraGuidePage extends StatelessWidget {
  const GarraGuidePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Cómo usar Garra')),
    body: ListView(padding: const EdgeInsets.all(GarraSpacing.lg), children: [
      _section(context, 'Primeros pasos',
        'Completa tu perfil y elige tus intereses para encontrar gente y contenido que te importen.'),
      _section(context, 'Inicio y Explorar',
        'En Inicio ves publicaciones. En Explorar encuentras personas y experiencias de Garra.'),
      _section(context, 'Tribuna',
        'Comparte publicaciones, comenta y reacciona. En las comunidades también puedes conversar con otros hinchas.',
        route: '/comunidad', action: 'Ir a Comunidad'),
      _section(context, 'Centro Garra',
        'Consulta partidos, resultados y tablas. Entra en un partido para ver su Tribuna y Chat Futbolero.',
        route: '/centro-garra', action: 'Ir a Centro Garra'),
      _section(context, 'Negocios y promociones',
        'Descubre negocios de la comunidad y sus ofertas. Si tienes un negocio, puedes solicitar registrarlo y gestionarlo.' ,
        route: '/negocios', action: 'Ver negocios'),
      _section(context, 'Marketplace',
        'Solicita tu perfil vendedor. Garra lo revisa. Luego crea tu tienda o negocio; tras su aprobación, publica un producto. Revisamos las publicaciones antes de mostrarlas a la comunidad.',
        route: '/marketplace', action: 'Ir a Marketplace'),
      _section(context, 'Garra Solidaria',
        'Propón una iniciativa. Garra la revisa y, si se aprueba, la publica para que la comunidad contacte directamente. Garra no procesa dinero, donaciones ni pagos.',
        route: '/solidaria', action: 'Ver Garra Solidaria'),
      _section(context, 'Perfil y privacidad',
        'Actualiza tu perfil y revisa tus preferencias, términos y privacidad desde Ajustes.',
        route: '/settings', action: 'Abrir Ajustes'),
    ]),
  );

  Widget _section(BuildContext context, String title, String body,
      {String? route, String? action}) => Padding(
    padding: const EdgeInsets.only(bottom: GarraSpacing.md),
    child: GarraCard(child: Padding(
      padding: const EdgeInsets.all(GarraSpacing.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: GarraSpacing.sm),
        Text(body),
        if (route != null && action != null)
          TextButton(onPressed: () => context.push(route), child: Text(action)),
      ]),
    )),
  );
}

class GarraFaqPage extends StatelessWidget {
  const GarraFaqPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Preguntas frecuentes')),
    body: ListView(padding: const EdgeInsets.all(GarraSpacing.lg), children: const [
      _Question('¿Por qué mi negocio está en revisión?',
        'Garra revisa las solicitudes antes de mostrar negocios a la comunidad.'),
      _Question('¿Por qué mi producto todavía no aparece?',
        'Los productos se revisan antes de publicarse. Puedes consultar su estado en tu espacio de vendedor.'),
      _Question('¿Cómo publico en Marketplace?',
        'Solicita el perfil vendedor y espera la aprobación. Después crea una tienda y publica tu producto. La tienda y el producto también pasan por revisión.'),
      _Question('¿Cómo funciona Garra Solidaria?',
        'Propón una iniciativa. Si Garra la aprueba, la comunidad podrá verla y contactarte directamente.'),
      _Question('¿Garra recibe dinero en Solidaria?',
        'No. Garra no procesa dinero, donaciones ni pagos.'),
      _Question('¿Dónde reviso privacidad y términos?',
        'En Ajustes encontrarás Privacidad y Legal y privacidad.'),
    ]),
  );
}

class _Question extends StatelessWidget {
  const _Question(this.question, this.answer);
  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(title: Text(question), childrenPadding: const EdgeInsets.all(16),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [Text(answer)]),
  );
}
