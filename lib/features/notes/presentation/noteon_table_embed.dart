import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../data/note_block_model.dart';
import '../data/noteon_table_data.dart';
import 'note_block_chrome.dart';
import 'noteon_image_embed.dart';

/// Locates a table embed inside a Quill [Document] by its stable table id.
abstract final class NoteonTableDocument {
  static int? offsetOf(Document document, String tableId) {
    var offset = 0;
    for (final op in document.toDelta().toList()) {
      final data = op.data;
      if (data is Map && data[BlockEmbed.customType] is String) {
        final raw = data[BlockEmbed.customType] as String;
        final parsed = _parseTableId(raw);
        if (parsed == tableId) {
          return offset;
        }
      }
      offset += op.length ?? 0;
    }
    return null;
  }

  static String? _parseTableId(String customRaw) {
    try {
      final nested = jsonDecode(customRaw);
      if (nested is! Map) {
        return null;
      }
      final tableRaw = nested['noteonTable'];
      if (tableRaw is! String) {
        return null;
      }
      return NoteonTableData.fromJsonString(tableRaw).id;
    } catch (_) {
      return null;
    }
  }
}

/// Quill custom embed type for Noteon tables.
class NoteonTableBlockEmbed extends CustomBlockEmbed {
  const NoteonTableBlockEmbed(String data) : super(embedType, data);

  static const String embedType = 'noteonTable';

  factory NoteonTableBlockEmbed.fromData(NoteonTableData data) {
    return NoteonTableBlockEmbed(data.toJsonString());
  }

  NoteonTableData get tableData {
    try {
      return NoteonTableData.fromJsonString(data);
    } catch (_) {
      return NoteonTableData.empty(
        rows: NoteonTableData.defaultRows,
        columns: NoteonTableData.defaultColumns,
      );
    }
  }

