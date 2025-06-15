// import cake/delete as d
import cake/insert as i

// import cake/select as s
// import cake/where as w
import envoy

// import gleam/decode/dynamic
import gleam/result
import simplifile
import sqlight

const db_file = "gpac.db"

pub type BackendError {
  EnvoyError
  SimplifileError(simplifile.FileError)
  SqlightError(sqlight.Error)
  InvalidGradeString
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

pub fn initialise() -> Result(Nil, BackendError) {
  use config_dir <- result.try(
    envoy.get("HOME")
    |> result.map(fn(d) { d <> "/.config/gpac" })
    |> result.map_error(fn(_) { EnvoyError }),
  )

  use _ <- result.try(
    simplifile.is_directory(config_dir)
    |> result.map_error(fn(e) { SimplifileError(e) })
    |> result.try(fn(is_dir) {
      case is_dir {
        False ->
          simplifile.create_directory(config_dir)
          |> result.map_error(fn(e) { SimplifileError(e) })
        _ -> Ok(Nil)
      }
    }),
  )

  let create_table_stmt =
    "CREATE TABLE IF NOT EXISTS modules (
    code TEXT PRIMARY KEY, 
    units INTEGER NOT NULL,
    grade TEXT NOT NULL
  );"

  use conn <- result.try(
    sqlight.open(config_dir <> "/" <> db_file)
    |> result.map_error(fn(e) { SqlightError(e) }),
  )

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

pub fn add_module(code: String, units: Int, grade: Grade) {
  todo
  // let insert_stmt = []
}
