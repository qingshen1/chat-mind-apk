
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

  // ===== v2.3 新增：说话人识别 =====

  /// 模型识别出的「对方」最后一条消息原文
  final String? otherLastMessage;

  /// 模型识别出的「你」最后一条消息原文
  final String? myLastMessage;

  /// 说话人归属的判断依据；不确定时模型会在此说明
  final String? speakerNote;

  AnalysisResult({
    required this.psychology,
    required this.intention,
    required this.replies,
    this.riskWarning,
    this.tokenUsage,
    this.otherLastMessage,
    this.myLastMessage,
    this.speakerNote,
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
      otherLastMessage: _asText(json['other_last_message']),
      myLastMessage: _asText(json['my_last_message']),
      speakerNote: _asText(json['speaker_note']),
    );
  }

  /// 空字符串统一转成 null，避免界面出现空区块
  static String? _asText(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  /// 是否成功识别出对话双方
  bool get hasSpeakerInfo =>
      (otherLastMessage != null && otherLastMessage!.isNotEmpty) ||
      (myLastMessage != null && myLastMessage!.isNotEmpty);
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
