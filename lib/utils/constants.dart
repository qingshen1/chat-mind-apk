
class Constants {
  static const String appName = 'ChatMind';
  static const String appVersion = '2.2.0';

  // SharedPreferences keys
  static const String prefApiKey = 'api_key';
  static const String prefModel = 'model';
  static const String prefBaseUrl = 'base_url';
  static const String prefApiProvider = 'api_provider';
  static const String prefScene = 'scene';
  static const String prefOpacity = 'opacity';
  static const String prefValuesBase = 'values_base';
  static const String prefValuesScene = 'values_scene';
  static const String prefPrivacyAgreed = 'privacy_agreed';
  static const String prefFirstLaunch = 'first_launch';
  // v2.2 新增
  static const String prefTemperature = 'temperature';
  static const String prefMaxTokens = 'max_tokens';
  static const String prefTopP = 'top_p';
  static const String prefFeedback = 'feedback_data';
  static const String prefTemplates = 'reply_templates';
  static const String prefTokenStats = 'token_stats';
  static const String prefKeyMigrated = 'key_migrated';

  // Default values
  static const String defaultModel = 'doubao-1.5-vision-pro-32k';
  static const String defaultBaseUrl = 'https://ark.cn-beijing.volces.com/api/v3/chat/completions';
  static const String defaultApiProvider = 'doubao';
  // v2.2 模型参数默认值
  static const double defaultTemperature = 0.3;
  static const int defaultMaxTokens = 800;
  static const double defaultTopP = 1.0;

  /// 各服务商 Token 单价（元 / 百万 tokens，混合输入输出均价）
  /// 用于费用粗略估算，仅供参考
  static const Map<String, double> tokenPrices = {
    'doubao': 8.0,
    'openai': 35.0,
    'deepseek': 1.5,
    'qwen': 8.0,
    'moonshot': 12.0,
    'glm': 12.0,
    'custom': 0.0,
  };

  /// API 服务商预设列表
  /// 每个预设包含：id, 名称, 默认 endpoint, 默认模型, 是否支持视觉, 描述
  static const List<Map<String, dynamic>> apiProviders = [
    {
      'id': 'doubao',
      'name': '火山引擎豆包',
      'base_url': 'https://ark.cn-beijing.volces.com/api/v3/chat/completions',
      'default_model': 'doubao-1.5-vision-pro-32k',
      'supports_vision': true,
      'desc': '字节跳动旗下大模型，国内直连速度快',
      'docs_url': 'https://console.volcengine.com/ark',
    },
    {
      'id': 'openai',
      'name': 'OpenAI',
      'base_url': 'https://api.openai.com/v1/chat/completions',
      'default_model': 'gpt-4o',
      'supports_vision': true,
      'desc': 'GPT-4o 多模态模型，需要海外网络',
      'docs_url': 'https://platform.openai.com/api-keys',
    },
    {
      'id': 'deepseek',
      'name': 'DeepSeek',
      'base_url': 'https://api.deepseek.com/v1/chat/completions',
      'default_model': 'deepseek-chat',
      'supports_vision': false,
      'desc': '深度求索，性价比极高（不支持图片）',
      'docs_url': 'https://platform.deepseek.com/api_keys',
    },
    {
      'id': 'qwen',
      'name': '通义千问',
      'base_url': 'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions',
      'default_model': 'qwen-vl-max',
      'supports_vision': true,
      'desc': '阿里云通义千问 VL 视觉模型',
      'docs_url': 'https://dashscope.console.aliyun.com/apiKey',
    },
    {
      'id': 'moonshot',
      'name': '月之暗面 Kimi',
      'base_url': 'https://api.moonshot.cn/v1/chat/completions',
      'default_model': 'moonshot-v1-8k',
      'supports_vision': false,
      'desc': 'Kimi 大模型，长文本能力强（不支持图片）',
      'docs_url': 'https://platform.moonshot.cn/console/api-keys',
    },
    {
      'id': 'glm',
      'name': '智谱 GLM',
      'base_url': 'https://open.bigmodel.cn/api/paas/v4/chat/completions',
      'default_model': 'glm-4v',
      'supports_vision': true,
      'desc': '智谱 AI GLM-4V 视觉模型',
      'docs_url': 'https://open.bigmodel.cn/usercenter/apikeys',
    },
    {
      'id': 'custom',
      'name': '自定义 API',
      'base_url': '',
      'default_model': '',
      'supports_vision': true,
      'desc': '填写任意 OpenAI 兼容格式的 API 地址',
      'docs_url': '',
    },
  ];

