import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sql_query_manager/sql_query_manager.dart';

import 'tables/profiles/forms/create.dart';
import 'tables/profiles/table.dart';
import 'tables/users/forms/create.dart';
import 'tables/users/table.dart';

void main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final factory = databaseFactory;
  final dbPath = await factory.getDatabasesPath();
  await factory.deleteDatabase(dbPath);

  final databaseName = 'test_database.db';
  final databasePath = [dbPath, databaseName].join("/");

  ///Init database
  final database = await factory.openDatabase(databasePath,
      options: OpenDatabaseOptions(
          onOpen: (db) async {
            await db.execute("PRAGMA foreign_keys = ON");
          },
          onCreate: (db, version) async {
            await db.execute(UsersTable().toCreateQuery);
            await db.execute(ProfilesTable().toCreateQuery);
          },
          version: 1));

  ///MAKE A CREATE IN THE 'USERS' TABLE
  await UsersTable().makeInsert(
      database: database,
      creationForm: UserCreationForm(username: "MyUsername"));
  final userCreated = await database.query(UsersTable().tableName);
  print(userCreated);

  ///MAKE A CREATE IN THE 'PROFILES' TABLE
  await ProfilesTable().makeInsert(
      database: database,
      creationForm: ProfileCreationForm(
          userId: 1, firstName: "MyFirstName", lastName: "MyLastName"));
  final profileCreated = await database.query(ProfilesTable().tableName);
  print(profileCreated);

  ///VISUALIZE AS A SIMPLE QUERY
  final users = await database.rawQuery(UsersTable().makeSelect());
  print(users);
  final profiles = await database.rawQuery(ProfilesTable().makeSelect());
  print(profiles);

  ///VISUALIZE THE DATA USING 'JOINS'
  final joinQuery = UsersTable().makeSelect(
      queryParams: SqlSelectQueryParams(
          joins: (mainTable) => [
                JoinQueryColumn<ProfilesTable>(
                    table: ProfilesTable(),
                    instance: ProfilesTable(),
                    onExpressions: (table) => [
                          OnExpressionColumnSqL(
                              originAlias: "users",
                              column: table.userId,
                              operation: "=",
                              value: mainTable.localId)
                        ])
              ],
          whereExpressions: (table) => [
                ColumnExpressionSqL(
                    column: table.localId, operation: "=", value: 1)
              ]));
  print(joinQuery);
  final joinedData = await database.rawQuery(joinQuery);
  print(joinedData);
}
