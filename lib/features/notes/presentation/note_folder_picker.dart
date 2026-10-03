import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../folders/data/folder.dart';

/// Shows a folder picker sheet.
///
/// Returns a folder id, `-1` for unfiled / no folder, or `null` if cancelled.
Future<int?> showNoteFolderPicker(
  BuildContext context, {
  required List<Folder> folders,
  int? selectedFolderId,
}) {
  final l10n = AppLocalizations.of(context);
  return showModalBottomSheet<int?>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final theme = Theme.of(context);
      final isDark = theme.brightness == Brightness.dark;
      final accent = isDark ? AppColors.tealLight : AppColors.tealDark;

      Widget row({
        required IconData icon,
        required String label,
        required bool selected,
        required VoidCallback onTap,
        bool indented = false,
      }) {
        return Material(
          color: selected
              ? AppColors.teal.withValues(alpha: isDark ? 0.22 : 0.12)
              : Colors.transparent,
          child: ListTile(
            leading: Icon(
              icon,
              color: selected ? accent : AppColors.teal,
            ),
            title: Text(
              label,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? accent : null,
              ),
            ),
            trailing: selected
                ? Icon(Icons.check_rounded, color: accent)
                : null,
            selected: selected,
            contentPadding: EdgeInsetsDirectional.only(
              start: indented ? 28 : 16,
              end: 16,
            ),
            onTap: onTap,
          ),
        );
      }

      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            row(
              icon: Icons.inbox_outlined,
              label: l10n.noFolder,
              selected: selectedFolderId == null,
              onTap: () => Navigator.pop(context, -1),
            ),
            for (final folder in folders)
              row(
                icon: folder.parentFolderId == null
                    ? Icons.folder_outlined
                    : Icons.folder_open_outlined,
                label: folder.name,
                selected: selectedFolderId == folder.id,
                indented: folder.parentFolderId != null,
                onTap: () => Navigator.pop(context, folder.id),
              ),
          ],
        ),
      );
    },
  );
}
