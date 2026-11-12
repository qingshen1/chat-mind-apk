
/// Token 用量信息（v2.2 新增）
class TokenUsage {
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;

  TokenUsage({
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
  });

  factory TokenUsage.fromJson(Map<String, dynamic> json) {
    return TokenUsage(
      promptTokens: (json['prompt_tokens'] as num?)?.toInt() ?? 0,
      completionTokens: (json['completion_tokens'] as num?)?.toInt() ?? 0,
      totalTokens: (json['total_tokens'] as num?)?.toInt() ?? 0,
    );
  }

  /// 根据服务商 ID 估算费用（元）
  /// price 为元/百万 tokens
  double getEstimatedCost(double pricePerMillion) {
    return totalTokens / 1000000 * pricePerMillion;
  }
}

/// 回复模板（v2.2 新增，用户点赞的回复自动收藏）
class ReplyTemplate {
  final String scene;
  final String style;
  final String content;
  final String savedAt;

  ReplyTemplate({
    required this.scene,
    required this.style,
    required this.content,
    required this.savedAt,
  });

  Map<String, dynamic> toJson() => {
        'scene': scene,
        'style': style,
        'content': content,
        'saved_at': savedAt,
      };

  factory ReplyTemplate.fromJson(Map<String, dynamic> json) {
    return ReplyTemplate(
      scene: json['scene'] as String? ?? '',
      style: json['style'] as String? ?? '',
      content: json['content'] as String? ?? '',
      savedAt: json['saved_at'] as String? ?? '',
    );
  }
}

class AnalysisResult {
  final String psychology;
  final String intention;
  final List<ReplyOption> replies;
  final String? riskWarning;
  final TokenUsage? tokenUsage; // v2.2 新增

  AnalysisResult({
    required this.psychology,
    required this.intention,
    required this.replies,
    this.riskWarning,
    this.tokenUsage,
  });

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    return AnalysisResult(
      psychology: json['psychology'] ?? '',
      intention: json['intention'] ?? '',
      riskWarning: json['risk_warning'],
      replies: (json['replies'] as List?)
          ?.map((e) => ReplyOption.fromJson(e))
          .toList() ?? [],
      tokenUsage: json['usage'] != null
          ? TokenUsage.fromJson(json['usage'] as Map<String, dynamic>)
          : null,
    );
  }
}

class ReplyOption {
  final String style;
  final String content;

  ReplyOption({required this.style, required this.content});

  factory ReplyOption.fromJson(Map<String, dynamic> json) {
    return ReplyOption(
      style: json['style'] ?? '',
      content: json['content'] ?? '',
    );
  }
}
