import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../data/noteon_table_data.dart';

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

/// Renders and edits [NoteonTableBlockEmbed] inside the Quill editor.
class NoteonTableEmbedBuilder extends EmbedBuilder {
  const NoteonTableEmbedBuilder();

  @override
  String get key => NoteonTableBlockEmbed.embedType;

  @override
  bool get expanded => true;

  @override
  String toPlainText(Embed node) {
    final table = NoteonTableBlockEmbed.tryParseEmbeddable(node.value);
    if (table == null) {
      return '';
    }
    final text = table.toPlainText();
    return text.isEmpty ? ' ' : text;
  }

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final raw = embedContext.node.value;
    final data = NoteonTableBlockEmbed.tryParseEmbeddable(raw) ??
        NoteonTableData.empty(
          rows: NoteonTableData.defaultRows,
          columns: NoteonTableData.defaultColumns,
        );

    // flutter_quill unwraps `custom` embeds into a detached Embed node, so
    // `node.documentOffset` is often 0. Resolve by stable table id instead.
    final documentOffset = NoteonTableDocument.offsetOf(
          embedContext.controller.document,
          data.id,
        ) ??
        embedContext.node.documentOffset;

    return _NoteonTableView(
      key: ValueKey(data.id),
      data: data,
      readOnly: embedContext.readOnly,
      documentOffset: documentOffset,
      controller: embedContext.controller,
    );
  }
}

class _NoteonTableView extends StatefulWidget {
  const _NoteonTableView({
    super.key,
    required this.data,
    required this.readOnly,
    required this.documentOffset,
    required this.controller,
  });

  final NoteonTableData data;
  final bool readOnly;
  final int documentOffset;
  final QuillController controller;

  @override
  State<_NoteonTableView> createState() => _NoteonTableViewState();
}

class _NoteonTableViewState extends State<_NoteonTableView> {
  late NoteonTableData _data;
  late List<List<TextEditingController>> _controllers;
  late List<List<FocusNode>> _focusNodes;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _data = widget.data;
    _buildControllers();
    final pending = NoteonTableFocus.pendingTableId;
    if (pending != null && pending == _data.id && !widget.readOnly) {
      NoteonTableFocus.pendingTableId = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _focusNodes.isEmpty || _focusNodes.first.isEmpty) {
          return;
        }
        _focusNodes.first.first.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(covariant _NoteonTableView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.id != widget.data.id ||
        oldWidget.data.rows != widget.data.rows ||
        oldWidget.data.columns != widget.data.columns) {
      _debounce?.cancel();
      _disposeControllers();
      _data = widget.data;
      _buildControllers();
      return;
    }

