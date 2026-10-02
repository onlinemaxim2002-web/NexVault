import 'package:flutter/widgets.dart';

import '../state/app_state.dart';

/// Reloads a screen's data when what the user may see changes
/// (login/logout, install source recorded, plan granted).
mixin ContentReload<T extends StatefulWidget> on State<T> {
  Future<void> reload();

  @override
  void initState() {
    super.initState();
    app.contentVersion.addListener(_onChange);
    reload();
  }

  void _onChange() {
    if (mounted) reload();
  }

  @override
  void dispose() {
    app.contentVersion.removeListener(_onChange);
    super.dispose();
  }
}
