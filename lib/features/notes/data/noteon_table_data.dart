import 'dart:convert';

import 'package:uuid/uuid.dart';

/// Serializable table payload stored inside a Quill custom embed.
class NoteonTableData {
  const NoteonTableData({
    required this.id,
    required this.rows,
    required this.columns,
    required this.cells,
  });

  static const int minSize = 1;
  static const int maxSize = 8;
  static const int defaultRows = 3;
  static const int defaultColumns = 3;

  final String id;
  final int rows;
  final int columns;

  /// Cell text as [row][column].
  final List<List<String>> cells;

  factory NoteonTableData.empty({
    required int rows,
    required int columns,
    String? id,
  }) {
    final r = rows.clamp(minSize, maxSize);
    final c = columns.clamp(minSize, maxSize);
    return NoteonTableData(
      id: id ?? const Uuid().v4(),
      rows: r,
      columns: c,
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
    final rawCells = json['cells'];

    final cells = <List<String>>[];
    if (rawCells is List) {
      for (final row in rawCells) {
        if (row is List) {
          cells.add(row.map((cell) => '${cell ?? ''}').toList());
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
        'cells': cells,
      };

  String toJsonString() => jsonEncode(toJson());

  /// Plain text used for list previews and search.
  String toPlainText() {
    final parts = <String>[];
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

  NoteonTableData copyWithCell(int row, int column, String value) {
    final next = cells
        .map((r) => List<String>.from(r))
        .toList(growable: false);
    next[row][column] = value;
    return NoteonTableData(
      id: id,
      rows: rows,
      columns: columns,
      cells: next,
    );
  }

  NoteonTableData addRow() {
    if (rows >= maxSize * 2) {
      return this;
    }
    return NoteonTableData(
      id: id,
      rows: rows + 1,
      columns: columns,
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
    return NoteonTableData(
      id: id,
      rows: rows - 1,
      columns: columns,
      cells: next,
    );
  }

  NoteonTableData addColumn() {
    if (columns >= maxSize * 2) {
      return this;
    }
    return NoteonTableData(
      id: id,
      rows: rows,
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
    return NoteonTableData(
      id: id,
      rows: rows,
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
