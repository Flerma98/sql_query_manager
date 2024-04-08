import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common/utils/utils.dart' as sqflite_utils;
import 'package:sql_query_manager/src/sql_tools.dart';

abstract class TableSql<T, CF, EF> {
  String get tableName;

  List<ColumnSql> get columns;

  T get instance;

  Map<ColumnSql, dynamic> insertMap(CF creationForm);

  Map<ColumnSql, dynamic> editMap(EF editionForm);

  String get toCreateQuery {
    final creation = columns.map((column) => column.toCreate).toList();
    final foreignKeys = columns.fold(
        [],
        (previousList, currentColumn) =>
            previousList..addAll(currentColumn.foreignKeys));
    creation.addAll(foreignKeys.map((fk) => fk.toCreate));
    return "CREATE TABLE IF NOT EXISTS $tableName (${creation.join(", ")});";
  }

  String makeSelect({final SqlSelectQueryParams<T>? queryParams}) {
    return SqlTable.selectQuery(
        table: tableName,
        instance: instance,
        params: queryParams ?? SqlSelectQueryParams<T>());
  }

  Future<int> makeInsert(
      {required final Database database,
      required final CF creationForm}) async {
    final map = insertMap(creationForm).map((key, value) =>
        MapEntry<String, dynamic>(
            key.columnName, ColumnSql.parseCorrectFormat(value)));
    return await database.insert(tableName, map,
        conflictAlgorithm: ConflictAlgorithm.fail);
  }

  Future<int> makeUpdate(
      {required final Database database,
      required final EF editionForm,
      required final List<ColumnExpressionSqL> Function(T) whereExpressions,
      final WhereUnion whereUnion = WhereUnion.and}) async {
    final map = editMap(editionForm).map((key, value) =>
        MapEntry<String, dynamic>(
            key.columnName, ColumnSql.parseCorrectFormat(value)));

    String? whereClause;

    if (whereExpressions(instance).isNotEmpty) {
      whereClause = whereExpressions(instance)
          .map((expression) =>
              "$tableName.${expression.column} ${expression.operation} ${expression.value}")
          .join(" ${whereUnion.name} ");
    }

    return await database.update(tableName, map,
        conflictAlgorithm: ConflictAlgorithm.rollback, where: whereClause);
  }

  Future<int> makeDelete(
      {required final Database database,
      required final List<ColumnExpressionSqL> Function(T) whereExpressions,
      final WhereUnion whereUnion = WhereUnion.and}) async {
    String? whereClause;
    if (whereExpressions(instance).isNotEmpty) {
      whereClause = whereExpressions(instance)
          .map((expression) =>
              "$tableName.${expression.column} ${expression.operation} ${expression.value}")
          .join(" ${whereUnion.name} ");
    }

    return await database.delete(tableName, where: whereClause);
  }

  List<String> getChangesToApply(
      {required final int oldVersion, required final int currentVersion}) {
    final queries = <int, List<String>>{};
    for (final columnToAdd in columns.where((column) =>
        column.addedInVersion > oldVersion &&
        column.addedInVersion <= currentVersion)) {
      final version = columnToAdd.addedInVersion;
      if (queries.containsKey(version)) {
        queries[version]!.add(columnToAdd.addScript(tableName: tableName));
      } else {
        queries[version] = [columnToAdd.addScript(tableName: tableName)];
      }
    }

    for (final columnToRemove in columns.where((column) =>
        column.removedInVersion != null &&
        column.removedInVersion! > oldVersion &&
        column.removedInVersion! <= currentVersion)) {
      final version = columnToRemove.addedInVersion;
      if (queries.containsKey(version)) {
        queries[version]!
            .add(columnToRemove.removeScript(tableName: tableName));
      } else {
        queries[version] = [columnToRemove.removeScript(tableName: tableName)];
      }
    }

    return queries.values.fold(
        [], (previousList, currentList) => previousList..addAll(currentList));
  }
}

class SqlCondition {
  final String syntax;

  SqlCondition(this.syntax);
}

class ColumnSql {
  ///The name of the column
  String columnName;

  ///The version specified in the database context
  int addedInVersion;

  ///The version specified in the database context
  int? removedInVersion;

  ///The type of the data
  SqlDataType dataType;

  ///If the column is the Primary-Key
  bool primaryKey;

  ///If the value is auto incremental
  bool autoIncrement;

  ///If the value is unique
  bool unique;