    final focused = _focusNodes.any((row) => row.any((n) => n.hasFocus));
    if (!focused && !_sameCells(_data.cells, widget.data.cells)) {
      _disposeControllers();
      _data = widget.data;
      _buildControllers();
    }
  }

  bool _sameCells(List<List<String>> a, List<List<String>> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var r = 0; r < a.length; r++) {
      if (a[r].length != b[r].length) {
        return false;
      }
      for (var c = 0; c < a[r].length; c++) {
        if (a[r][c] != b[r][c]) {
          return false;
        }
      }
    }
    return true;
  }

  void _buildControllers() {
    _controllers = [
      for (var r = 0; r < _data.rows; r++)
        [
          for (var c = 0; c < _data.columns; c++)
            TextEditingController(text: _data.cells[r][c]),
        ],
    ];
    _focusNodes = [
      for (var r = 0; r < _data.rows; r++)
        [
          for (var c = 0; c < _data.columns; c++) FocusNode(),
        ],
    ];
  }

  void _disposeControllers() {
    for (final row in _controllers) {
      for (final controller in row) {
        controller.dispose();
      }
    }
    for (final row in _focusNodes) {
      for (final node in row) {
        node.dispose();
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _disposeControllers();
    super.dispose();
  }

  void _commit(NoteonTableData next, {bool keepFocus = true}) {
    if (widget.readOnly) {
      return;
    }
    _data = next;
    final block = BlockEmbed.custom(NoteonTableBlockEmbed.fromData(next));
    // Never fall back to a possibly-stale documentOffset (often 0 for custom
    // embeds). Replacing the wrong index inserts a duplicate table.
    final offset = NoteonTableDocument.offsetOf(
      widget.controller.document,
      next.id,
    );
    if (offset == null) {
      return;
    }
    final docLength = widget.controller.document.length;
    if (offset < 0 || offset >= docLength) {
      return;
    }
    widget.controller.replaceText(
      offset,
      1,
      block,
      keepFocus
          ? widget.controller.selection
          : TextSelection.collapsed(offset: offset + 1),
    );
  }

  void _scheduleCommit(NoteonTableData next) {
    _data = next;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) {
        return;
      }
      _commit(_data);
    });
  }

  void _onCellChanged(int row, int column, String value) {
    if (_data.cells[row][column] == value) {
      return;
    }
    _scheduleCommit(_data.copyWithCell(row, column, value));
  }

  void _flushCommit() {
    _debounce?.cancel();
    _commit(_data);
  }

  void _focusCell(int row, int column) {
    if (row < 0 ||
        column < 0 ||
        row >= _focusNodes.length ||
        column >= _focusNodes[row].length) {
      return;
    }
    _focusNodes[row][column].requestFocus();
  }

  void _moveFocus(int row, int column, {required bool forward}) {
    var r = row;
    var c = column;
    if (forward) {
      c++;
      if (c >= _data.columns) {
        c = 0;
        r++;
      }
      if (r >= _data.rows) {
        return;
      }
    } else {
      c--;
      if (c < 0) {
        r--;
        c = _data.columns - 1;
      }
      if (r < 0) {
        return;
      }
    }
    _focusCell(r, c);
  }

  Future<void> _onMenuSelected(String value) async {
    final l10n = AppLocalizations.of(context);
    _debounce?.cancel();
    switch (value) {
      case 'addRow':
        setState(() {
          _disposeControllers();
          _data = _data.addRow();
          _buildControllers();
        });
        _commit(_data);
      case 'removeRow':
        if (_data.rows <= NoteonTableData.minSize) {
          return;
        }
        setState(() {
          _disposeControllers();
          _data = _data.removeRow();
          _buildControllers();
        });
        _commit(_data);
      case 'addColumn':
        setState(() {
          _disposeControllers();
          _data = _data.addColumn();
          _buildControllers();
        });
        _commit(_data);
      case 'removeColumn':
        if (_data.columns <= NoteonTableData.minSize) {
          return;
        }
        setState(() {
          _disposeControllers();
          _data = _data.removeColumn();
          _buildControllers();
        });
        _commit(_data);
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
              ) ??
              widget.documentOffset;
          widget.controller.replaceText(
            offset,
            1,
            '',
            TextSelection.collapsed(offset: offset),
          );
        }
    }
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
    final cellMinWidth = 96.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
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
                  Icon(
                    Icons.table_chart_outlined,
                    size: 18,
                    color: isDark ? AppColors.tealLight : AppColors.tealDark,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.tableLabel,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
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
                          enabled: _data.columns < NoteonTableData.maxSize * 2,
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
                  defaultColumnWidth: FixedColumnWidth(cellMinWidth),
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
                            _TableCellField(
                              controller: _controllers[r][c],
                              focusNode: _focusNodes[r][c],
                              readOnly: widget.readOnly,
                              isHeader: r == 0,
                              onChanged: (value) => _onCellChanged(r, c, value),
                              onEditingComplete: _flushCommit,
                              onNext: () {
                                _flushCommit();
                                _moveFocus(r, c, forward: true);
                              },
                              onPrevious: () {
                                _flushCommit();
                                _moveFocus(r, c, forward: false);
                              },
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TableCellField extends StatelessWidget {
  const _TableCellField({
    required this.controller,
    required this.focusNode,
    required this.readOnly,
    required this.isHeader,
    required this.onChanged,
    required this.onEditingComplete,
    required this.onNext,
    required this.onPrevious,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool readOnly;
  final bool isHeader;
  final ValueChanged<String> onChanged;
  final VoidCallback onEditingComplete;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Focus(
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) {
          return KeyEventResult.ignored;
        }
        if (event.logicalKey == LogicalKeyboardKey.tab) {
          if (HardwareKeyboard.instance.isShiftPressed) {
            onPrevious();
          } else {
            onNext();
          }
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        readOnly: readOnly,
        minLines: 1,
        maxLines: 4,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: isHeader ? FontWeight.w700 : FontWeight.w500,
          height: 1.35,
        ),
        textAlign: TextAlign.start,
        textInputAction: TextInputAction.next,
        decoration: const InputDecoration(
          isDense: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        ),
        onChanged: onChanged,
        onEditingComplete: onEditingComplete,
        onSubmitted: (_) => onNext(),
      ),
    );
  }
}

/// Prompts for initial table size, then returns [NoteonTableData] or null.
Future<NoteonTableData?> showInsertTableDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  var rows = NoteonTableData.defaultRows;
  var columns = NoteonTableData.defaultColumns;

  return showDialog<NoteonTableData>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setLocalState) {
          return AlertDialog(
            title: Text(l10n.insertTableTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.insertTableMessage,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 20),
                _SizeStepper(
                  label: l10n.tableRows,
                  value: rows,
                  onChanged: (value) => setLocalState(() => rows = value),
                ),
                const SizedBox(height: 12),
                _SizeStepper(
                  label: l10n.tableColumns,
                  value: columns,
                  onChanged: (value) => setLocalState(() => columns = value),
                ),
              ],
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
                    NoteonTableData.empty(rows: rows, columns: columns),
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
