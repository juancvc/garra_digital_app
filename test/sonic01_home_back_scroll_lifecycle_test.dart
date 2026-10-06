import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garra_digital_app/core/navigation/home_back_scroll.dart';

/// SONIC_01: a Home list that attaches in initState and detaches in dispose,
/// exactly like SocialFeedTab and the Home match list.
class _HomeList extends ConsumerStatefulWidget {
  const _HomeList({super.key});

  @override
  ConsumerState<_HomeList> createState() => _HomeListState();
}

class _HomeListState extends ConsumerState<_HomeList> {
  final controller = ScrollController();
  late final HomeBackScroll _scroll;

  @override
  void initState() {
    super.initState();
    _scroll = ref.read(homeBackScrollProvider.notifier);
    _scroll.attach(controller);
  }

  @override
  void dispose() {
    _scroll.detach(controller);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView.builder(
    controller: controller,
    itemCount: 60,
    itemBuilder: (_, i) => SizedBox(height: 60, child: Text('Fila $i')),
  );
}

class _Host extends StatefulWidget {
  const _Host();

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  int generation = 0;
  bool showList = true;

  @override
  Widget build(BuildContext context) => Column(children: [
    // Like MainShell: watches the provider while lists come and go.
    Consumer(builder: (_, ref, _) =>
        Text(ref.watch(homeBackScrollProvider) ? 'SCROLLED' : 'TOP')),
    TextButton(onPressed: () => setState(() => showList = !showList),
        child: const Text('toggle')),
    TextButton(onPressed: () => setState(() => generation++),
        child: const Text('replace')),
    Expanded(child: showList
        ? _HomeList(key: ValueKey(generation))
        : const Text('OTRA PESTAÑA')),
  ]);
}

void main() {
  testWidgets('disposing a scrolled Home list does not modify the provider during build',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: Scaffold(body: _Host()))));
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('SCROLLED'), findsOneWidget);

    // Unmounting the list (tab switch / Home rebuild / logout) runs dispose ->
    // detach inside the frame. Before SONIC_01 this threw
    // "Tried to modify a provider while the widget tree was building".
    await tester.tap(find.text('toggle'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pump();
    expect(find.text('OTRA PESTAÑA'), findsOneWidget);
    expect(find.text('TOP'), findsOneWidget);
  });

  testWidgets('replacing the list keeps Back state coherent with the new controller',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: Scaffold(body: _Host()))));
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('SCROLLED'), findsOneWidget);

    // New list attaches in initState while the old one detaches in dispose.
    await tester.tap(find.text('replace'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('TOP'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('SCROLLED'), findsOneWidget);
  });
}
