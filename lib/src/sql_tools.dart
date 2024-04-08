

import 'package:sql_query_manager/src/sql_helper.dart';

enum OrderByType { asc, desc }

extension OrderByExtension on OrderByType {
  String get order {
    switch (this) {
      case OrderByType.asc:
        return "ASC";
      case OrderByType.desc:
        return "DESC";
    }
  }
}

class SqlOrderBy {
  final ColumnSql column;

  final OrderByType order;

  SqlOrderBy({required this.column, this.order = OrderByType.asc});
}

class ColumnExpressionSqL {
  final String column;
  final String operation;
  final dynamic value;

  ColumnExpressionSqL(
      {required final ColumnSql column,
      required this.operation,
      required final dynamic value})
      : column = column.columnName,
        value = ColumnSql.parseCorrectFormat(value);
}

class SqlSelectQueryParams<T> {
  List<ColumnExpressionSqL> Function(T) whereExpressions;
  List<ColumnExpressionSqL> Function(T) distinct;
  List<ColumnSql> Function(T) selectedColumns;
  List<String> Function(T) extraDataColumns;
  List<ColumnSql> Function(T) groupBy;
  List<JoinQueryColumn> Function(T) joins;
  List<SqlOrderBy> Function(T) orderBy;
  final ColumnSql Function(T)? having;
  int? limit;
  final int? offset;

  SqlSelectQueryParams({
    List<ColumnExpressionSqL> Function(T table)? whereExpressions,
    List<ColumnExpressionSqL> Function(T table)? distinct,
    List<ColumnSql> Function(T table)? selectedColumns,
    List<String> Function(T table)? extraDataColumns,
    List<ColumnSql> Function(T table)? groupBy,
    List<JoinQueryColumn> Function(T table)? joins,
    List<SqlOrderBy> Function(T table)? orderBy,
    this.having,
    this.limit,
    this.offset,
  })  : whereExpressions =
            whereExpressions ?? ((T _) => const <ColumnExpressionSqL>[]),
        distinct = distinct ?? ((T _) => const <ColumnExpressionSqL>[]),
        selectedColumns = selectedColumns ?? ((T _) => const <ColumnSql>[]),
        extraDataColumns = extraDataColumns ?? ((T _) => const <String>[]),
        groupBy = groupBy ?? ((T _) => const <ColumnSql>[]),
        joins = joins ?? ((T _) => const <JoinQueryColumn>[]),
        orderBy = orderBy ?? ((T _) => const <SqlOrderBy>[]);
}

abstract class SqlTable {
  static String selectQuery<T>(
      {required final String table,
      required final T instance,
      required final SqlSelectQueryParams<T> params}) {
    final selectedColumns = params.selectedColumns(instance);

    List<String> columns = (selectedColumns.isEmpty)
        ? ["$table.*"]
        : selectedColumns.map((column) => column.columnName).toList();

    columns.addAll(params.extraDataColumns(instance));

    final joins = params.joins(instance);
    if (joins.isNotEmpty) {
      columns.addAll(joins.map((join) => join.columnsSyntax));
    }

    final columnsToSelect = params.distinct(instance).isNotEmpty
        ? "DISTINCT ${params.distinct(instance).join(", ")}"
        : columns.join(", ");

    final queryBuilder = StringBuffer("SELECT $columnsToSelect FROM $table");

    for (final join in joins) {
      queryBuilder.write(" ${join.expressionsSyntax()} ");
    }

    if (params.whereExpressions(instance).isNotEmpty) {
      final whereClause = params
          .whereExpressions(instance)
          .map((expression) =>
              "$table.${expression.column} ${expression.operation} ${expression.value}")
          .join(" AND ");

      queryBuilder.write(" WHERE $whereClause");
    }

    if (params.groupBy(instance).isNotEmpty) {
      queryBuilder.write(
          " GROUP BY ${params.groupBy(instance).map((column) => column.columnName).join(", ")}");
    }

    final orderBy = params.orderBy(instance);

    if (orderBy.isNotEmpty) {
      queryBuilder.write(
          " ORDER BY ${orderBy.map((item) => "$table.${item.column.columnName} ${item.order.order}").join(", ")}");
    }

    if (params.having != null &&
        params.having!(instance).columnName.isNotEmpty) {
      queryBuilder.write(" HAVING ${params.having}");
    }

    if (params.limit != null) {
      queryBuilder.write(" LIMIT ${params.limit}");
    }

    if (params.offset != null) {
      queryBuilder.write(" OFFSET ${params.offset}");
    }

    return queryBuilder.toString();
  }
}

class JoinQueryColumn<T> {
  final TableSql table;
  final String alias;
  final T _instance;
  final List<ColumnSql> Function(T) selectedColumns;
  final List<OnExpressionColumnSqL> Function(T) onExpressions;
  final JoinType joinType;

  JoinQueryColumn(
      {required this.table,
      final String? alias,
      required final T instance,
      final List<ColumnSql> Function(T)? selectedColumns,
      required this.onExpressions,
      this.joinType = JoinType.inner})
      : alias = alias ?? table.tableName,
        selectedColumns = selectedColumns ?? ((T _) => const <ColumnSql>[]),
        _instance = instance;

  String get columnsSyntax {
    List<ColumnSql> columns = selectedColumns(_instance);
    if (columns.isEmpty) columns = table.columns;
    return columns
        .map((column) =>
            "$alias.${column.columnName} as '$alias.${column.columnName}'")
        .join(", ");
  }

  String expressionsSyntax() {
    final joinQueryBuilder = StringBuffer(
        "${joinType.syntax} ${table.tableName} ${(alias == table.tableName) ? "" : alias}");

    final joinOnExpressions = onExpressions(_instance);

    if (joinOnExpressions.isNotEmpty) {
      final whereClause = joinOnExpressions
          .map((expression) =>
              "$alias.${expression.column.columnName} ${expression.operation} ${expression.originAlias}.${expression.value}")
          .join(" AND ");

      joinQueryBuilder.write(" ON $whereClause");
    }

    return joinQueryBuilder.toString();
  }
}

class OnExpressionColumnSqL {
  final String originAlias;
  final ColumnSql column;
  final String operation;
  final dynamic value;

  OnExpressionColumnSqL(
      {required this.originAlias,
      required this.column,
      required this.operation,
      required final dynamic value})
      : value = ColumnSql.parseCorrectFormat(value);
}

enum JoinType { inner, left, right }

extension JoinTypeExtension on JoinType {
  String get syntax {
    switch (this) {
      case JoinType.inner:
        return "INNER JOIN";
      case JoinType.left:
        return "LEFT JOIN";
      case JoinType.right:
        return "RIGHT JOIN";
    }
  }
}
