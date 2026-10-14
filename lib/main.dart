import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/database.dart';
import 'data/settings_repo.dart';
import 'platform/native_bridge.dart';
import 'state/app_state.dart';
import 'ui/app_scope.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final db = await AppDatabase.open();
  final state = AppState(db, NativeBridge());
  await state.init();
  runApp(TarteebApp(state: state));
}

class TarteebApp extends StatefulWidget {
  final AppState state;
  const TarteebApp({super.key, required this.state});

  @override
  State<TarteebApp> createState() => _TarteebAppState();
}

class _TarteebAppState extends State<TarteebApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) widget.state.onResumed();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: widget.state,
      child: ListenableBuilder(
        listenable: widget.state,
        builder: (context, _) {
          final st = widget.state.settings;
          return MaterialApp(
            title: 'ترتيب',
            debugShowCheckedModeBanner: false,
            locale: Locale(st.language),
            supportedLocales: const [Locale('ar'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            themeMode: switch (st.theme) {
              ThemePref.light => ThemeMode.light,
              ThemePref.dark => ThemeMode.dark,
              ThemePref.system => ThemeMode.system,
            },
            theme: buildTheme(Brightness.light),
            darkTheme: buildTheme(Brightness.dark),
            home: const Shell(),
          );
        },
      ),
    );
  }
}
