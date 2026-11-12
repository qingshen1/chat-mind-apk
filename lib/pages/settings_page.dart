
import 'package:flutter/material.dart';
import '../utils/theme.dart';
import '../utils/toast.dart';
import '../utils/constants.dart';
import '../services/storage_service.dart';
import '../models/test_connection_result.dart';
import '../services/ai_service.dart';
import 'values_editor_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController _apiKeyController;
  late TextEditingController _modelController;
  late TextEditingController _baseUrlController;
  late String _selectedProviderId;
  double _opacity = 0.85;
  bool _obscureKey = true;
  bool _isCustomProvider = false;
  bool _isFetchingModels = false;
  bool _isTestingConnection = false;

  // v2.2 模型生成参数
  late double _temperature;
  late int _maxTokens;
  late double _topP;
  bool _showAdvanced = false;

  @override
  void initState() {
    super.initState();
    final storage = StorageService();
    _apiKeyController = TextEditingController(text: storage.apiKey);
    _modelController = TextEditingController(text: storage.model);
    _baseUrlController = TextEditingController(text: storage.baseUrl);
    _selectedProviderId = storage.apiProvider;
    _opacity = storage.floatOpacity;
    _isCustomProvider = _selectedProviderId == 'custom';
    // v2.2 加载模型参数
    _temperature = storage.temperature;
    _maxTokens = storage.maxTokens;
    _topP = storage.topP;
  }

  /// 切换 API 服务商时自动填充默认值
  void _onProviderChanged(String providerId) {
    final provider = Constants.getProviderById(providerId);
    if (provider == null) return;

    setState(() {
      _selectedProviderId = providerId;
      _isCustomProvider = providerId == 'custom';

      // 非自定义时自动填充默认 baseUrl 和 model
      if (!_isCustomProvider) {
        final defaultUrl = provider['base_url'] as String;
        final defaultModel = provider['default_model'] as String;
        _baseUrlController.text = defaultUrl;
        _modelController.text = defaultModel;
      }
    });
  }

  void _save() {
    final storage = StorageService();

    // 自动补全 /chat/completions，避免只填到 /v1 时请求 404
    final normalizedUrl = Constants.normalizeChatUrl(_baseUrlController.text.trim());
    if (normalizedUrl != _baseUrlController.text.trim()) {
      _baseUrlController.text = normalizedUrl;
    }

    storage.setApiKey(_apiKeyController.text.trim());
    storage.setModel(_modelController.text.trim());
    storage.setBaseUrl(normalizedUrl);
    storage.setApiProvider(_selectedProviderId);
    storage.setOpacity(_opacity);
    storage.setTemperature(_temperature);
    storage.setMaxTokens(_maxTokens);
    storage.setTopP(_topP);
    AppToast.show(context, '保存成功');
  }

  // ==================== 自动识别模型 ====================

  /// 调用 /models 接口自动获取可用模型列表
  Future<void> _fetchModels() async {
    final apiKey = _apiKeyController.text.trim();
    final baseUrl = _baseUrlController.text.trim();

    if (apiKey.isEmpty) {
      AppToast.show(context, '请先填写 API Key');
      return;
    }
    if (baseUrl.isEmpty) {
      AppToast.show(context, '请先填写 API 地址');
      return;
    }

    setState(() => _isFetchingModels = true);

    try {
      final models = await AIService.fetchAvailableModels(
        baseUrl: baseUrl,
        apiKey: apiKey,
      );

      if (!mounted) return;

      if (models.length == 1) {
        setState(() => _modelController.text = models.first);
        AppToast.show(context, '已识别模型: ${models.first}');
      } else {
        _showModelSelectionDialog(models);
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('自动识别失败', e.toString());
    } finally {
      if (mounted) setState(() => _isFetchingModels = false);
    }
  }

  /// 显示模型选择底部弹窗
  void _showModelSelectionDialog(List<String> models) {
    String searchQuery = '';
    // 视觉模型关键词
    const visionKeywords = [
      'vision', 'vl', 'gpt-4o', 'glm-4v', 'multimodal', '4v', 'qvq', 'omni'
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final filtered = searchQuery.isEmpty
              ? models
              : models
                  .where((m) => m.toLowerCase().contains(searchQuery.toLowerCase()))
                  .toList();

          return Column(
            children: [
              // 顶部把手
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textMuted.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 标题栏
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.list_alt, color: AppTheme.accentStart, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '发现 ${models.length} 个可用模型',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('取消', style: TextStyle(color: AppTheme.textMuted)),
                    ),
                  ],
                ),
              ),
              // 搜索框
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  onChanged: (v) => setSheetState(() => searchQuery = v),
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: '搜索模型名称...',
                    hintStyle: TextStyle(color: AppTheme.textMuted.withOpacity(0.5)),
                    prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted, size: 20),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // 模型列表
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          '未找到匹配的模型',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (ctx, index) {
                          final modelId = filtered[index];
                          final isVision = visionKeywords.any(
                            (k) => modelId.toLowerCase().contains(k),
                          );
                          final isCurrent =
                              modelId == _modelController.text.trim();

                          return ListTile(
                            leading: Icon(
                              isVision
                                  ? Icons.visibility_outlined
                                  : Icons.text_snippet_outlined,
                              color: isVision ? AppTheme.success : AppTheme.textMuted,
                              size: 20,
                            ),
                            title: Text(
                              modelId,
                              style: TextStyle(
                                color: isCurrent
                                    ? AppTheme.accentStart
                                    : AppTheme.textPrimary,
                                fontWeight: isCurrent
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                fontSize: 14,
                              ),
                            ),
                            trailing: isCurrent
                                ? const Icon(Icons.check_circle,
                                    color: AppTheme.accentStart, size: 18)
                                : (isVision
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.success.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text('视觉',
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: AppTheme.success)),
                                      )
                                    : null),
                            onTap: () {
                              setState(() => _modelController.text = modelId);
                              Navigator.pop(ctx);
                              AppToast.show(context, '已选择模型: $modelId');
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ==================== 测试链接 ====================

  /// 发送轻量请求验证 API 连接
  Future<void> _testConnection() async {
    final apiKey = _apiKeyController.text.trim();
    final baseUrl = _baseUrlController.text.trim();
    final model = _modelController.text.trim();

    if (apiKey.isEmpty) {
      AppToast.show(context, '请先填写 API Key');
      return;
    }
    if (baseUrl.isEmpty) {
      AppToast.show(context, '请先填写 API 地址');
      return;
    }
    if (model.isEmpty) {
      AppToast.show(context, '请先填写模型名称');
      return;
    }

    setState(() => _isTestingConnection = true);

    try {
      final result = await AIService.testConnection(
        baseUrl: baseUrl,
        apiKey: apiKey,
        model: model,
      );

      if (!mounted) return;
      _showTestResultDialog(result);
    } catch (e) {
      if (!mounted) return;
      _showTestResultDialog(TestConnectionResult(
        success: false,
        message: '连接异常',
        latencyMs: 0,
        errorDetail: e.toString(),
      ));
    } finally {
      if (mounted) setState(() => _isTestingConnection = false);
    }
  }

  /// 显示测试结果对话框
  void _showTestResultDialog(TestConnectionResult result) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              result.success ? Icons.check_circle : Icons.error_outline,
              color: result.success ? AppTheme.success : AppTheme.danger,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              result.success ? '连接成功' : '连接失败',
              style: TextStyle(
                color: result.success ? AppTheme.success : AppTheme.danger,
                fontWeight: FontWeight.w600,
                fontSize: 17,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(result.message,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
            const SizedBox(height: 12),
            if (result.success) ...[
              _buildResultRow('延迟', '${result.latencyMs}ms'),
              if (result.modelUsed != null)
                _buildResultRow('模型', result.modelUsed!),
              if (result.replyPreview != null &&
                  result.replyPreview!.isNotEmpty)
                _buildResultRow('回复', result.replyPreview!),
            ] else ...[
              if (result.errorDetail != null) ...[
                const Text('错误详情:',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                const SizedBox(height: 4),
                Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.bgDarker,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      result.errorDetail!,
                      style: const TextStyle(color: AppTheme.danger, fontSize: 12),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('确定', style: TextStyle(color: AppTheme.accentStart)),
          ),
        ],
      ),
    );
  }

  /// 显示错误对话框
  void _showErrorDialog(String title, String detail) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: AppTheme.danger, size: 24),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    color: AppTheme.danger, fontWeight: FontWeight.w600, fontSize: 17)),
          ],
        ),
        content: Container(
          constraints: const BoxConstraints(maxHeight: 150),
          child: SingleChildScrollView(
            child: Text(detail,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('确定', style: TextStyle(color: AppTheme.accentStart)),
          ),
        ],
      ),
    );
  }

  /// 结果行组件
  Widget _buildResultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 50,
            child: Text(label,
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // ==================== 操作按钮组件 ====================

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required LinearGradient gradient,
    required bool isLoading,
    VoidCallback? onTap,
  }) {
    final isDisabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          gradient: isDisabled ? null : gradient,
          color: isDisabled ? AppTheme.bgDarker : null,
          borderRadius: BorderRadius.circular(12),
          border: isDisabled
              ? Border.all(color: Colors.white.withOpacity(0.06))
              : null,
          boxShadow: isDisabled
              ? null
              : [
                  BoxShadow(
                    color: gradient.colors.first.withOpacity(0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            else
              Icon(icon,
                  color: isDisabled ? AppTheme.textMuted : Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDisabled ? AppTheme.textMuted : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 预设方案芯片 ====================

  Widget _buildPresetChip(String label, double temp, int tokens, double topP, Color color) {
    final isActive = _temperature == temp && _maxTokens == tokens && _topP == topP;
    return GestureDetector(
      onTap: () => setState(() {
        _temperature = temp;
        _maxTokens = tokens;
        _topP = topP;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.2) : AppTheme.bgDarker,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? color.withOpacity(0.4) : Colors.white.withOpacity(0.06),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            color: isActive ? color : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _modelController.dispose();
    _baseUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ==================== API 配置 ====================
                      _buildSectionTitle('API 配置', Icons.cloud_outlined),
                      const SizedBox(height: 12),

                      // 服务商选择
                      _buildCard(
                        child: _buildProviderSelector(),
                      ),
                      const SizedBox(height: 12),

                      // 当前服务商信息提示
                      _buildProviderInfoBanner(),
                      const SizedBox(height: 12),

                      // API Key 输入
                      _buildCard(
                        child: Column(
                          children: [
                            TextField(
                              controller: _apiKeyController,
                              obscureText: _obscureKey,
                              style: const TextStyle(color: AppTheme.textPrimary),
                              decoration: InputDecoration(
                                labelText: 'API Key',
                                labelStyle: const TextStyle(color: AppTheme.textMuted),
                                prefixIcon: const Icon(Icons.key_outlined, color: AppTheme.textMuted, size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureKey ? Icons.visibility_off : Icons.visibility,
                                    color: AppTheme.textMuted,
                                  ),
                                  onPressed: () => setState(() => _obscureKey = !_obscureKey),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // 模型名称
                            TextField(
                              controller: _modelController,
                              style: const TextStyle(color: AppTheme.textPrimary),
                              decoration: InputDecoration(
                                labelText: '模型名称',
                                labelStyle: const TextStyle(color: AppTheme.textMuted),
                                prefixIcon: const Icon(Icons.smart_toy_outlined, color: AppTheme.textMuted, size: 20),
                                hintText: '输入或选择模型名称',
                                hintStyle: TextStyle(color: AppTheme.textMuted.withOpacity(0.5)),
                                suffixIcon: IconButton(
                                  icon: _isFetchingModels
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppTheme.accentStart,
                                          ),
                                        )
                                      : const Icon(Icons.auto_awesome, color: AppTheme.accentStart, size: 20),
                                  onPressed: _isFetchingModels ? null : _fetchModels,
                                  tooltip: '自动识别模型',
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Base URL（自定义时必填，预设时可编辑）
                            TextField(
                              controller: _baseUrlController,
                              style: const TextStyle(color: AppTheme.textPrimary),
                              decoration: InputDecoration(
                                labelText: _isCustomProvider ? 'API 地址（必填）' : 'API 地址',
                                labelStyle: const TextStyle(color: AppTheme.textMuted),
                                prefixIcon: const Icon(Icons.link, color: AppTheme.textMuted, size: 20),
                                hintText: 'https://api.example.com/v1/chat/completions',
                                hintStyle: TextStyle(color: AppTheme.textMuted.withOpacity(0.4)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          _isCustomProvider
                              ? '填写任意 OpenAI 兼容格式的 API 地址和模型名称'
                              : '前往 ${_currentProviderName} 控制台获取 API Key',
                          style: TextStyle(fontSize: 12, color: AppTheme.textMuted.withOpacity(0.7)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 操作按钮：自动识别模型 + 测试链接
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionButton(
                              label: '自动识别',
                              icon: Icons.auto_awesome,
                              gradient: AppTheme.purplePinkGradient,
                              isLoading: _isFetchingModels,
                              onTap: _isFetchingModels ? null : _fetchModels,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildActionButton(
                              label: '测试链接',
                              icon: Icons.wifi_tethering,
                              gradient: AppTheme.cyanBlueGradient,
                              isLoading: _isTestingConnection,
                              onTap: _isTestingConnection ? null : _testConnection,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // ==================== 高级参数（v2.2 新增） ====================
                      _buildSectionTitle('高级参数', Icons.tune_outlined),
                      const SizedBox(height: 12),
                      _buildCard(
                        child: Column(
                          children: [
                            // 折叠/展开头部
                            GestureDetector(
                              onTap: () => setState(() => _showAdvanced = !_showAdvanced),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      gradient: AppTheme.cyanBlueGradient,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.tune, color: Colors.white, size: 16),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('模型生成参数', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                                        Text(
                                          '温度 ${_temperature.toStringAsFixed(1)} · 长度 $_maxTokens · TopP ${_topP.toStringAsFixed(1)}',
                                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    _showAdvanced ? Icons.expand_less : Icons.expand_more,
                                    color: AppTheme.textMuted,
                                  ),
                                ],
                              ),
                            ),
                            // 展开内容
                            if (_showAdvanced) ...[
                              const Divider(height: 24),
                              // 预设方案
                              const Text('快速预设', style: TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: [
                                  _buildPresetChip('🛡️ 保守', 0.1, 1000, 0.9, AppTheme.success),
                                  _buildPresetChip('⚖️ 平衡', 0.3, 2000, 1.0, AppTheme.accentStart),
                                  _buildPresetChip('🎨 创意', 0.7, 3000, 1.0, AppTheme.accentPink),
                                ],
                              ),
                              const SizedBox(height: 20),
                              // Temperature 滑块
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Temperature · 创意度', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                                  Text(
                                    _temperature.toStringAsFixed(2),
                                    style: const TextStyle(color: AppTheme.accentStart, fontWeight: FontWeight.w600, fontSize: 13, fontFamily: 'monospace'),
                                  ),
                                ],
                              ),
                              Slider(
                                value: _temperature,
                                min: 0.0,
                                max: 1.0,
                                divisions: 20,
                                activeColor: AppTheme.accentStart,
                                inactiveColor: AppTheme.textMuted.withOpacity(0.15),
                                onChanged: (v) => setState(() => _temperature = v),
                              ),
                              // Top P 滑块
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Top P · 采样范围', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                                  Text(
                                    _topP.toStringAsFixed(2),
                                    style: const TextStyle(color: AppTheme.accentCyan, fontWeight: FontWeight.w600, fontSize: 13, fontFamily: 'monospace'),
                                  ),
                                ],
                              ),
                              Slider(
                                value: _topP,
                                min: 0.1,
                                max: 1.0,
                                divisions: 18,
                                activeColor: AppTheme.accentCyan,
                                inactiveColor: AppTheme.textMuted.withOpacity(0.15),
                                onChanged: (v) => setState(() => _topP = v),
                              ),
                              // Max Tokens 输入
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Max Tokens · 最大长度', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                                  SizedBox(
                                    width: 80,
                                    child: TextField(
                                      controller: TextEditingController(text: _maxTokens.toString()),
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontFamily: 'monospace'),
                                      textAlign: TextAlign.right,
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                        border: OutlineInputBorder(),
                                      ),
                                      onChanged: (v) {
                                        final n = int.tryParse(v);
                                        if (n != null && n > 0 && n <= 8000) {
                                          setState(() => _maxTokens = n);
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // ==================== 悬浮窗设置 ====================
                      _buildSectionTitle('悬浮窗设置', Icons.layers_outlined),
                      const SizedBox(height: 12),
                      _buildCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('透明度', style: TextStyle(color: AppTheme.textPrimary)),
                                Text(
                                  '${(_opacity * 100).toInt()}%',
                                  style: const TextStyle(color: AppTheme.accentStart, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            Slider(
                              value: _opacity,
                              min: 0.3,
                              max: 1.0,
                              divisions: 14,
                              activeColor: AppTheme.accentStart,
                              inactiveColor: AppTheme.textMuted.withOpacity(0.15),
                              onChanged: (v) => setState(() => _opacity = v),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // ==================== 个人价值观 ====================
                      _buildSectionTitle('个人价值观', Icons.favorite_border_outlined),
                      const SizedBox(height: 12),
                      _buildCard(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: AppTheme.purplePinkGradient,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.favorite_border, color: Colors.white, size: 20),
                          ),
                          title: const Text('价值观编辑器', style: TextStyle(color: AppTheme.textPrimary)),
                          subtitle: const Text('让AI回复更贴合你的处事风格', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppTheme.textMuted),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ValuesEditorPage()),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // ==================== 关于 ====================
                      _buildSectionTitle('关于', Icons.info_outline),
                      const SizedBox(height: 12),
                      _buildCard(
                        child: Column(
                          children: [
                            _buildInfoRow('应用名称', 'ChatMind'),
                            const Divider(height: 24),
                            _buildInfoRow('版本号', Constants.appVersion),
                            const Divider(height: 24),
                            _buildInfoRow('当前服务商', _currentProviderName),
                            const Divider(height: 24),
                            _buildInfoRow('支持视觉', StorageService().supportsVision ? '✓ 是' : '✗ 否'),
                          ],
                        ),
                      ),

                      const SizedBox(height: 36),

                      // 保存按钮
                      SizedBox(
                        width: double.infinity,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: AppTheme.accentGradient,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: AppTheme.accentGlow,
                          ),
                          child: ElevatedButton(
                            onPressed: _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('保存设置', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
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

  String get _currentProviderName {
    final p = Constants.getProviderById(_selectedProviderId);
    return p?['name'] as String? ?? '未知';
  }

  // ==================== 头部 ====================

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.textSecondary, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          ShaderMask(
            shaderCallback: (bounds) => AppTheme.accentGradient.createShader(bounds),
            child: const Text(
              '设置',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 服务商选择器 ====================

  Widget _buildProviderSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '选择 API 服务商',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: Constants.apiProviders.map((provider) {
            final id = provider['id'] as String;
            final name = provider['name'] as String;
            final isSelected = id == _selectedProviderId;
            final supportsVision = provider['supports_vision'] as bool;

            return GestureDetector(
              onTap: () => _onProviderChanged(id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: isSelected ? AppTheme.accentGradient : null,
                  color: isSelected ? null : AppTheme.bgDarker,
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected
                      ? null
                      : Border.all(color: Colors.white.withOpacity(0.06)),
                  boxShadow: isSelected ? AppTheme.accentGlow : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected ? Colors.white : AppTheme.textSecondary,
                      ),
                    ),
                    if (supportsVision) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.visibility_outlined,
                        size: 12,
                        color: isSelected ? Colors.white70 : AppTheme.textMuted,
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ==================== 服务商信息横幅 ====================

  Widget _buildProviderInfoBanner() {
    final provider = Constants.getProviderById(_selectedProviderId);
    if (provider == null) return const SizedBox.shrink();

    final desc = provider['desc'] as String?;
    final supportsVision = provider['supports_vision'] as bool;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGlassGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: AppTheme.cyanBlueGradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.lightbulb_outline, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (desc != null && desc.isNotEmpty)
                  Text(
                    desc,
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      supportsVision ? Icons.check_circle_outline : Icons.cancel_outlined,
                      size: 14,
                      color: supportsVision ? AppTheme.success : AppTheme.danger,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      supportsVision ? '支持图片输入' : '不支持图片（仅文本）',
                      style: TextStyle(
                        fontSize: 12,
                        color: supportsVision ? AppTheme.success : AppTheme.danger,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 通用组件 ====================

  Widget _buildSectionTitle(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.accentStart),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGlassGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: child,
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
        Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w500, fontSize: 14)),
      ],
    );
  }
}
