import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/theme.dart';
import '../utils/toast.dart';
import '../utils/constants.dart';
import '../models/analysis_result.dart';
import '../services/storage_service.dart';
import '../services/permission_service.dart';
import '../services/screenshot_service.dart';
import '../services/float_window_service.dart';
import '../services/ai_service.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  String _currentScene = Constants.scenes.first;
  bool _isAnalyzing = false;
  StreamSubscription<ScreenshotData>? _screenshotSub;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _currentScene = StorageService().currentScene;
    _screenshotSub = ScreenshotService.selectionComplete.listen((data) {
      _analyzeImage(data.image, scene: data.scene);
    });
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _screenshotSub?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _setScene(String scene) {
    setState(() => _currentScene = scene);
    StorageService().setScene(scene);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    _analyzeImage(bytes);
  }

  Future<void> _startScreenshotSelection() async {
    final hasOverlay = await PermissionService.checkOverlayPermission();
    if (!hasOverlay) {
      final granted = await PermissionService.requestOverlayPermission();
      if (!granted) {
        AppToast.show(context, '需要悬浮窗权限才能截图');
        return;
      }
    }

    try {
      await ScreenshotService.showSelectionOverlay();
      AppToast.show(context, '请在屏幕上框选聊天区域');
    } catch (e) {
      AppToast.show(context, '启动框选失败: $e');
    }
  }

  Future<void> _analyzeImage(Uint8List imageBytes, {String? scene}) async {
    if (_isAnalyzing) return;

    setState(() => _isAnalyzing = true);

    try {
      final baseValues = StorageService().baseValues;
      final sceneValues = StorageService().sceneValues;

      final result = await AIService.analyzeImage(
        imageBytes,
        scene: scene ?? _currentScene,
        baseValues: baseValues,
        sceneValues: sceneValues,
      );

      if (mounted) {
        _showResultDialog(result, scene: scene ?? _currentScene);
      }

      await FloatWindowService.showAnalysisPanel(
        result,
        scene: scene ?? _currentScene,
      );
    } catch (e) {
      AppToast.show(context, '分析失败: $e');
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  void _showResultDialog(AnalysisResult result, {required String scene}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AnalysisResultDialog(result: result, scene: scene),
    );
  }

  Future<void> _openFloatWindow() async {
    final hasOverlay = await PermissionService.checkOverlayPermission();
    if (!hasOverlay) {
      final granted = await PermissionService.requestOverlayPermission();
      if (!granted) {
        AppToast.show(context, '需要悬浮窗权限');
        return;
      }
    }

    final success = await FloatWindowService.showFloatBall();
    if (success) {
      AppToast.show(context, '悬浮窗已开启');
    } else {
      AppToast.show(context, '悬浮窗开启失败');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      _buildHeroSection(),
                      const SizedBox(height: 24),
                      _buildSceneSelector(),
                      const SizedBox(height: 24),
                      _buildMainButton(
                        icon: Icons.photo_library_outlined,
                        title: '从相册选择',
                        subtitle: '选择已保存的聊天截图',
                        onTap: _pickImage,
                      ),
                      const SizedBox(height: 14),
                      _buildMainButton(
                        icon: Icons.layers_outlined,
                        title: '打开悬浮窗',
                        subtitle: '在其他APP上方显示分析结果',
                        onTap: _openFloatWindow,
                        isSecondary: true,
                      ),
                      const SizedBox(height: 14),
                      _buildTips(),
                      const Spacer(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== 顶部导航栏 ====================

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: AppTheme.accentGradient,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: AppTheme.accentGlow,
                ),
                child: const Icon(Icons.psychology, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              ShaderMask(
                shaderCallback: (bounds) => AppTheme.accentGradient.createShader(bounds),
                child: const Text(
                  'Chat Mind',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppTheme.textSecondary),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== Hero 区域 ====================

  Widget _buildHeroSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGlassGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI 聊天分析助手',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '截图分析对方心理·智能回复建议',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildStatusChip(
                      StorageService().apiKey.isNotEmpty ? '已配置' : '未配置',
                      StorageService().apiKey.isNotEmpty ? AppTheme.success : AppTheme.warning,
                    ),
                    const SizedBox(width: 8),
                    _buildStatusChip(StorageService().providerName, AppTheme.accentStart),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _isAnalyzing ? _pulseAnimation.value : 1.0,
                child: child,
              );
            },
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: AppTheme.cyanBlueGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accentCyan.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 0),
                  ),
                ],
              ),
              child: _isAnalyzing
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome, color: Colors.white, size: 28),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: color),
      ),
    );
  }

  // ==================== 场景选择器 ====================

  Widget _buildSceneSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.tune, size: 16, color: AppTheme.accentStart),
            const SizedBox(width: 6),
            const Text('当前场景', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: Constants.scenes.map((scene) {
            final isSelected = scene == _currentScene;
            return GestureDetector(
              onTap: () => _setScene(scene),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  gradient: isSelected ? AppTheme.accentGradient : null,
                  color: isSelected ? null : AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(20),
                  border: isSelected ? null : Border.all(color: Colors.white.withOpacity(0.08)),
                  boxShadow: isSelected ? AppTheme.accentGlow : null,
                ),
                child: Text(
                  scene,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? Colors.white : AppTheme.textSecondary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ==================== 主功能按钮 ====================

  Widget _buildMainButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isSecondary = false,
  }) {
    return GestureDetector(
      onTap: _isAnalyzing ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: isSecondary ? AppTheme.cardGlassGradient : AppTheme.cardGlassGradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSecondary
                ? Colors.white.withOpacity(0.06)
                : AppTheme.accentStart.withOpacity(0.15),
          ),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: isSecondary ? null : AppTheme.accentGradient,
                color: isSecondary ? AppTheme.bgDarker : null,
                borderRadius: BorderRadius.circular(12),
                boxShadow: isSecondary ? null : AppTheme.accentGlow,
              ),
              child: Icon(
                icon,
                color: isSecondary ? AppTheme.accentStart : Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }

  // ==================== 使用说明 ====================

  Widget _buildTips() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGlassGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.help_outline, size: 16, color: AppTheme.accentCyan),
              const SizedBox(width: 6),
              const Text(
                '使用说明',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '1. 在微信/QQ等聊天页面截图或选择已有截图\n'
            '2. AI自动分析对方心理、意图和回复建议\n'
            '3. 使用悬浮窗可在聊天时实时查看分析结果\n'
            '4. 建议先在设置中配置个人价值观，让回复更贴合你',
            style: TextStyle(
              fontSize: 12,
              height: 1.7,
              color: AppTheme.textMuted.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== 分析结果弹窗（v2.2 StatefulWidget） ====================

class AnalysisResultDialog extends StatefulWidget {
  final AnalysisResult result;
  final String scene;
  const AnalysisResultDialog({super.key, required this.result, required this.scene});

  @override
  State<AnalysisResultDialog> createState() => _AnalysisResultDialogState();
}

class _AnalysisResultDialogState extends State<AnalysisResultDialog> {
  /// 每条回复的评分状态：true=赞, false=踩, null=未评
  final Map<int, bool> _ratings = {};

  AnalysisResult get result => widget.result;
  String get scene => widget.scene;

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    AppToast.show(context, '已复制到剪贴板');
  }

  void _share(String text) {
    Share.share(text);
  }

  /// 分享全部分析结果
  void _shareAll() {
    final buffer = StringBuffer();
    buffer.writeln('【ChatMind AI 分析 · $scene】');
    buffer.writeln();
    if (result.riskWarning != null && result.riskWarning!.isNotEmpty) {
      buffer.writeln('⚠️ 风险预警：${result.riskWarning}');
      buffer.writeln();
    }
    buffer.writeln('💭 对方心理：${result.psychology}');
    buffer.writeln();
    buffer.writeln('🎯 对方意图：${result.intention}');
    buffer.writeln();
    buffer.writeln('💬 回复建议：');
    for (final reply in result.replies) {
      buffer.writeln('【${reply.style}】${reply.content}');
    }
    Share.share(buffer.toString());
  }

  /// 评分回复
  void _rateReply(int index, bool isGood) {
    final reply = result.replies[index];
    final storage = StorageService();

    setState(() {
      // 再次点击同方向则取消
      if (_ratings[index] == isGood) {
        _ratings.remove(index);
        return;
      }
      _ratings[index] = isGood;
    });

    if (_ratings[index] == true) {
      // 👍 → 保存评分 + 自动收藏模板
      storage.saveFeedback(scene: scene, replyStyle: reply.style, rating: 1);
      storage.saveTemplate(scene, reply);
      AppToast.show(context, '已收藏为模板 👍');
    } else if (_ratings[index] == false) {
      // 👎 → 保存评分
      storage.saveFeedback(scene: scene, replyStyle: reply.style, rating: -1);
      AppToast.show(context, '已记录反馈，可尝试重新生成');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        decoration: BoxDecoration(
          gradient: AppTheme.bgGradient,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 头部
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: AppTheme.accentGradient,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.psychology, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'AI 分析结果 · $scene',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  // 分享全部按钮
                  GestureDetector(
                    onTap: _shareAll,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.share, size: 14, color: Colors.white),
                          SizedBox(width: 4),
                          Text('分享', style: TextStyle(fontSize: 12, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (result.riskWarning != null && result.riskWarning!.isNotEmpty)
                      _buildRiskCard(result.riskWarning!),
                    _buildSectionCard(
                      '💭 对方心理',
                      result.psychology,
                      Icons.sentiment_satisfied_outlined,
                      AppTheme.accentStart,
                    ),
                    const SizedBox(height: 14),
                    _buildSectionCard(
                      '🎯 对方意图',
                      result.intention,
                      Icons.track_changes_outlined,
                      AppTheme.accentCyan,
                    ),
                    const SizedBox(height: 16),
                    const Row(
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 18, color: AppTheme.accentPurple),
                        SizedBox(width: 8),
                        Text(
                          '💬 回复建议',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...result.replies.asMap().entries.map((entry) {
                      return _buildReplyCard(entry.key, entry.value);
                    }),
                    // v2.2: Token 消耗条
                    if (result.tokenUsage != null) ...[
                      const SizedBox(height: 8),
                      _buildTokenBar(),
                    ],
                    // v2.2: 场景满意度
                    const SizedBox(height: 12),
                    _buildSatisfactionBar(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== v2.2: Token 消耗条 ====================

  Widget _buildTokenBar() {
    final usage = result.tokenUsage!;
    final storage = StorageService();
    final providerId = storage.apiProvider;
    final price = Constants.tokenPrices[providerId] ?? 0.0;
    final cost = usage.getEstimatedCost(price);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.accentCyan.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.accentCyan.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt, color: AppTheme.accentCyan, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: '本次消耗 ', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      TextSpan(
                        text: '${usage.totalTokens}',
                        style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontFamily: 'monospace'),
                      ),
                      const TextSpan(text: ' tokens', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'prompt: ${usage.promptTokens} · completion: ${usage.completionTokens}'
                  + (cost > 0 ? ' · 预估 ¥${cost.toStringAsFixed(4)}' : ''),
                  style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          // 今日累计
          if (storage.todayTokenUsage > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.bgDarker,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '今日 ${storage.todayTokenUsage}',
                style: const TextStyle(fontSize: 10, color: AppTheme.accentCyan, fontFamily: 'monospace'),
              ),
            ),
        ],
      ),
    );
  }

  // ==================== v2.2: 场景满意度 ====================

  Widget _buildSatisfactionBar() {
    final satisfaction = StorageService().getSceneSatisfaction(scene);
    if (satisfaction == 0) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_outlined, size: 14, color: AppTheme.textMuted),
              const SizedBox(width: 6),
              Text('$scene 场景满意度', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              const Spacer(),
              Text(
                '$satisfaction%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                  color: satisfaction >= 60 ? AppTheme.success : AppTheme.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: satisfaction / 100,
              minHeight: 5,
              backgroundColor: Colors.white.withOpacity(0.06),
              valueColor: AlwaysStoppedAnimation(
                satisfaction >= 60 ? AppTheme.success : AppTheme.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 风险卡片 ====================

  Widget _buildRiskCard(String text) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.danger.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.danger.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, color: AppTheme.danger, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 分析段落卡片 ====================

  Widget _buildSectionCard(String title, String content, IconData icon, Color iconColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGlassGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: const TextStyle(fontSize: 14, height: 1.6, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  // ==================== v2.2: 回复卡片（含评分+分享） ====================

  Widget _buildReplyCard(int index, ReplyOption reply) {
    final rating = _ratings[index];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgDarker.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: rating == true
              ? AppTheme.success.withOpacity(0.3)
              : rating == false
                  ? AppTheme.danger.withOpacity(0.2)
                  : AppTheme.accentStart.withOpacity(0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 风格标签
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: AppTheme.purplePinkGradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              reply.style,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ),
          const SizedBox(height: 10),
          // 回复内容
          Text(
            reply.content,
            style: const TextStyle(fontSize: 14, height: 1.6, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 10),
          // v2.2: 操作按钮栏
          Row(
            children: [
              // 👍 点赞
              _buildRateButton(
                icon: Icons.thumb_up_outlined,
                isActive: rating == true,
                activeColor: AppTheme.success,
                onTap: () => _rateReply(index, true),
              ),
              const SizedBox(width: 6),
              // 👎 点踩
              _buildRateButton(
                icon: Icons.thumb_down_outlined,
                isActive: rating == false,
                activeColor: AppTheme.danger,
                onTap: () => _rateReply(index, false),
              ),
              const Spacer(),
              // 复制
              _buildActionChip(
                icon: Icons.copy,
                label: '复制',
                color: AppTheme.accentStart,
                onTap: () {
                  _copy('【${reply.style}】\n${reply.content}');
                },
              ),
              const SizedBox(width: 6),
              // 分享
              _buildActionChip(
                icon: Icons.share,
                label: '分享',
                color: AppTheme.accentPink,
                onTap: () {
                  _share('【ChatMind AI建议·$scene】\n${reply.style}：${reply.content}');
                },
              ),
            ],
          ),
          // v2.2: 点赞后提示
          if (rating == true) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bookmark_added, size: 12, color: AppTheme.success),
                  SizedBox(width: 4),
                  Text('已自动收藏到模板库', style: TextStyle(fontSize: 11, color: AppTheme.success)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 评分按钮（👍/👎）
  Widget _buildRateButton({
    required IconData icon,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive ? activeColor.withOpacity(0.4) : Colors.transparent,
          ),
        ),
        child: Icon(
          icon,
          size: 15,
          color: isActive ? activeColor : AppTheme.textMuted,
        ),
      ),
    );
  }

  /// 操作按钮芯片（复制/分享）
  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, color: color)),
          ],
        ),
      ),
    );
  }
}
