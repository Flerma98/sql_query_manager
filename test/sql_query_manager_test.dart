import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sql_query_manager/sql_query_manager.dart';
import 'package:test/test.dart';

import '../example/tables/profiles/forms/create.dart';
import '../example/tables/profiles/table.dart';
import '../example/tables/users/forms/create.dart';
import '../example/tables/users/table.dart';

void main() {
  late final Database database;

  setUpAll(() async {
    print("*******************************************");
    print("Init database");
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final factory = databaseFactory;
    final dbPath = await factory.getDatabasesPath();
    await factory.deleteDatabase(dbPath);

    final databaseName = 'test_database.db';
    final databasePath = [dbPath, databaseName].join("/");

    database = await factory.openDatabase(databasePath,
        options: OpenDatabaseOptions(
            onOpen: (db) async {
              await db.execute("PRAGMA foreign_keys = ON");
            },
            onCreate: (db, version) async {
              await db.execute(UsersTable().toCreateQuery);
              await db.execute(ProfilesTable().toCreateQuery);
            },
            version: 1));
  });

  setUp(() async {
    if (!database.isOpen) throw "The database has been closed";
  });

  tearDownAll(() async {
    await database.close();
    print("The database closed");
    print("-------------------------------------------");
  });

  test('Create user Test', () async {
    await UsersTable().makeInsert(
        database: database,
        creationForm: UserCreationForm(username: "MyUsername"));
    final result = await database.query(UsersTable().tableName);
    expect(result, isNotEmpty);
  });

  test('Create profile for user Test', () async {
    await ProfilesTable().makeInsert(
        database: database,
        creationForm: ProfileCreationForm(
            userId: 1, firstName: "MyFirstName", lastName: "MyLastName"));
    final result = await database.query(ProfilesTable().tableName);
    expect(result, isNotEmpty);
  });

  test('Visualization Test', () async {
    final users = await database.rawQuery(UsersTable().makeSelect());
    print(users);
    final profiles = await database.rawQuery(ProfilesTable().makeSelect());
    print(profiles);
    expect(users, isNotEmpty);
    expect(profiles, isNotEmpty);
  });

  test('Visualization Single Test', () async {
    final query = UsersTable().makeSelect(
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
    print(query);
    final result = await database.rawQuery(query);
    print(result);
    expect(result, isNotEmpty);
  });

  test('Deletion Test', () async {
    final rowsAffected = await database.delete(UsersTable().tableName,
        where: "${UsersTable().localId.columnName} = ?", whereArgs: [1]);
    expect(rowsAffected, greaterThan(0));
  });
}
