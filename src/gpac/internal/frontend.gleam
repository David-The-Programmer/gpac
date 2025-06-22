import gleam/dynamic
import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import gleam/option.{Some, None}
import gpac/internal/backend
import glint

type FrontendError {
  ArgValidationError(arg_name: String, issue: String)
}

pub fn gpac() -> glint.Command(Nil) {
  let help_text =
    "CLI tool to calculate GPA and simulate S/U options.

  Run 'gpac (SUBCOMMAND) --help' to get more info of each subcommand."
  use <- glint.command_help(help_text)
  use _, _, _ <- glint.command()
  io.println("Try 'gpac --help' for more information.")
}

fn force_flag() -> glint.Flag(Bool) {
  let help_text =
    "Use the --force=true or --force flag to forcefully reinitialise gpac.

  This will wipe out all existing data, use this flag with caution."

  glint.bool_flag("force")
  |> glint.flag_default(False)
  |> glint.flag_help(help_text)
}

pub fn init() -> glint.Command(Nil) {
  let help_text = "Initialise gpac to be ready for use."
  use <- glint.command_help(help_text)
  use <- glint.unnamed_args(glint.EqArgs(0))
  use force <- glint.flag(force_flag())
  use _, _, flags <- glint.command()
  let assert Ok(force_init) = force(flags)

  case backend.initialise(force_init) {
    Ok(Nil) -> io.println("gpac successfully initialised!")
    Error(backend.InitCheckFail(backend.DBDirCheckFail(_))) -> {
      io.println(
        "gpac failed to initialise: could not check if db directory exists",
      )
    }
    Error(backend.InitCheckFail(backend.DBFileCheckFail(_))) -> {
      io.println("gpac failed to initialise: could not check if db file exists")
    }
    Error(backend.AlreadyInitialised) -> {
      io.println(
        "gpac is already initialised, use --force to override, but proceed with caution, run 'gpac init --help to find out more.",
      )
    }
    Error(backend.RemoveDBDirFail(_)) -> {
      io.println(
        "gpac failed to initialise: failed to remove previous db directory",
      )
    }
    Error(backend.CreateDBDirFail(_)) -> {
      io.println("gpac failed to initialise: failed to create new db directory")
    }
    Error(backend.WriteToDBFileFail(_)) -> {
      io.println("gpac failed to initialise: failed to create new db file")
    }
    _ -> io.println("gpac failed to initialise: unexpected error")
  }
}

fn validate_units_arg(units_arg: String) -> Result(Int, FrontendError) {
  int.parse(units_arg)
  |> result.map_error(fn(_) {
    ArgValidationError("units", "'units' given is not a number")
  })
  |> result.try(fn(units) {
    case units >= 0 {
      True -> Ok(units)
      False ->
        Error(ArgValidationError(
          "units",
          "'units' given is not greater than or equal to 0",
        ))
    }
  })
}

fn validate_grade_arg(grade_arg: String) -> Result(backend.Grade, FrontendError) {
  let decoder = backend.module_grade_decoder()
  decode.run(dynamic.string(grade_arg), decoder)
  |> result.map_error(fn(_) {
    ArgValidationError(
      "grade",
      "'grade' given is not one of the following values: A+, A, A-, B+, B, B-, C+, C, D+, D, F, S, U",
    )
  })
}

