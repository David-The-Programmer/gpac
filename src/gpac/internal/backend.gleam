import envoy
import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/result
import simplifile

pub type BackendError {
  HomeDirNotFound
  DBDirCheckFail(simplifile.FileError)
  DBFileCheckFail(simplifile.FileError)
  InitCheckFail(BackendError)
  NotInitialised
  AlreadyInitialised
  ReadFromDBFileFail(simplifile.FileError)
  WriteToDBFileFail(simplifile.FileError)
  DecodeDBFail(json.DecodeError)
  RemoveDBDirFail(simplifile.FileError)
  CreateDBDirFail(simplifile.FileError)
  CreateDBFileFail(simplifile.FileError)
  ModuleNotFound
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

pub type Database {
  Database(modules: List(Module))
}

fn config_dir_path() -> Result(String, BackendError) {
  envoy.get("HOME")
  |> result.map(fn(d) { d <> "/.config/gpac" })
  |> result.map_error(fn(_) { HomeDirNotFound })
}

fn db_filepath() -> Result(String, BackendError) {
  use config_dir <- result.try(config_dir_path())
  let db_file = "gpac_db.json"

  Ok(config_dir <> "/" <> db_file)
}

fn has_config_dir() -> Result(Bool, BackendError) {
  use config_dir <- result.try(config_dir_path())

  simplifile.is_directory(config_dir)
  |> result.map_error(fn(e) { DBDirCheckFail(e) })
}

fn has_db_file() -> Result(Bool, BackendError) {
  use db_filepath <- result.try(db_filepath())

  simplifile.is_file(db_filepath)
  |> result.map_error(fn(e) { DBFileCheckFail(e) })
}

pub fn is_initialised() -> Result(Bool, BackendError) {
  use has_config_dir <- result.try(
    has_config_dir()
    |> result.map_error(fn(e) { InitCheckFail(e) }),
  )
  use has_db_file <- result.try(
    has_db_file()
    |> result.map_error(fn(e) { InitCheckFail(e) }),
  )

  Ok(has_config_dir && has_db_file)
}

pub fn grade_to_string(grade: Grade) -> String {
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

fn module_to_json(module: Module) -> json.Json {
  json.object([
    #("code", json.string(module.code)),
    #("units", json.int(module.units)),
    #("grade", json.string(module.grade |> grade_to_string)),
  ])
}

fn db_to_json(db: Database) -> json.Json {
  json.object([#("modules", json.array(db.modules, module_to_json))])
}

fn write_db_to_file(filepath: String, db: Database) -> Result(Nil, BackendError) {
  let db_json_str = db_to_json(db) |> json.to_string
  simplifile.write(filepath, db_json_str)
  |> result.map_error(fn(e) { WriteToDBFileFail(e) })
}

pub fn module_grade_decoder() -> decode.Decoder(Grade) {
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

fn db_from_json(db_json: String) -> Result(Database, json.DecodeError) {
  let module_decoder = {
    use code <- decode.field("code", decode.string)
    use units <- decode.field("units", decode.int)
    use grade <- decode.field("grade", module_grade_decoder())
    decode.success(Module(code: code, units: units, grade: grade))
  }

  let db_decoder = {
    use modules <- decode.field("modules", decode.list(module_decoder))
    decode.success(Database(modules: modules))
  }

  json.parse(db_json, db_decoder)
}

fn read_db_from_file(filepath: String) -> Result(Database, BackendError) {
  use db_json <- result.try(
    simplifile.read(filepath)
    |> result.map_error(fn(e) { ReadFromDBFileFail(e) }),
  )
  db_from_json(db_json) |> result.map_error(fn(e) { DecodeDBFail(e) })
}

fn init_checks(force_init: Bool) -> Result(Nil, BackendError) {
  case force_init {
    True -> Ok(Nil)
    False -> {
      use is_init <- result.try(is_initialised())
      case is_init {
        True -> Error(AlreadyInitialised)
        _ -> Ok(Nil)
      }
    }
  }
}

pub fn initialise(force_init: Bool) -> Result(Nil, BackendError) {
  use _ <- result.try(init_checks(force_init))

  use has_config_dir <- result.try(has_config_dir())
  use config_dir <- result.try(config_dir_path())

  use _ <- result.try(fn() {
    case has_config_dir {
      True ->
        simplifile.delete(config_dir)
        |> result.map_error(fn(e) { RemoveDBDirFail(e) })
      False -> Ok(Nil)
    }
  }())

  use _ <- result.try(
    simplifile.create_directory(config_dir)
    |> result.map_error(fn(e) { CreateDBDirFail(e) }),
  )

  use db_filepath <- result.try(db_filepath())
  write_db_to_file(db_filepath, Database([]))
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
  use db <- result.try(read_db_from_file(db_filepath))
  let new_db = Database(modules: [module, ..db.modules] |> list.reverse)
  write_db_to_file(db_filepath, new_db)
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
  use db <- result.try(read_db_from_file(db_filepath))
  Ok(db.modules)
}

pub fn remove_module(module_code: String) -> Result(Nil, BackendError) {
  use is_init <- result.try(is_initialised())
  use _ <- result.try(fn() {
    case is_init {
      False -> Error(NotInitialised)
      True -> Ok(Nil)
    }
  }())
  use db_filepath <- result.try(db_filepath())
  use db <- result.try(read_db_from_file(db_filepath))

  use _ <- result.try(
    list.find(db.modules, fn(module) { module.code == module_code })
    |> result.map_error(fn(_) { ModuleNotFound }),
  )

  let new_db =
    Database(
      modules: db.modules
      |> list.filter(fn(module) { module.code != module_code }),
    )
  write_db_to_file(db_filepath, new_db)
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

fn calculate_gpa(modules: List(Module)) -> Float {
  let sum_gradepoint_units_product =
    modules
    |> list.filter(fn(module) { module.grade != S && module.grade != U })
    |> list.fold(0.0, fn(acc, module) {
      let grade_point = grade_to_grade_point(module.grade)
      acc +. { grade_point *. int.to_float(module.units) }
    })

  let total_units =
    modules
    |> list.filter(fn(module) { module.grade != S && module.grade != U })
    |> list.fold(0, fn(acc, module) { acc + module.units })
    |> int.to_float

  sum_gradepoint_units_product /. total_units
}

pub fn gpa() -> Result(Float, BackendError) {
  use modules <- result.try(list_modules())
  Ok(calculate_gpa(modules))
}
