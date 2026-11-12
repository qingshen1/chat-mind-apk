
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'utils/theme.dart';
import 'services/storage_service.dart';
import 'services/float_window_service.dart';
import 'services/screenshot_service.dart';
import 'pages/privacy_page.dart';
import 'pages/home_page.dart';

class AppState extends ChangeNotifier {
  bool _initialized = false;
  bool _privacyAgreed = false;

  bool get initialized => _initialized;
  bool get privacyAgreed => _privacyAgreed;

  Future<void> init() async {
    await StorageService().init();
    FloatWindowService.init();
    ScreenshotService.init();
    _privacyAgreed = StorageService().privacyAgreed;
    _initialized = true;
    notifyListeners();
  }

  void agreePrivacy() {
    _privacyAgreed = true;
    StorageService().setPrivacyAgreed(true);
    notifyListeners();
  }
}

/// 监听软键盘高度并上报原生悬浮窗服务。
/// 只在高度变化时发一次，键盘收起时上报 0 让悬浮窗归位。
class ImeHeightReporter extends StatefulWidget {
  const ImeHeightReporter({super.key, required this.child});

  final Widget? child;

  @override
  State<ImeHeightReporter> createState() => _ImeHeightReporterState();
}

class _ImeHeightReporterState extends State<ImeHeightReporter> {
  int _lastHeight = 0;

  @override
  Widget build(BuildContext context) {
    final metrics = MediaQuery.maybeOf(context);
    if (metrics != null) {
      final px = (metrics.viewInsets.bottom * metrics.devicePixelRatio).round();
      if (px != _lastHeight) {
        _lastHeight = px;
        // 下一帧再发，避免在 build 期间触发通道调用
        WidgetsBinding.instance.addPostFrameCallback((_) {
          FloatWindowService.updateImeHeight(px);
        });
      }
    }
    return widget.child ?? const SizedBox.shrink();
  }
}

class ChatMindApp extends StatelessWidget {
  const ChatMindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState()..init(),
      child: MaterialApp(
        title: 'ChatMind',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        // v2.4：把软键盘高度同步给原生悬浮窗，避免悬浮球/面板压住键盘
        builder: (context, child) => ImeHeightReporter(child: child),
        home: Consumer<AppState>(
          builder: (context, state, _) {
            if (!state.initialized) {
              return Scaffold(
                body: Container(
                  decoration: BoxDecoration(gradient: AppTheme.bgGradient),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: AppTheme.accentGradient,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: AppTheme.accentGlow,
                          ),
                          child: const Icon(Icons.psychology, color: Colors.white, size: 28),
                        ),
                        const SizedBox(height: 20),
                        const CircularProgressIndicator(color: AppTheme.accentStart),
                      ],
                    ),
                  ),
                ),
              );
            }
            if (!state.privacyAgreed) {
              return const PrivacyPage();
            }
            return const HomePage();
          },
        ),
      ),
    );
  }
}
