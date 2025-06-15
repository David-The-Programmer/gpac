// import cake/delete as d
import cake
import cake/dialect/sqlite_dialect
import cake/insert as i

// import cake/select as s
// import cake/where as w
import envoy

// import gleam/decode/dynamic
import gleam/result
import simplifile
import sqlight

pub type BackendError {
  EnvoyError
  SimplifileError(simplifile.FileError)
  SqlightError(sqlight.Error)
  InvalidGradeString
  NotInitialised
}

pub type Grade {
  APlus
  A
  AMinus
  BPlus
  B
  BMinus
  CPlus
  C
  DPlus
  D
  F
  S
  U
}

fn config_dir_path() -> Result(String, BackendError) {
  envoy.get("HOME")
  |> result.map(fn(d) { d <> "/.config/gpac" })
  |> result.map_error(fn(_) { EnvoyError })
}

fn db_filepath() -> Result(String, BackendError) {
  use config_dir <- result.try(config_dir_path())
  let db_file = "gpac.db"

  Ok(config_dir <> "/" <> db_file)
}

fn has_config_dir() -> Result(Bool, BackendError) {
  use config_dir <- result.try(config_dir_path())

  simplifile.is_directory(config_dir)
  |> result.map_error(fn(e) { SimplifileError(e) })
}

fn has_db_file() -> Result(Bool, BackendError) {
  use db_filepath <- result.try(db_filepath())

  simplifile.is_file(db_filepath)
  |> result.map_error(fn(e) { SimplifileError(e) })
}

fn is_initialised() -> Result(Bool, BackendError) {
  use has_config_dir <- result.try(has_config_dir())
  use has_db_file <- result.try(has_db_file())

  Ok(has_config_dir && has_db_file)
}

pub fn initialise() -> Result(Nil, BackendError) {
  use has_config_dir <- result.try(has_config_dir())
  use config_dir <- result.try(config_dir_path())

  use _ <- result.try(fn() {
    case has_config_dir {
      True ->
        simplifile.delete(config_dir)
        |> result.map_error(fn(e) { SimplifileError(e) })
      False -> Ok(Nil)
    }
  }())

  use _ <- result.try(
    simplifile.create_directory(config_dir)
    |> result.map_error(fn(e) { SimplifileError(e) }),
  )

  use has_db_file <- result.try(has_db_file())
  use db_filepath <- result.try(db_filepath())

  use _ <- result.try(fn() {
    case has_db_file {
      True ->
        simplifile.delete(db_filepath)
        |> result.map_error(fn(e) { SimplifileError(e) })
      False -> Ok(Nil)
    }
  }())

  use conn <- result.try(
    sqlight.open(db_filepath)
    |> result.map_error(fn(e) { SqlightError(e) }),
  )

  let create_table_stmt =
    "CREATE TABLE IF NOT EXISTS modules (
    code TEXT PRIMARY KEY, 
    units INTEGER NOT NULL,
    grade TEXT NOT NULL
  );"

  use _ <- result.try(
    sqlight.exec(create_table_stmt, conn)
    |> result.map_error(fn(e) { SqlightError(e) }),
  )

  sqlight.close(conn)
  |> result.map_error(fn(e) { SqlightError(e) })
}

fn grade_to_grade_point(grade: Grade) -> Float {
  case grade {
    APlus -> 5.0
    A -> 5.0
    AMinus -> 4.5
    BPlus -> 4.0
    B -> 3.5
    BMinus -> 3.0
    CPlus -> 2.5
    C -> 2.0
    DPlus -> 1.5
    D -> 1.0
    _ -> 0.0
  }
}

fn grade_to_string(grade: Grade) -> String {
  case grade {
    APlus -> "A+"
    A -> "A"
    AMinus -> "A-"
    BPlus -> "B+"
    B -> "B"
    BMinus -> "B-"
    CPlus -> "C+"
    C -> "C"
    DPlus -> "D+"
    D -> "D"
    F -> "F"
    S -> "S"
    U -> "U"
  }
}

fn grade_string_to_grade(grade_str: String) -> Result(Grade, BackendError) {
  case grade_str {
    "A+" -> Ok(APlus)
    "A" -> Ok(A)
    "A-" -> Ok(AMinus)
    "B+" -> Ok(BPlus)
    "B" -> Ok(B)
    "B-" -> Ok(BMinus)
    "C+" -> Ok(CPlus)
    "C" -> Ok(C)
    "D+" -> Ok(DPlus)
    "D" -> Ok(D)
    "F" -> Ok(F)
    "S" -> Ok(S)
    "U" -> Ok(U)
    _ -> Error(InvalidGradeString)
  }
}

// pub fn add_module(
//   code: String,
//   units: Int,
//   grade: Grade,
// ) -> Result(Nil, BackendError) {
//   use is_init <- result.try(is_initialised())
//   use _ <- result.try(fn() {
//     case is_init {
//       False -> Error(NotInitialised)
//       True -> Ok(Nil)
//     }
//   }())
//   use db_filepath <- result.try(db_filepath())
//   use conn <- result.try(
//     sqlight.open(db_filepath)
//     |> result.map_error(fn(e) { SqlightError(e) }),
//   )
//
//   let insert_stmt =
//     [
//       [i.string(code), i.int(units), grade_to_string(grade) |> i.string]
//       |> i.row,
//     ]
//     |> i.from_values(table_name: "modules", columns: ["code", "units", "grade"])
//     |> i.to_query
//     |> sqlite_dialect.write_query_to_prepared_statement
//     |> cake.get_sql
//
//   use _ <- result.try(
//     sqlight.exec(insert_stmt, conn)
//     |> result.map_error(fn(e) { SqlightError(e) }),
//   )
//   Ok(Nil)
// }
