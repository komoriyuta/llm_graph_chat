import 'package:flutter/foundation.dart';

enum LlmProviderType { gemini, openai, claude, custom }

extension LlmProviderTypeX on LlmProviderType {
  String get storageKey => name;

  String get displayName {
    switch (this) {
      case LlmProviderType.gemini:
        return 'Google Gemini';
      case LlmProviderType.openai:
        return 'OpenAI';
      case LlmProviderType.claude:
        return 'Anthropic Claude';
      case LlmProviderType.custom:
        return 'Custom (OpenAI Compatible)';
    }
  }
}

class LlmProviderOption {
  final LlmProviderType type;
  final String displayName;
  final String defaultEndpoint;
  final List<String> defaultModels;
  final bool allowEndpointEditing;
  final bool requiresEndpoint;

  const LlmProviderOption({
    required this.type,
    required this.displayName,
    required this.defaultEndpoint,
    required this.defaultModels,
    required this.allowEndpointEditing,
    required this.requiresEndpoint,
  });

  static const List<LlmProviderOption> all = [
    LlmProviderOption(
      type: LlmProviderType.gemini,
      displayName: 'Google Gemini',
      defaultEndpoint: 'https://generativelanguage.googleapis.com/v1beta',
      defaultModels: [
        'gemini-2.5-pro',
        'gemini-2.5-flash',
        'gemini-2.5-flash-lite',
        'gemini-2.5-flash-preview-09-2025',
        'gemini-2.5-flash-lite-preview-09-2025',
        'gemini-2.5-flash-native-audio-preview-09-2025',
        'gemini-1.5-pro-latest',
        'gemini-1.5-flash-latest',
        'gemini-1.5-flash-8b-latest',
      ],
      allowEndpointEditing: false,
      requiresEndpoint: false,
    ),
    LlmProviderOption(
      type: LlmProviderType.openai,
      displayName: 'OpenAI',
      defaultEndpoint: 'https://api.openai.com/v1',
      defaultModels: [
        'gpt-5',
        'gpt-5-pro',
        'gpt-5-mini',
        'gpt-5-chat-latest',
        'gpt-5-codex',
        'o3',
        'o3-pro',
        'o3-mini',
        'o4-mini',
        'o4-mini-high',
      ],
      allowEndpointEditing: true,
      requiresEndpoint: true,
    ),
    LlmProviderOption(
      type: LlmProviderType.claude,
      displayName: 'Anthropic Claude',
      defaultEndpoint: 'https://api.anthropic.com/v1',
      defaultModels: [
        'claude-sonnet-4.5',
        'claude-opus-4.1',
        'claude-sonnet-4',
        'claude-opus-4',
        'claude-haiku-4',
      ],
      allowEndpointEditing: true,
      requiresEndpoint: true,
    ),
    LlmProviderOption(
      type: LlmProviderType.custom,
      displayName: 'Custom (OpenAI Compatible)',
      defaultEndpoint: '',
      defaultModels: [],
      allowEndpointEditing: true,
      requiresEndpoint: true,
    ),
  ];

  static LlmProviderOption byType(LlmProviderType type) {
    return all.firstWhere((option) => option.type == type);
  }

  static LlmProviderType? typeFromStorage(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    try {
      return LlmProviderType.values.firstWhere((e) => e.storageKey == value);
    } catch (_) {
      return null;
    }
  }
}

@immutable
class LlmProviderSettings {
  final LlmProviderType provider;
  final String? apiKey;
  final String? endpoint;
  final String? model;

  const LlmProviderSettings({
    required this.provider,
    this.apiKey,
    this.endpoint,
    this.model,
  });

  LlmProviderSettings copyWith({
    String? apiKey,
    String? endpoint,
    String? model,
  }) {
    return LlmProviderSettings(
      provider: provider,
      apiKey: apiKey ?? this.apiKey,
      endpoint: endpoint ?? this.endpoint,
      model: model ?? this.model,
    );
  }
}
