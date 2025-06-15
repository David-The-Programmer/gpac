import gleeunit

// import gpac/internal/sqlite

pub fn main() -> Nil {
  gleeunit.main()
}
// gleeunit test functions end in `_test`

// pub fn gen_stmt_columns_test() {
//   assert sqlite.gen_stmt_columns(["test1", "test2"]) == "(\"test1\", \"test2\")"
// }
//
// pub fn gen_stmt_values_test() {
//   let values = [
//     sqlite.Integer(1),
//     sqlite.Text("test"),
//     sqlite.Real(1.5),
//     sqlite.Null,
//   ]
//   assert sqlite.gen_stmt_values(values) == "(1, 'test', 1.5, NULL)"
// }
//
// pub fn gen_insert_stmt_test() {
//   let table = "test_table"
//   let columns = ["col1", "col2", "col3", "col4"]
//   let values = [
//     sqlite.Integer(1),
//     sqlite.Text("test"),
//     sqlite.Real(1.5),
//     sqlite.Null,
//   ]
//   assert sqlite.gen_insert_stmt(table, columns, values)
//     == "INSERT INTO test_table (\"col1\", \"col2\", \"col3\", \"col4\") VALUES (1, 'test', 1.5, NULL);"
// }
