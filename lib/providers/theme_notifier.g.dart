// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ThemeNotifier)
const themeProvider = ThemeNotifierProvider._();

final class ThemeNotifierProvider
    extends $NotifierProvider<ThemeNotifier, ThemeData> {
  const ThemeNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'themeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$themeNotifierHash();

  @$internal
  @override
  ThemeNotifier create() => ThemeNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ThemeData value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ThemeData>(value),
    );
  }
}

String _$themeNotifierHash() => r'26f9db53080956252c6cb28cb13cb9252c96c809';

abstract class _$ThemeNotifier extends $Notifier<ThemeData> {
  ThemeData build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<ThemeData, ThemeData>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ThemeData, ThemeData>,
              ThemeData,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

@ProviderFor(NodeSettingsNotifier)
const nodeSettingsProvider = NodeSettingsNotifierProvider._();

final class NodeSettingsNotifierProvider
    extends $NotifierProvider<NodeSettingsNotifier, NodeSettingsState> {
  const NodeSettingsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'nodeSettingsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$nodeSettingsNotifierHash();

  @$internal
  @override
  NodeSettingsNotifier create() => NodeSettingsNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NodeSettingsState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NodeSettingsState>(value),
    );
  }
}

String _$nodeSettingsNotifierHash() =>
    r'86d79525c997f0642efb3c22c1a54db3ba1d0a0e';

abstract class _$NodeSettingsNotifier extends $Notifier<NodeSettingsState> {
  NodeSettingsState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<NodeSettingsState, NodeSettingsState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<NodeSettingsState, NodeSettingsState>,
              NodeSettingsState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
