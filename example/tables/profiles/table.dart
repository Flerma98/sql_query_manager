import 'package:sql_query_manager/sql_query_manager.dart';

import '../users/table.dart';
import 'forms/create.dart';
import 'forms/replace.dart';

class ProfilesTable
    extends TableSql<ProfilesTable, ProfileCreationForm, ProfileReplaceForm> {
  @override
  String get tableName => "profiles";

  ColumnSql get localId => ColumnSql(
      columnName: "local_id",
      addedInVersion: 1,
      dataType: SqlDataType.integer,
      primaryKey: true,
      autoIncrement: true);

  ColumnSql get userId => ColumnSql(
          columnName: "user_id",
          addedInVersion: 1,
          dataType: SqlDataType.integer,
          notNull: true,
          foreignKeys: [
            ForeignKeySqlColumn("user_id",
                tableName: UsersTable().tableName,
                columnPrimaryKey: UsersTable().localId)
          ]);

  ColumnSql get firstName => ColumnSql(
      columnName: "first_name",
      addedInVersion: 1,
      dataType: SqlDataType.text,
      notNull: true);

  ColumnSql get lastName => ColumnSql(
      columnName: "last_name",
      addedInVersion: 1,
      dataType: SqlDataType.text,
      notNull: true);

  @override
  List<ColumnSql> get columns => [localId, userId, firstName, lastName];

  @override
  Map<ColumnSql, dynamic> insertMap(final ProfileCreationForm creationForm) {
    return {
      userId: creationForm.userId,
      firstName: creationForm.firstName,
      lastName: creationForm.lastName
    };
  }

  @override
  Map<ColumnSql, dynamic> editMap(final ProfileReplaceForm editionForm) {
    return {
      firstName: editionForm.firstName,
      lastName: editionForm.lastName
    };
  }

  @override
  ProfilesTable get instance => this;
}
