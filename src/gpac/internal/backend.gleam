import envoy
import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
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
  ModuleAlreadyExists
}

fn decode_error_desc(decode_error: decode.DecodeError) -> String {
  case decode_error {
    decode.DecodeError(expected, found, path) ->
      "expected: "
      <> expected
      <> ", "
      <> "found: "
      <> found
      <> ", "
      <> "path: "
      <> path
      |> string.join(".")
  }
}

fn decode_errors_desc(errors: List(decode.DecodeError)) -> String {
  "\n"
  <> errors
  |> list.map(fn(e) { decode_error_desc(e) })
  |> string.join("\n")
}

fn json_decode_error_desc(error: json.DecodeError) -> String {
  case error {
    json.UnexpectedEndOfInput -> "unexpected end of input"
    json.UnexpectedByte(str) -> "unexpected byte: " <> str
    json.UnexpectedSequence(str) -> "unexpected sequence: " <> str
    json.UnableToDecode(decode_errors) -> decode_errors_desc(decode_errors)
  }
}

pub fn error_description(error: BackendError) -> String {
  case error {
    HomeDirNotFound -> "could not find HOME directory"
    DBDirCheckFail(err) ->
      "could not check if database directory exists: "
      <> simplifile.describe_error(err)
    DBFileCheckFail(err) ->
      "could not check if database file exists: "
      <> simplifile.describe_error(err)
    InitCheckFail(err) ->
      "initialisation checks failed: " <> error_description(err)
    NotInitialised -> "backend is not initialised"
    AlreadyInitialised -> "backend is already initialised"
    ReadFromDBFileFail(err) ->
      "could not read from database file: " <> simplifile.describe_error(err)
    WriteToDBFileFail(err) ->
      "could not write to database file: " <> simplifile.describe_error(err)
    DecodeDBFail(err) ->
      "could not decode database file: " <> json_decode_error_desc(err)
    RemoveDBDirFail(err) ->
      "could not remove database directory: " <> simplifile.describe_error(err)
    CreateDBDirFail(err) ->
      "could not create database directory: " <> simplifile.describe_error(err)
    CreateDBFileFail(err) ->
      "could not create database file: " <> simplifile.describe_error(err)
    ModuleNotFound -> "module could not be found"
    ModuleAlreadyExists -> "module already exists"
  }
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
  Module(code: String, units: Int, grade: Grade, simulated_grade: Grade)
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
    #("simulated_grade", json.string(module.simulated_grade |> grade_to_string)),
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
    use simulated_grade <- decode.field(
      "simulated_grade",
      module_grade_decoder(),
    )
    decode.success(Module(
      code: code,
      units: units,
      grade: grade,
      simulated_grade: simulated_grade,
    ))
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
  case list.find(db.modules, fn(mod) { mod.code == module.code }) {
    Ok(_) -> Error(ModuleAlreadyExists)
    Error(Nil) -> {
      let new_db = Database(modules: [module, ..db.modules])
      write_db_to_file(db_filepath, new_db)
    }
  }
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

fn calculate_gpa(grade_info: List(#(Int, Grade))) -> Float {
  let sum_gradepoint_units_product =
    grade_info
    |> list.filter(fn(info) {
      let #(_, grade) = info
      grade != S && grade != U
    })
    |> list.fold(0.0, fn(acc, info) {
      let #(units, grade) = info
      let grade_point = grade_to_grade_point(grade)
      acc +. { grade_point *. int.to_float(units) }
    })

  let total_units =
    grade_info
    |> list.filter(fn(info) {
      let #(_, grade) = info
      grade != S && grade != U
    })
    |> list.fold(0, fn(acc, info) {
      let #(units, _) = info
      acc + units
    })
    |> int.to_float

  sum_gradepoint_units_product /. total_units
}

pub fn gpa(
  include_simulated: Bool,
) -> Result(#(Float, Option(Float)), BackendError) {
  use modules <- result.try(list_modules())
  let gpa =
    modules
    |> list.map(fn(module) { #(module.units, module.grade) })
    |> calculate_gpa

  case include_simulated {
    False -> Ok(#(gpa, None))
    True -> {
      let simulated_gpa =
        modules
        |> list.map(fn(module) { #(module.units, module.simulated_grade) })
        |> calculate_gpa
      Ok(#(gpa, Some(simulated_gpa)))
    }
  }
}

pub fn simulate_module_grade(
  module_code: String,
  grade: Grade,
) -> Result(Nil, BackendError) {
  use is_init <- result.try(is_initialised())
  use _ <- result.try(fn() {
    case is_init {
      False -> Error(NotInitialised)
      True -> Ok(Nil)
    }
  }())
  use db_filepath <- result.try(db_filepath())
  use db <- result.try(read_db_from_file(db_filepath))

  use module <- result.try(
    list.find(db.modules, fn(module) { module.code == module_code })
    |> result.map_error(fn(_) { ModuleNotFound }),
  )
  let new_module = Module(..module, simulated_grade: grade)
  let new_modules =
    db.modules
    |> list.chunk(fn(mod) { mod.code == module_code })
    |> list.flat_map(fn(chunk) {
      case chunk == [module] {
        True -> [new_module]
        False -> chunk
      }
    })
  let new_db = Database(modules: new_modules)
  write_db_to_file(db_filepath, new_db)
}

pub type ModuleUnitsField {
  Units(Int)
}

pub type ModuleGradeField {
  Grade(Grade)
}

pub fn update_module(
  module_code: String,
  updated_fields: #(Option(ModuleUnitsField), Option(ModuleGradeField)),
) -> Result(Nil, BackendError) {
  use is_init <- result.try(is_initialised())
  use _ <- result.try(fn() {
    case is_init {
      False -> Error(NotInitialised)
      True -> Ok(Nil)
    }
  }())
  use db_filepath <- result.try(db_filepath())
  use db <- result.try(read_db_from_file(db_filepath))

  use module <- result.try(
    list.find(db.modules, fn(module) { module.code == module_code })
    |> result.map_error(fn(_) { ModuleNotFound }),
  )
  let updated_module = case updated_fields {
    #(Some(Units(units)), Some(Grade(grade))) ->
      Module(..module, units: units, grade: grade)
    #(Some(Units(units)), None) -> Module(..module, units: units)
    #(None, Some(Grade(grade))) -> Module(..module, grade: grade)
    _ -> module
  }

  let new_modules =
    db.modules
    |> list.chunk(fn(mod) { mod.code == module_code })
    |> list.flat_map(fn(chunk) {
      case chunk == [module] {
        True -> [updated_module]
        False -> chunk
      }
    })
  let new_db = Database(modules: new_modules)
  write_db_to_file(db_filepath, new_db)
}
