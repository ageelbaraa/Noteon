import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/noteon_logo.dart';

/// Shown when the local database cannot be opened at startup.
class DatabaseErrorApp extends StatelessWidget {
  const DatabaseErrorApp({
    super.key,
    this.failureCode,
    this.debugDetail,
    this.onRetry,
  });

  /// Non-sensitive failure code (e.g. DB_PATH).
  final String? failureCode;

  /// Verbose detail for debug/profile only.
  final String? debugDetail;

  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: _DatabaseErrorScreen(
        failureCode: failureCode,
        debugDetail: debugDetail,
        onRetry: onRetry,
      ),
    );
  }
}

class _DatabaseErrorScreen extends StatefulWidget {
  const _DatabaseErrorScreen({
    this.failureCode,
    this.debugDetail,
    this.onRetry,
  });

  final String? failureCode;
  final String? debugDetail;
  final Future<void> Function()? onRetry;

  @override
  State<_DatabaseErrorScreen> createState() => _DatabaseErrorScreenState();
}

class _DatabaseErrorScreenState extends State<_DatabaseErrorScreen> {
  bool _retrying = false;

  Future<void> _handleRetry() async {
    final retry = widget.onRetry;
    if (retry == null || _retrying) {
      return;
    }
    setState(() => _retrying = true);
    try {
      await retry();
    } finally {
      if (mounted) {
        setState(() => _retrying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final code = widget.failureCode;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const NoteonLogo(size: 72, variant: NoteonLogoVariant.branded),
              const SizedBox(height: AppSpacing.xl),
              Text(
                l10n.databaseOpenErrorTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.databaseOpenErrorMessage,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (code != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  l10n.databaseOpenErrorCode(code),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (!kReleaseMode && widget.debugDetail != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    l10n.databaseOpenErrorDebugLabel,
                    style: theme.textTheme.labelLarge,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 160),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: AppRadii.control,
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      widget.debugDetail!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              if (widget.onRetry != null)
                FilledButton(
                  onPressed: _retrying ? null : _handleRetry,
                  child: _retrying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.retry),
                ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () => SystemNavigator.pop(),
                child: Text(l10n.closeApp),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