  static NoteonTableData? tryParseEmbeddable(Embeddable embeddable) {
    try {
      if (embeddable.type == embedType) {
        return NoteonTableData.fromJsonString('${embeddable.data}');
      }
      if (embeddable.type == BlockEmbed.customType) {
        final custom = CustomBlockEmbed.fromJsonString('${embeddable.data}');
        if (custom.type == embedType) {
          return NoteonTableData.fromJsonString('${custom.data}');
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}

/// Renders [NoteonTableBlockEmbed] inside Quill.
///
/// Architecture — single focus owner:
/// - The Quill embed is **display-only** (no nested TextFields).
/// - Editing a cell/title opens a modal sheet with exactly one TextField.
/// - That sheet owns keyboard input; Quill's TextInputConnection stays closed.
/// - Cell values remain plain [String]s in [NoteonTableData] end-to-end.
class NoteonTableEmbedBuilder extends EmbedBuilder {
  const NoteonTableEmbedBuilder({
    this.editorFocusNode,
    this.interaction,
  });

  /// Quill editor focus node. Unfocused before opening a cell editor sheet.
  final FocusNode? editorFocusNode;
  final NoteBlockInteraction? interaction;

  @override
  String get key => NoteonTableBlockEmbed.embedType;

  @override
  bool get expanded => true;

  @override
  String toPlainText(Embed node) {
    // Embed document length is always 1.
    return Embed.kObjectReplacementCharacter;
  }

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final raw = embedContext.node.value;
    final data = NoteonTableBlockEmbed.tryParseEmbeddable(raw) ??
        NoteonTableData.empty(
          rows: NoteonTableData.defaultRows,
          columns: NoteonTableData.defaultColumns,
        );

    return RepaintBoundary(
      child: _NoteonTableView(
        key: ValueKey(data.id),
        data: data,
        readOnly: embedContext.readOnly,
        controller: embedContext.controller,
        editorFocusNode: editorFocusNode,
        interaction: interaction,
      ),
    );
  }
}

class _NoteonTableView extends StatefulWidget {
  const _NoteonTableView({
    super.key,
    required this.data,
    required this.readOnly,
    required this.controller,
    this.editorFocusNode,
    this.interaction,
  });

  final NoteonTableData data;
  final bool readOnly;
  final QuillController controller;
  final FocusNode? editorFocusNode;
  final NoteBlockInteraction? interaction;

  @override
  State<_NoteonTableView> createState() => _NoteonTableViewState();
}

class _NoteonTableViewState extends State<_NoteonTableView> {
  late NoteonTableData _data;
  var _sheetOpen = false;

  @override
  void initState() {
    super.initState();
    _data = widget.data;
    final pending = NoteonTableFocus.pendingTableId;
    if (pending != null && pending == _data.id && !widget.readOnly) {
      NoteonTableFocus.pendingTableId = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _editCell(0, 0);
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant _NoteonTableView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.id != widget.data.id) {
      _data = widget.data;
      return;
    }
    // Ignore Quill rebuilds while a sheet is editing local state.
    if (_sheetOpen) {
      return;
    }
    if (!_sameTable(widget.data, _data)) {
      _data = widget.data;
    }
  }

  bool _sameTable(NoteonTableData a, NoteonTableData b) {
    if (a.rows != b.rows ||
        a.columns != b.columns ||
        a.title != b.title ||
        a.cells.length != b.cells.length) {
      return false;
    }
    for (var r = 0; r < a.cells.length; r++) {
      if (a.cells[r].length != b.cells[r].length) {
        return false;
      }
      for (var c = 0; c < a.cells[r].length; c++) {
        if (a.cells[r][c] != b.cells[r][c]) {
          return false;
        }
      }
    }
    return true;
  }

  void _releaseQuillFocus() {
    final node = widget.editorFocusNode;
    if (node != null && node.hasFocus) {
      node.unfocus();
    }
  }

  /// Writes [_data] into the Quill document without moving focus/selection.
  void _persistToDocument() {
    if (widget.readOnly) {
      return;
    }
    final offset = NoteonTableDocument.offsetOf(
      widget.controller.document,
      _data.id,
    );
    if (offset == null) {
      return;
    }
    final docLength = widget.controller.document.length;
    if (offset < 0 || offset >= docLength) {
      return;
    }

    final selection = widget.controller.selection;
    final safeSelection = selection.isValid
        ? selection
        : TextSelection.collapsed(offset: offset);
    widget.controller.replaceText(
      offset,
      1,
      BlockEmbed.custom(NoteonTableBlockEmbed.fromData(_data)),
      safeSelection,
      ignoreFocus: true,
    );
  }

  Future<void> _editCell(int row, int column) async {
    if (widget.readOnly || _sheetOpen) {
      return;
    }
    widget.interaction?.selection.value = null;
    if (row < 0 ||
        column < 0 ||
        row >= _data.rows ||
        column >= _data.columns) {
      return;
    }

    _releaseQuillFocus();
    _sheetOpen = true;
    final l10n = AppLocalizations.of(context);
    final initial = NoteonTableData.sanitizeCellText(_data.cells[row][column]);

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return _TableTextEditorSheet(
          title: l10n.tableLabel,
          initialValue: initial,
          hintText: l10n.noteBodyHint,
        );
      },
    );

    if (!mounted) {
      return;
    }
    _sheetOpen = false;

    if (result == null) {
      return;
    }
    final next = NoteonTableData.sanitizeCellText(result);
    if (_data.cells[row][column] == next) {
      return;
    }
    setState(() {
      _data = _data.copyWithCell(row, column, next);
    });
    _persistToDocument();
  }

  Future<void> _editTitle() async {
    if (widget.readOnly || _sheetOpen) {
      return;
    }

    _releaseQuillFocus();
    _sheetOpen = true;
    final l10n = AppLocalizations.of(context);

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return _TableTextEditorSheet(
          title: l10n.tableTitleHint,
          initialValue: _data.title,
          hintText: l10n.tableTitleOptional,
        );
      },
    );

    if (!mounted) {
      return;
    }
    _sheetOpen = false;

