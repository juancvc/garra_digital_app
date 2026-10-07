import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/garra_spacing.dart';
import '../../../core/design/garra_colors.dart';
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
    body: ListView(padding: const EdgeInsets.all(GarraSpacing.md), children: [
      const _GarraGuideHero(),
      const SizedBox(height: GarraSpacing.lg),
      _section(context, Icons.person_outline, 'Primeros pasos',
        'Completa tu perfil y elige tus intereses para encontrar gente y contenido que te importen.'),
      _section(context, Icons.explore_outlined, 'Inicio y Explorar',
        'En Inicio ves publicaciones. En Explorar encuentras personas y experiencias de Garra.'),
      _section(context, Icons.groups_outlined, 'Tribuna',
        'Comparte publicaciones, comenta y reacciona. En las comunidades también puedes conversar con otros hinchas.',
        route: '/comunidad', action: 'Ir a Comunidad'),
      _section(context, Icons.sports_soccer_outlined, 'Centro Garra',
        'Consulta partidos, resultados y tablas. Entra en un partido para ver su Tribuna y Chat Futbolero.',
        route: '/centro-garra', action: 'Ir a Centro Garra'),
      _section(context, Icons.storefront_outlined, 'Negocios y promociones',
        'Descubre negocios de la comunidad y sus ofertas. Si tienes un negocio, puedes solicitar registrarlo y gestionarlo.' ,
        route: '/negocios', action: 'Ver negocios'),
      _section(context, Icons.shopping_bag_outlined, 'Marketplace',
        'Solicita tu perfil vendedor. Garra lo revisa. Luego crea tu tienda o negocio; tras su aprobación, publica un producto. Revisamos las publicaciones antes de mostrarlas a la comunidad.',
        route: '/marketplace', action: 'Ir a Marketplace'),
      _section(context, Icons.favorite_border, 'Garra Solidaria',
        'Propón una iniciativa. Garra la revisa y, si se aprueba, la publica para que la comunidad contacte directamente. Garra no procesa dinero, donaciones ni pagos.',
        route: '/solidaria', action: 'Ver Garra Solidaria'),
      _section(context, Icons.add_circle_outline, 'Crear publicación',
        'Escribe lo que quieres compartir con la comunidad y, si quieres, agrega una foto.',
        route: '/comunidad/compose', action: 'Crear publicación'),
      _section(context, Icons.privacy_tip_outlined, 'Perfil y privacidad',
        'Actualiza tu perfil y revisa tus preferencias, términos y privacidad desde Ajustes.',
        route: '/settings', action: 'Abrir Ajustes'),
    ]),
  );

  Widget _section(BuildContext context, IconData icon, String title, String body,
      {String? route, String? action}) => Padding(
    padding: const EdgeInsets.only(bottom: GarraSpacing.sm),
    child: _GarraGuideCard(icon: icon, title: title, description: body,
      action: action, onAction: route == null ? null : () => context.push(route)),
  );
}

class _GarraGuideHero extends StatelessWidget {
  const _GarraGuideHero();

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(24),
    child: DecoratedBox(
      decoration: const BoxDecoration(color: Color(GarraColors.burgundyDeep)),
      child: Stack(children: [
        Positioned.fill(child: ExcludeSemantics(child: Image.asset(
          'assets/visual/garra_match_hero.png', fit: BoxFit.cover,
          cacheWidth: 960,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ))),
        const Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.centerLeft,
            end: Alignment.centerRight, colors: [
              Color(0xF00E0C0B), Color(0xC947101C), Color(0x770E0C0B),
            ]),
        ))),
        Padding(padding: const EdgeInsets.all(20), child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, children: [
              const Text('GUÍA DE LA HINCHADA', style: TextStyle(
                color: Color(GarraColors.gold), fontSize: 11,
                fontWeight: FontWeight.w800, letterSpacing: 1.6)),
              const SizedBox(height: 10),
              const Text('GARRA\nTE ENSEÑA\nGARRA',
                style: TextStyle(color: Color(GarraColors.cream),
                  fontWeight: FontWeight.w900, fontSize: 25, height: 1.05)),
              const SizedBox(height: 12),
              const Text('Descubre todo lo que puedes hacer en la app y vive el fútbol dentro y fuera de la cancha.',
                style: TextStyle(color: Color(GarraColors.cream), height: 1.35)),
            ])),
          const SizedBox(width: 10),
          ExcludeSemantics(child: ClipOval(child: Image.asset(
            'assets/brand/intro/garra_puma.png', width: 76, height: 76,
            cacheWidth: 152, fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ))),
        ])),
      ]),
    ),
  );
}

class _GarraGuideCard extends StatelessWidget {
  const _GarraGuideCard({required this.icon, required this.title,
    required this.description, this.action, this.onAction});
  final IconData icon;
  final String title;
  final String description;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(GarraColors.gold).withValues(alpha: .16)),
      gradient: const LinearGradient(colors: [Color(GarraColors.surfaceRaised),
        Color(GarraColors.surface), Color(GarraColors.burgundyDeep)]),
    ),
    child: Padding(padding: const EdgeInsets.all(15),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 44, height: 44,
          decoration: BoxDecoration(color: const Color(GarraColors.burgundy),
            borderRadius: BorderRadius.circular(13)),
          child: Icon(icon, color: const Color(GarraColors.cream))),
        const SizedBox(width: 13),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: const Color(GarraColors.cream), fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            Text(description, style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(GarraColors.creamMuted), height: 1.35)),
            if (action != null && onAction != null)
              Padding(padding: const EdgeInsets.only(top: 4),
                child: TextButton.icon(onPressed: onAction,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: Text(action!),
                  style: TextButton.styleFrom(foregroundColor: const Color(GarraColors.gold)))),
          ])),
      ]),
    ),
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