pub fn add() -> glint.Command(Nil) {
  let help_text =
    "Add module code, units and grade info to gpac.

  Note: <grade> can only be 1 of the following values:

  A+, A, A-, B+, B, B-, C+, C, D+, D, F, S, U
  "
  use <- glint.command_help(help_text)
  use <- glint.unnamed_args(glint.EqArgs(0))
  use module_code <- glint.named_arg("code")
  use module_units <- glint.named_arg("units")
  use module_grade <- glint.named_arg("grade")
  use named_args, _, _ <- glint.command()

  let code = module_code(named_args)
  let units_str = module_units(named_args)
  let grade_str = module_grade(named_args)

  let arg_validation = {
    use units <- result.try(validate_units_arg(units_str))
    use grade <- result.try(validate_grade_arg(grade_str))
    Ok(#(units, grade))
  }

  case arg_validation {
    Error(ArgValidationError(arg_name, issue)) -> {
      io.println("'" <> arg_name <> "' error: " <> issue)
      io.println(
        "Run 'gpac add --help' for more info on the"
        <> "'"
        <> arg_name
        <> "' argument",
      )
    }
    Ok(#(units, grade)) -> {
      let result = backend.add_module(backend.Module(code, units, grade, grade))
      case result {
        Ok(Nil) -> io.println("successfully added module to gpac!")
        Error(backend.NotInitialised) ->
          io.println(
            "gpac is not initialised, run 'gpac init' to initialise gpac and try again.",
          )
        Error(backend.ReadFromDBFileFail(_)) ->
          io.println("gpac failed to add module: could not read from db file.")
        Error(backend.WriteToDBFileFail(_)) ->
          io.println("gpac failed to add module: could not write to db file.")
        _ -> {
          io.println("gpac failed to add module: unexpected error.")
        }
      }
    }
  }
}

fn split_by_size_inner(
  str: String,
  size: Int,
  acc: List(String),
) -> List(String) {
  case str {
    "" -> list.reverse(acc)
    _ -> {
      let str_len = string.length(str)
      let head = string.slice(str, 0, size)
      let rest = string.slice(str, size, str_len - size)
      split_by_size_inner(rest, size, [head, ..acc])
    }
  }
}

pub fn split_by_size(str: String, size: Int) -> List(String) {
  split_by_size_inner(str, size, [])
}

fn format_table_body(
  table_body: List(List(String)),
  table_width: Int,
) -> List(List(String)) {
  table_body
  |> list.flat_map(fn(row) {
    let num_cols = list.length(row)
    let col_width = { table_width - { num_cols + 1 } } / num_cols
    let assert Ok(max_new_rows) =
      row
      |> list.map(fn(col) {
        let col_value_len = string.length(col)
        { int.to_float(col_value_len) /. int.to_float(col_width) }
        |> float.ceiling
        |> float.truncate
      })
      |> list.max(int.compare)

    list.repeat(row, max_new_rows)
    |> list.index_map(fn(row, i) {
      row
      |> list.map(fn(col) {
        col
        |> split_by_size(col_width)
        |> list.index_map(fn(v, j) {
          case i == j {
            True -> v
            False -> ""
          }
        })
        |> string.join("")
      })
    })
  })
  |> list.map(fn(row) {
    let col_width =
      { table_width - { list.length(row) + 1 } } / list.length(row)
    row
    |> list.index_map(fn(col, i) {
      let num_cols = list.length(row)
      let diff = table_width - { { num_cols * col_width } + { num_cols + 1 } }
      case i == { num_cols - 1 } {
        True -> string.pad_end(col, col_width + diff, " ")
        False -> string.pad_end(col, col_width, " ")
      }
    })
  })
}

fn print_row(row: List(String)) -> Nil {
  case row {
    [] -> io.print("\n")
    [col, ..rest] -> {
      io.print(col <> "|")
      print_row(rest)
    }
  }
}

fn print_table_body(body: List(List(String))) -> Nil {
  case body {
    [] -> Nil
    [row, ..rest] -> {
      io.print("|")
      print_row(row)
      print_table_body(rest)
    }
  }
}

fn pretty_print_table(
  body: List(List(String)),
  headers: List(String),
  width: Int,
) -> Nil {
  io.println("+" <> string.repeat("-", width - 2) <> "+")

  [headers]
  |> format_table_body(width)
  |> print_table_body
  io.println(string.repeat("-", width))

  body
  |> format_table_body(width)
  |> print_table_body

  io.println("+" <> string.repeat("-", width - 2) <> "+")
}

fn pretty_print_mods(modules: List(backend.Module)) -> Nil {
  let table_width = 100
  modules
  |> list.map(fn(mod) {
    [
      mod.code,
      int.to_string(mod.units),
      backend.grade_to_string(mod.grade),
      backend.grade_to_string(mod.simulated_grade),
    ]
  })
  |> pretty_print_table(
    ["Module Code", "Units", "Grade", "Simulated Grade"],
    table_width,
  )
}

pub fn list() -> glint.Command(Nil) {
  let help_text = "Lists all modules stored in gpac."
  use <- glint.command_help(help_text)
  use <- glint.unnamed_args(glint.EqArgs(0))
  use _, _, _ <- glint.command()

  case backend.list_modules() {
    Ok(modules) -> pretty_print_mods(modules)
    Error(backend.NotInitialised) -> {
      io.println(
        "gpac is not initialised, run 'gpac init' to initialise gpac and try again.",
      )
    }
    Error(backend.ReadFromDBFileFail(_)) -> {
      io.println("gpac failed to list modules: could not read from db file.")
    }
    _ -> io.println("gpac failed to list modules: unexpected error.")
  }
}

pub fn remove() -> glint.Command(Nil) {
  let help_text = "Deletes all module info of given module code."
  use <- glint.command_help(help_text)
  use <- glint.unnamed_args(glint.EqArgs(0))
  use module_code <- glint.named_arg("code")
  use named_args, _, _ <- glint.command()
  let code = module_code(named_args)

  case backend.remove_module(code) {
    Ok(Nil) -> io.println("successfully removed module")
    Error(backend.NotInitialised) -> {
      io.println(
        "gpac is not initialised, run 'gpac init' to initialise gpac and try again.",
      )
    }
    Error(backend.ReadFromDBFileFail(_)) -> {
      io.println("gpac failed to remove module: could not read from db file.")
    }
    Error(backend.ModuleNotFound) -> {
      io.println("gpac failed to remove module: module not found.")
    }
    Error(backend.WriteToDBFileFail(_)) -> {
      io.println("gpac failed to remove module: could not write to db file.")
    }
    _ -> io.println("gpac failed to remove module: unexpected error.")
  }
}

fn simulate_flag() -> glint.Flag(Bool) {
  let help_text =
    "Use the --include-simulated=true or --include-simulated flag to ask gpac to calculate and show the simulated grade"
  glint.bool_flag("include-simulated")
  |> glint.flag_default(False)
  |> glint.flag_help(help_text)
}

pub fn gpa() -> glint.Command(Nil) {
  let help_text = "Calculates the cumulative GPA of all modules added to gpac."
  use <- glint.command_help(help_text)
  use <- glint.unnamed_args(glint.EqArgs(0))
  use simulate <- glint.flag(simulate_flag())
  use _, _, flags <- glint.command()
  let assert Ok(include_simulated) = simulate(flags)

  case backend.gpa(include_simulated) {
    Ok(#(gpa, simulated_gpa_option)) -> {
      io.println("Actual GPA: " <> float.to_string(gpa))
      case simulated_gpa_option {
        Some(simulated_gpa) ->
          io.println("Simulated GPA: " <> float.to_string(simulated_gpa))
        None -> io.println("")
      }
    }
    Error(backend.NotInitialised) -> {
      io.println(
        "gpac is not initialised, run 'gpac init' to initialise gpac and try again.",
      )
    }
    Error(backend.ReadFromDBFileFail(_)) -> {
      io.println("gpac failed to calculate GPA: could not read from db file.")
    }
    _ -> io.println("gpac failed to calculate GPA: unexpected error.")
  }
}

pub fn simulate() -> glint.Command(Nil) {
  let help_text =
    "Allows user to simulate grades for their modules, including S/U options.


    Run 'gpac simulate <code> <grade>' to update the simulated grade of module with given module code. This simulated grade will be used to calculate the simulated GPA, i.e, GPA that uses the simulated grade (instead of actual grade) of each module.


    Subsequently, run 'gpac gpa --include-simulated' to see the simulated GPA and actual GPA.


  Note: <grade> can only be 1 of the following values:

  A+, A, A-, B+, B, B-, C+, C, D+, D, F, S, U
  "
  use <- glint.command_help(help_text)
  use <- glint.unnamed_args(glint.EqArgs(0))
  use module_code <- glint.named_arg("code")
  use module_grade <- glint.named_arg("grade")
  use named_args, _, _ <- glint.command()

  let code = module_code(named_args)
  let grade_str = module_grade(named_args)

  let arg_validation = {
    use grade <- result.try(validate_grade_arg(grade_str))
    Ok(#(code, grade))
  }

  case arg_validation {
    Error(ArgValidationError(arg_name, issue)) -> {
      io.println("'" <> arg_name <> "' error: " <> issue)
      io.println(
        "Run 'gpac simulate --help' for more info on the"
        <> "'"
        <> arg_name
        <> "' argument",
      )
    }
    Ok(#(code, grade)) -> {
      let result = backend.simulate_module_grade(code, grade)
      case result {
        Ok(Nil) -> io.println("successfully updated simulated grade of module!")
        Error(backend.NotInitialised) ->
          io.println(
            "gpac is not initialised, run 'gpac init' to initialise gpac and try again.",
          )
        Error(backend.ReadFromDBFileFail(_)) ->
          io.println(
            "gpac failed to update simulated grade of module: could not read from db file.",
          )
        Error(backend.ModuleNotFound) ->
          io.println(
            "gpac failed to update simulated grade of module: module not found.",
          )
        Error(backend.WriteToDBFileFail(_)) ->
          io.println(
            "gpac failed to update simulated grade of module: could not write to db file.",
          )
        _ ->
          io.println(
            "gpac failed to update simulated grade of module: unexpected error.",
          )
      }
    }
  }
}