  ///If the value is not null
  bool notNull;

  ///If the value has a default value
  Object? defaultValue;

  ///If the column is a foreign key
  List<ForeignKeySqlColumn> foreignKeys;

  ColumnSql(
      {required this.columnName,
      required this.addedInVersion,
      this.removedInVersion,
      required this.dataType,
      this.primaryKey = false,
      this.autoIncrement = false,
      this.unique = false,
      this.notNull = false,
      this.defaultValue,
      this.foreignKeys = const <ForeignKeySqlColumn>[]});

  String get toCreate => [
        columnName,
        dataType.name.toUpperCase(),
        if (primaryKey) "PRIMARY KEY",
        if (autoIncrement) "AUTOINCREMENT",
        if (unique) "UNIQUE",
        if (notNull) "NOT NULL",
        if (canPutDefaultValue) "DEFAULT ${parseCorrectFormat(defaultValue)}"
      ].join(" ");

  bool get canPutDefaultValue {
    if (!notNull) return true;
    return notNull && defaultValue != null;
  }

  static Object? parseCorrectFormat(final dynamic value) {
    if (value == null) return null;
    if (value is ColumnSql) return value.columnName;
    if (value is SqlCondition) return value.syntax;
    if (value is List || value is Map) return json.encode(value);
    if (value is Color) return value.value.toRadixString(16);
    if (value is Enum) return value.index.toString();
    if (value is bool) return (value) ? 1 : 0;
    if (value is DateTime) return value.toIso8601TimeZonedString();
    if (value is Uint8List) return sqflite_utils.hex(value);
    if (value is String) return value;
    return value.toString();
  }

  String addScript({required final String tableName}) {
    return "ALTER TABLE $tableName ADD COLUMN $columnName ${dataType.name.toUpperCase()};";
  }

  String removeScript({required final String tableName}) {
    return "ALTER TABLE $tableName REMOVE COLUMN $columnName;";
  }
}

class ForeignKeySqlColumn {
  ///The name of the column with the foreign key
  final String columnForeignKey;

  ///The name of the table with the primary key
  final String tableName;

  ///The name of the column with the primary key
  final ColumnSql columnPrimaryKey;

  ///The rule wanted on the OnUpdate function
  final SqlForeignKeyRules onUpdateRule;

  ///The rule wanted on the OnDelete function
  final SqlForeignKeyRules onDeleteRule;

  ForeignKeySqlColumn(this.columnForeignKey,
      {required this.tableName,
      required this.columnPrimaryKey,
      this.onUpdateRule = SqlForeignKeyRules.cascade,
      this.onDeleteRule = SqlForeignKeyRules.cascade});

  String get toCreate => [
        "FOREIGN KEY ($columnForeignKey)",
        "REFERENCES $tableName (${columnPrimaryKey.columnName})",
        "ON UPDATE ${onUpdateRule.parameterText}",
        "ON DELETE ${onDeleteRule.parameterText}"
      ].join(" ");
}

enum SqlDataType { integer, real, text, blob, date, dateTime }

enum SqlForeignKeyRules { noAction, restrict, setNull, setDefault, cascade }

extension SqlForeignKeyRulesExtension on SqlForeignKeyRules {
  String get parameterText {
    switch (this) {
      case SqlForeignKeyRules.noAction:
        return "NO ACTION";
      case SqlForeignKeyRules.restrict:
        return "RESTRICT";
      case SqlForeignKeyRules.setNull:
        return "SET NULL";
      case SqlForeignKeyRules.setDefault:
        return "SET DEFAULT";
      case SqlForeignKeyRules.cascade:
        return "CASCADE";
    }
  }
}

enum WhereOrder { asc, desc }

enum WhereUnion { and, or }

extension DateTimeExtension on DateTime {
  String _myOwnTimeZoneFormatter({final Duration? offSet}) {
    if (toIso8601String().toLowerCase().contains("z")) return "";

    final timeZone = offSet ?? timeZoneOffset;
    if (timeZone.inSeconds == 0) {
      return "Z";
    }
    return "${timeZone.isNegative ? "" : "+"}${NumberFormat("##00").format(timeZone.inHours)}:${NumberFormat("##00").format(timeZone.inMinutes - timeZone.inHours * 60)}";
  }

  String toIso8601TimeZonedString({final Duration? offSet}) =>
      "${toIso8601String()}${_myOwnTimeZoneFormatter(offSet: offSet)}";
}