    if (result == null) {
      return;
    }
    if (_data.title == result) {
      return;
    }
    setState(() {
      _data = _data.copyWith(title: result);
    });
    _persistToDocument();
  }

  Future<void> _onMenuSelected(String value) async {
    final l10n = AppLocalizations.of(context);

    switch (value) {
      case 'addRow':
        setState(() => _data = _data.addRow());
        _persistToDocument();
      case 'removeRow':
        if (_data.rows <= NoteonTableData.minSize) {
          return;
        }
        setState(() => _data = _data.removeRow());
        _persistToDocument();
      case 'addColumn':
        setState(() => _data = _data.addColumn());
        _persistToDocument();
      case 'removeColumn':
        if (_data.columns <= NoteonTableData.minSize) {
          return;
        }
        setState(() => _data = _data.removeColumn());
        _persistToDocument();
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.deleteTableTitle),
            content: Text(l10n.deleteTableMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.delete),
              ),
            ],
          ),
        );
        if (ok == true && mounted) {
          final offset = NoteonTableDocument.offsetOf(
            widget.controller.document,
            _data.id,
          );
          if (offset == null) {
            return;
          }
          widget.controller.replaceText(
            offset,
            1,
            '',
            TextSelection.collapsed(offset: offset),
          );
        }
    }
  }

  void _selectTable() {
    final interaction = widget.interaction;
    if (interaction == null || widget.readOnly) {
      return;
    }
    final offset = NoteonTableDocument.offsetOf(
      widget.controller.document,
      _data.id,
    );
    if (offset == null) {
      return;
    }
    interaction.onSelect(
      NoteBlock(
        kind: NoteBlockKind.table,
        start: offset,
        length: 1,
        tableId: _data.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = theme.colorScheme.outlineVariant.withValues(alpha: 0.8);
    final headerBg = isDark
        ? AppColors.surfaceDarkElevated
        : AppColors.surfaceLightAlt;
    const cellMinWidth = 96.0;
    final titleText = _data.title.trim();

    final tableBody = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _releaseQuillFocus,
        onLongPress: _selectTable,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: AppRadii.control,
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(10, 4, 4, 4),
                child: Row(
                  children: [
                    GestureDetector(
                      onLongPress: _selectTable,
                      child: Icon(
                        Icons.table_chart_outlined,
                        size: 18,
                        color:
                            isDark ? AppColors.tealLight : AppColors.tealDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: widget.readOnly ? null : _editTitle,
                        onLongPress: _selectTable,
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            titleText.isEmpty
                                ? (widget.readOnly
                                    ? l10n.tableLabel
                                    : l10n.tableTitleHint)
                                : titleText,
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: titleText.isEmpty
                                  ? theme.colorScheme.onSurfaceVariant
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (!widget.readOnly)
                      PopupMenuButton<String>(
                        tooltip: l10n.tableActions,
                        onSelected: _onMenuSelected,
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'addRow',
                            enabled: _data.rows < NoteonTableData.maxSize * 2,
                            child: Text(l10n.tableAddRow),
                          ),
                          PopupMenuItem(
                            value: 'removeRow',
                            enabled: _data.rows > NoteonTableData.minSize,
                            child: Text(l10n.tableRemoveRow),
                          ),
                          PopupMenuItem(
                            value: 'addColumn',
                            enabled:
                                _data.columns < NoteonTableData.maxSize * 2,
                            child: Text(l10n.tableAddColumn),
                          ),
                          PopupMenuItem(
                            value: 'removeColumn',
                            enabled: _data.columns > NoteonTableData.minSize,
                            child: Text(l10n.tableRemoveColumn),
                          ),
                          const PopupMenuDivider(),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(l10n.deleteTable),
                          ),
                        ],
                        icon: Icon(
                          Icons.more_horiz_rounded,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                primary: false,
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.all(8),
                child: RepaintBoundary(
                  child: Table(
                    defaultColumnWidth: const FixedColumnWidth(cellMinWidth),
                    border: TableBorder.all(
                      color: borderColor,
                      width: 1,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    children: [
                      for (var r = 0; r < _data.rows; r++)
                        TableRow(
                          decoration: BoxDecoration(
                            color: r == 0 ? headerBg : null,
                          ),
                          children: [
                            for (var c = 0; c < _data.columns; c++)
                              _buildCell(theme, r, c),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final interaction = widget.interaction;
    if (widget.readOnly || interaction == null) {
      return tableBody;
    }

    return ValueListenableBuilder<NoteBlockSelection?>(
      valueListenable: interaction.selection,
      builder: (context, selection, _) {
        final offset = NoteonTableDocument.offsetOf(
              widget.controller.document,
              _data.id,
            ) ??
            -1;
        final selected = selection != null &&
            selection.block.kind == NoteBlockKind.table &&
            (selection.block.tableId == _data.id ||
                selection.block.start == offset);
        final blockIndex = offset >= 0
            ? (interaction.indexForOffset(offset, NoteBlockKind.table) ?? 0)
            : 0;

        return NoteBlockChrome(
          selected: selected,
          blockIndex: blockIndex,
          onAcceptDrop: (fromIndex) {
            interaction.onAcceptDrop(
              fromIndex: fromIndex,
              toIndex: blockIndex,
            );
          },
          child: tableBody,
        );
      },
    );
  }

  Widget _buildCell(ThemeData theme, int row, int column) {
    final isHeader = row == 0;
    final text = NoteonTableData.sanitizeCellText(_data.cells[row][column]);
    final style = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: isHeader ? FontWeight.w700 : FontWeight.w500,
      height: 1.35,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.readOnly ? null : () => _editCell(row, column),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                text.isEmpty ? ' ' : text,
                style: style,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Single-field editor sheet — the only TextField used for table cell/title
/// editing. Kept outside the Quill focus tree on purpose.
class _TableTextEditorSheet extends StatefulWidget {
  const _TableTextEditorSheet({
    required this.title,
    required this.initialValue,
    required this.hintText,
  });

  final String title;
  final String initialValue;
  final String hintText;

  @override
  State<_TableTextEditorSheet> createState() => _TableTextEditorSheetState();
}

class _TableTextEditorSheetState extends State<_TableTextEditorSheet> {
  late final TextEditingController _controller;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.pop(context, _controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: true,
                minLines: 1,
                maxLines: 6,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: widget.hintText,
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.cancel),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _submit,
                    child: Text(l10n.save),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Prompts for initial table size (and optional title), then returns data.
Future<NoteonTableData?> showInsertTableDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  var rows = NoteonTableData.defaultRows;
  var columns = NoteonTableData.defaultColumns;
  final titleController = TextEditingController();

  try {
    return await showDialog<NoteonTableData>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: Text(l10n.insertTableTitle),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.insertTableMessage,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: l10n.tableTitleHint,
                        hintText: l10n.tableTitleOptional,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SizeStepper(
                      label: l10n.tableRows,
                      value: rows,
                      onChanged: (value) => setLocalState(() => rows = value),
                    ),
                    const SizedBox(height: 12),
                    _SizeStepper(
                      label: l10n.tableColumns,
                      value: columns,
                      onChanged: (value) =>
                          setLocalState(() => columns = value),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                      NoteonTableData.empty(
                        rows: rows,
                        columns: columns,
                        title: titleController.text.trim(),
                      ),
                    );
                  },
                  child: Text(l10n.insertTable),
                ),
              ],
            );
          },
        );
      },
    );
  } finally {
    titleController.dispose();
  }
}

class _SizeStepper extends StatelessWidget {
  const _SizeStepper({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(
          tooltip: '-',
          onPressed: value <= NoteonTableData.minSize
              ? null
              : () => onChanged(value - 1),
          icon: const Icon(Icons.remove_circle_outline),
        ),
        SizedBox(
          width: 28,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          tooltip: '+',
          onPressed: value >= NoteonTableData.maxSize
              ? null
              : () => onChanged(value + 1),
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}
