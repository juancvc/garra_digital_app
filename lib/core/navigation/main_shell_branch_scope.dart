import 'package:flutter/widgets.dart';

/// PRODUCT-03B-1: lets embedded chat pause polling when another main tab is active.
class MainShellBranchScope extends InheritedWidget {
  const MainShellBranchScope({
    required this.activeBranch,
    required super.child,
    super.key,
  });

  /// Shell branch index: 0 home, 1 comunidad, 2 centro garra, 3 explorar, 4 passport.
  final int activeBranch;

  static MainShellBranchScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<MainShellBranchScope>();
  }

  @override
  bool updateShouldNotify(MainShellBranchScope oldWidget) {
    return oldWidget.activeBranch != activeBranch;
  }
}