  /// 根据 id 获取服务商预设
  static Map<String, dynamic>? getProviderById(String id) {
    try {
      return apiProviders.firstWhere((p) => p['id'] == id);
    } catch (_) {
      return null;
    }
  }

  /// 规范化用户填写的 API 地址，补全成完整的 chat/completions 端点。
  ///
  /// 用户常常只填到版本号，直接发请求会 404，这里统一补全：
  /// - `https://api.x.com`                     → `https://api.x.com/v1/chat/completions`
  /// - `https://api.x.com/v1` / `.../v1/`      → `https://api.x.com/v1/chat/completions`
  /// - `https://api.x.com/v1/chat/completions` → 原样返回
  /// - 其它无法识别的完整路径 → 原样返回，避免拼出更错的地址
  static String normalizeChatUrl(String raw) {
    var url = raw.trim();
    if (url.isEmpty) return url;
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }

    final lower = url.toLowerCase();
    if (lower.endsWith('/chat/completions') || lower.endsWith('/completions')) {
      return url;
    }

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return url;

    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();

    // 只填了域名：补默认 v1 前缀
    if (segments.isEmpty) {
      return '$url/v1/chat/completions';
    }

    // 路径以版本号结尾（/v1、/v3、/v4、/api/paas/v4…）：直接补接口名
    if (RegExp(r'^v\d+$').hasMatch(segments.last)) {
      return '$url/chat/completions';
    }

    // 其它情况保守处理，原样返回
    return url;
  }

  /// 从 chat/completions 端点 URL 推导出 models 列表 URL。
  ///
  /// 例: `https://api.openai.com/v1` → `https://api.openai.com/v1/models`
  static String deriveModelsUrl(String rawChatUrl) {
    final chatUrl = normalizeChatUrl(rawChatUrl);
    final lower = chatUrl.toLowerCase();

    const chatSuffix = '/chat/completions';
    if (lower.endsWith(chatSuffix)) {
      return chatUrl.substring(0, chatUrl.length - chatSuffix.length) + '/models';
    }
    const compSuffix = '/completions';
    if (lower.endsWith(compSuffix)) {
      return chatUrl.substring(0, chatUrl.length - compSuffix.length) + '/models';
    }

    // 兜底：路径末尾是版本号则保留，否则去掉最后一段，再追加 /models
    final uri = Uri.tryParse(chatUrl);
    if (uri == null || uri.host.isEmpty) return chatUrl;
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isNotEmpty && !RegExp(r'^v\d+$').hasMatch(segments.last)) {
      segments.removeLast();
    }
    segments.add('models');
    return uri.replace(path: '/${segments.join('/')}').toString();
  }

  static const List<String> scenes = ['职场', '亲密关系', '家庭', '社交'];

  static const List<Map<String, String>> baseValues = [
    {'id': 'sincere', 'text': '待人真诚，不主动算计、挖坑套路别人'},
    {'id': 'no_sarcasm', 'text': '拒绝阴阳怪气、嘲讽、报复性话术'},
    {'id': 'no_beg', 'text': '不卑不亢，不卑微讨好任何人'},
    {'id': 'no_pushover', 'text': '不做无底线老好人，懂得委婉自保'},
    {'id': 'no_gossip', 'text': '不背后诋毁、挑拨他人关系'},
    {'id': 'gentle', 'text': '沟通优先温和体面，尽量避免正面冲突'},
    {'id': 'no_hurt', 'text': '不使用尖锐、伤人、对立的语言'},
  ];

  static const Map<String, String> sceneValueHints = {
    '职场': '例如：尊重但不盲从，合理拒绝额外压榨',
    '亲密关系': '例如：互相尊重，保持独立空间',
    '家庭': '例如：多包容理解，但也不一味顺从',
    '社交': '例如：和朋友往来平等，拒绝无底线消耗',
  };
}
