/// Tiny helpers for safe string interpolation into DuckDB SQL.
String sqlString(String value) => "'${value.replaceAll("'", "''")}'";

String sqlBool(bool value) => value ? 'TRUE' : 'FALSE';

String sqlNullableString(String? value) =>
    value == null ? 'NULL' : sqlString(value);

String sqlNullableNum(num? value) => value == null ? 'NULL' : '$value';

String sqlTimestamp(DateTime value) {
  final u = value.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  String three(int n) => n.toString().padLeft(3, '0');
  // DuckDB TIMESTAMP literals: avoid ISO-8601 `T`/`Z` (parser quirks on mobile).
  final body =
      '${u.year}-${two(u.month)}-${two(u.day)} ${two(u.hour)}:${two(u.minute)}:${two(u.second)}.${three(u.millisecond)}';
  return "'$body'";
}

/// Bare timestamp literal body (no quotes) for embedding in SQL strings.
String sqlTimestampLiteral(DateTime value) {
  final quoted = sqlTimestamp(value);
  return quoted.substring(1, quoted.length - 1);
}
