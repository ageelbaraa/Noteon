import 'dart:convert';

import 'package:uuid/uuid.dart';

/// Serializable table payload stored inside a Quill custom embed.
class NoteonTableData {
  const NoteonTableData({
    required this.id,
    required this.rows,
    required this.columns,
    required this.cells,
    this.title = '',
  });

  static const int minSize = 1;
  static const int maxSize = 8;
  static const int defaultRows = 3;
  static const int defaultColumns = 3;

  final String id;
  final int rows;
  final int columns;

  /// Optional caption shown above the table. Empty when unset.
  final String title;

  /// Cell text as [row][column].
  final List<List<String>> cells;

  factory NoteonTableData.empty({
    required int rows,
    required int columns,
    String? id,
    String title = '',
  }) {
    final r = rows.clamp(minSize, maxSize);
    final c = columns.clamp(minSize, maxSize);
    return NoteonTableData(
      id: id ?? const Uuid().v4(),
      rows: r,
      columns: c,
      title: title,
      cells: List.generate(
        r,
        (_) => List.generate(c, (_) => ''),
      ),
    );
  }

  factory NoteonTableData.fromJson(Map<String, dynamic> json) {
    final rows = (json['rows'] as num?)?.toInt() ?? 1;
    final columns = (json['columns'] as num?)?.toInt() ?? 1;
    final id = (json['id'] as String?)?.trim();
    final title = '${json['title'] ?? ''}'.trim();
    final rawCells = json['cells'];

    final cells = <List<String>>[];
    if (rawCells is List) {
      for (final row in rawCells) {
        if (row is List) {
          cells.add(row.map(sanitizeCellText).toList());
        }
      }
    }

    while (cells.length < rows) {
      cells.add(List.generate(columns, (_) => ''));
    }
    for (var i = 0; i < cells.length; i++) {
      while (cells[i].length < columns) {
        cells[i].add('');
      }
      if (cells[i].length > columns) {
        cells[i] = cells[i].sublist(0, columns);
      }
    }
    if (cells.length > rows) {
      cells.removeRange(rows, cells.length);
    }

    return NoteonTableData(
      id: (id == null || id.isEmpty) ? const Uuid().v4() : id,
      rows: rows.clamp(minSize, maxSize * 2),
      columns: columns.clamp(minSize, maxSize * 2),
      title: title,
      cells: cells,
    );
  }

  factory NoteonTableData.fromJsonString(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return NoteonTableData.fromJson(decoded);
    }
    if (decoded is Map) {
      return NoteonTableData.fromJson(Map<String, dynamic>.from(decoded));
    }
    return NoteonTableData.empty(rows: defaultRows, columns: defaultColumns);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'rows': rows,
        'columns': columns,
        'title': title,
        'cells': cells,
      };

  String toJsonString() => jsonEncode(toJson());

  /// Coerces a cell payload to plain text. Never uses Map/List `.toString()`,
  /// and strips Quill's U+FFFC object-replacement character if it leaked in.
  static String sanitizeCellText(Object? cell) {
    if (cell == null) {
      return '';
    }
    if (cell is String) {
      return cell.replaceAll('\uFFFC', '');
    }
    if (cell is num || cell is bool) {
      return '$cell';
    }
    // Unexpected structured values must not become "{...}" / object strings.
    return '';
  }

  /// Plain text used for list previews and search.
  String toPlainText() {
    final parts = <String>[];
    final trimmedTitle = title.trim();
    if (trimmedTitle.isNotEmpty) {
      parts.add(trimmedTitle);
    }
    for (final row in cells) {
      for (final cell in row) {
        final trimmed = cell.trim();
        if (trimmed.isNotEmpty) {
          parts.add(trimmed);
        }
      }
    }
    return parts.join(' ');
  }

  bool get hasContent => toPlainText().isNotEmpty;

  NoteonTableData copyWith({
    String? title,
    List<List<String>>? cells,
    int? rows,
    int? columns,
  }) {
    return NoteonTableData(
      id: id,
      rows: rows ?? this.rows,
      columns: columns ?? this.columns,
      title: title ?? this.title,
      cells: cells ??
          this.cells.map((r) => List<String>.from(r)).toList(growable: false),
    );
  }

  NoteonTableData copyWithCell(int row, int column, String value) {
    final next = cells.map((r) => List<String>.from(r)).toList(growable: false);
    next[row][column] = sanitizeCellText(value);
    return copyWith(cells: next);
  }

  NoteonTableData addRow() {
    if (rows >= maxSize * 2) {
      return this;
    }
    return copyWith(
      rows: rows + 1,
      cells: [
        ...cells.map((r) => List<String>.from(r)),
        List.generate(columns, (_) => ''),
      ],
    );
  }

  NoteonTableData removeRow({int? index}) {
    if (rows <= minSize) {
      return this;
    }
    final removeAt = (index ?? rows - 1).clamp(0, rows - 1);
    final next = [
      for (var i = 0; i < cells.length; i++)
        if (i != removeAt) List<String>.from(cells[i]),
    ];
    return copyWith(rows: rows - 1, cells: next);
  }

  NoteonTableData addColumn() {
    if (columns >= maxSize * 2) {
      return this;
    }
    return copyWith(
      columns: columns + 1,
      cells: [
        for (final row in cells) [...row, ''],
      ],
    );
  }

  NoteonTableData removeColumn({int? index}) {
    if (columns <= minSize) {
      return this;
    }
    final removeAt = (index ?? columns - 1).clamp(0, columns - 1);
    return copyWith(
      columns: columns - 1,
      cells: [
        for (final row in cells)
          [
            for (var i = 0; i < row.length; i++)
              if (i != removeAt) row[i],
          ],
      ],
    );
  }
}

/// Signals which newly inserted table should autofocus its first cell.
abstract final class NoteonTableFocus {
  static String? pendingTableId;
}
