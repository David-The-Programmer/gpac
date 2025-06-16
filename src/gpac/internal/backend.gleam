import envoy
import gleam/dynamic/decode
import gleam/list
import gleam/result
import simplifile
import sqlight

pub type BackendError {
  EnvoyError
  SimplifileError(simplifile.FileError)
  SqlightError(sqlight.Error)
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

pub type Module {
  Module(code: String, units: Int, grade: Grade)
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

pub fn add_module(module: Module) -> Result(Nil, BackendError) {
  use is_init <- result.try(is_initialised())
  use _ <- result.try(fn() {
    case is_init {
      False -> Error(NotInitialised)
      True -> Ok(Nil)
    }
  }())
  use db_filepath <- result.try(db_filepath())
  use conn <- result.try(
    sqlight.open(db_filepath)
    |> result.map_error(fn(e) { SqlightError(e) }),
  )

  let prepared_stmt_sql =
    "INSERT INTO modules (\"code\", \"units\", \"grade\")
   VALUES (?, ?, ?);"

  let args = [
    sqlight.text(module.code),
    sqlight.int(module.units),
    sqlight.text(grade_to_string(module.grade)),
  ]

  use _ <- result.try(
    sqlight.query(prepared_stmt_sql, conn, args, decode.dynamic)
    |> result.map_error(fn(e) { SqlightError(e) }),
  )

  sqlight.close(conn)
  |> result.map_error(fn(e) { SqlightError(e) })
}

pub fn list_modules() -> Result(List(Module), BackendError) {
  use is_init <- result.try(is_initialised())
  use _ <- result.try(fn() {
    case is_init {
      False -> Error(NotInitialised)
      True -> Ok(Nil)
    }
  }())
  use db_filepath <- result.try(db_filepath())
  use conn <- result.try(
    sqlight.open(db_filepath)
    |> result.map_error(fn(e) { SqlightError(e) }),
  )

  let sql =
    "SELECT code, units, grade
     FROM modules;"

  let args = []

  let module_grade_decoder = {
    use module_grade_string <- decode.then(decode.string)
    case module_grade_string {
      "A+" -> decode.success(APlus)
      "A" -> decode.success(A)
      "A-" -> decode.success(AMinus)
      "B+" -> decode.success(BPlus)
      "B" -> decode.success(B)
      "B-" -> decode.success(BMinus)
      "C+" -> decode.success(CPlus)
      "C" -> decode.success(C)
      "D+" -> decode.success(DPlus)
      "D" -> decode.success(D)
      "F" -> decode.success(F)
      "S" -> decode.success(S)
      "U" -> decode.success(U)
      _ -> decode.failure(U, "module_grade")
    }
  }

  let module_decoder = {
    use code <- decode.field(0, decode.string)
    use units <- decode.field(1, decode.int)
    use grade <- decode.field(2, module_grade_decoder)
    decode.success(Module(code: code, units: units, grade: grade))
  }

  use modules <- result.try(
    sqlight.query(sql, conn, args, module_decoder)
    |> result.map_error(fn(e) { SqlightError(e) }),
  )

  sqlight.close(conn)
  |> result.map_error(fn(e) { SqlightError(e) })

  Ok(modules)
}

pub fn delete_module(module_code: String) -> Result(Nil, BackendError) {
  use is_init <- result.try(is_initialised())
  use _ <- result.try(fn() {
    case is_init {
      False -> Error(NotInitialised)
      True -> Ok(Nil)
    }
  }())
  use db_filepath <- result.try(db_filepath())
  use conn <- result.try(
    sqlight.open(db_filepath)
    |> result.map_error(fn(e) { SqlightError(e) }),
  )

  let sql =
    "DELETE FROM modules
     WHERE code = ?;"

  let args = [sqlight.text(module_code)]

  use _ <- result.try(
    sqlight.query(sql, conn, args, decode.dynamic)
    |> result.map_error(fn(e) { SqlightError(e) }),
  )

  sqlight.close(conn)
  |> result.map_error(fn(e) { SqlightError(e) })
}
