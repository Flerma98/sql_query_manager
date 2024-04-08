import 'package:sql_query_manager/sql_query_manager.dart';

import 'forms/create.dart';
import 'forms/replace.dart';

class UsersTable
    extends TableSql<UsersTable, UserCreationForm, UserEditionReplace> {
  ///The name of the table
  @override
  String get tableName => "users";

  ///Columns properties of the table
  ColumnSql get localId => ColumnSql(
      columnName: "local_id",
      addedInVersion: 1,
      dataType: SqlDataType.integer,
      primaryKey: true,
      autoIncrement: true);

  ColumnSql get username => ColumnSql(
      columnName: "username",
      addedInVersion: 1,
      dataType: SqlDataType.text,
      notNull: true,
      unique: true);

  ///This list is used for internal management of columns in the database
  @override
  List<ColumnSql> get columns => [localId, username];

  ///These will be the data that will be sent in the INSERT INTO
  @override
  Map<ColumnSql, dynamic> insertMap(final UserCreationForm creationForm) {
    return {username: creationForm.username};
  }

  ///These will be the data that will be sent in the UPDATE
  @override
  Map<ColumnSql, dynamic> editMap(final UserEditionReplace editionForm) {
    return {username: editionForm.username};
  }

  ///The instance must always reference itself (for internal use in development)
  @override
  get instance => this;
}
