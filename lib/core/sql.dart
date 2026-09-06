/// Tiny helpers for safe string interpolation into DuckDB SQL.
String sqlString(String value) => "'${value.replaceAll("'", "''")}'";

String sqlBool(bool value) => value ? 'TRUE' : 'FALSE';

String sqlNullableString(String? value) =>
    value == null ? 'NULL' : sqlString(value);

String sqlNullableNum(num? value) => value == null ? 'NULL' : '$value';

String sqlTimestamp(DateTime value) =>
    sqlString(value.toUtc().toIso8601String());
