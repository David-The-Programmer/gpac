import gleam/dynamic
import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import glint
import glint/constraint
import gpac/internal/backend
import snag

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

fn defer(cleanup: fn() -> Nil, body: fn() -> a) -> a {
  let res = body()
  cleanup()
  res
}

fn force_flag() -> glint.Flag(Bool) {
  let help_text =
    "Use the flag --force=true or --force to forcefully reinitialise gpac.

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

  let init_result = backend.initialise(force_init)
  use <- defer(fn() {
    case init_result {
      Error(err) -> {
        io.println(
          "ERROR: gpac failed to initialise: " <> backend.error_description(err),
        )
      }
      Ok(_) -> Nil
    }
  })
  case init_result {
    Ok(Nil) -> io.println("gpac successfully initialised!")
    Error(backend.AlreadyInitialised) ->
      io.println(
        "gpac is already initialised, use --force to override, but proceed with caution, run 'gpac init --help' for more info.",
      )
    _ -> Nil
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
          "given argument is not greater than or equal to 0",
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
      "given argument is not one of the following values: \nA+, A, A-, B+, B, B-, C+, C, D+, D, F, S, U",
    )
  })
}

pub fn add() -> glint.Command(Nil) {
  let help_text =
    "Add module code, units and grade info to gpac.

  Note: <grade> can only be one of the following values:

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
      io.println("ERROR: argument <" <> arg_name <> ">: " <> issue)
      io.println(
        "Run 'gpac add --help' for more info on the "
        <> "<"
        <> arg_name
        <> "> argument.",
      )
    }
    Ok(#(units, grade)) -> {
      let result = backend.add_module(backend.Module(code, units, grade, grade))
      use <- defer(fn() {
        case result {
          Error(err) ->
            io.println(
              "ERROR: gpac failed to add module: "
              <> backend.error_description(err),
            )
          Ok(_) -> Nil
        }
      })
      case result {
        Ok(Nil) -> io.println("successfully added module to gpac!")
        Error(backend.NotInitialised) ->
          io.println(
            "gpac is not initialised, run 'gpac init' to initialise gpac and try again.",
          )
        Error(backend.ModuleAlreadyExists) -> {
          io.println(
            "gpac could not add the given module info as a module with the same code already exists.",
          )
          io.println(
            "If you want to edit properties of the module of the given code, run 'gpac update <code> [ --grade=<STRING> --units=<INT> ]'.",
          )
          io.println("Run 'gpac update --help' for more info.")
        }
        _ -> Nil
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
  let table_width = 80
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

  let list_result = backend.list_modules()
  use <- defer(fn() {
    case list_result {
      Error(err) ->
        io.println(
          "ERROR: gpac failed to list modules: "
          <> backend.error_description(err),
        )
      Ok(_) -> Nil
    }
  })
  case list_result {
    Ok(modules) -> pretty_print_mods(modules)
    Error(backend.NotInitialised) ->
      io.println(
        "gpac is not initialised, run 'gpac init' to initialise gpac and try again.",
      )
    _ -> Nil
  }
}

pub fn remove() -> glint.Command(Nil) {
  let help_text = "Deletes all module info of given module code."
  use <- glint.command_help(help_text)
  use <- glint.unnamed_args(glint.EqArgs(0))
  use module_code <- glint.named_arg("code")
  use named_args, _, _ <- glint.command()
  let code = module_code(named_args)

  let remove_result = backend.remove_module(code)
  use <- defer(fn() {
    case remove_result {
      Error(err) ->
        io.println(
          "ERROR: gpac failed to remove module: "
          <> backend.error_description(err),
        )
      Ok(_) -> Nil
    }
  })

  case remove_result {
    Ok(Nil) -> io.println("successfully removed module")
    Error(backend.NotInitialised) -> {
      io.println(
        "gpac is not initialised, run 'gpac init' to initialise gpac and try again.",
      )
    }
    Error(backend.ModuleNotFound) ->
      io.println(
        "gpac could not remove module of given code as no such module with given code exists. \nRun 'gpac list' to see all modules added to gpac.",
      )
    _ -> Nil
  }
}

fn simulate_flag() -> glint.Flag(Bool) {
  let help_text =
    "Use the flag --include-simulated=true or --include-simulated to ask gpac to calculate and show the simulated grade, by default the flag is set to 'false'"
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

  let gpa_result = backend.gpa(include_simulated)

  use <- defer(fn() {
    case gpa_result {
      Error(err) ->
        io.println(
          "ERROR: gpac failed to calculate gpa: "
          <> backend.error_description(err),
        )
      Ok(_) -> Nil
    }
  })

  case gpa_result {
    Ok(#(gpa, simulated_gpa_option)) -> {
      io.println("Actual GPA: " <> float.to_string(gpa))
      case simulated_gpa_option {
        Some(simulated_gpa) ->
          io.println("Simulated GPA: " <> float.to_string(simulated_gpa))
        None -> Nil
      }
    }
    Error(backend.NotInitialised) ->
      io.println(
        "gpac is not initialised, run 'gpac init' to initialise gpac and try again.",
      )
    _ -> Nil
  }
}

// TODO: log error using defer in gpa, simulate, update
pub fn simulate() -> glint.Command(Nil) {
  let help_text =
    "Allows user to simulate grades for their modules, including S/U options.


    Run 'gpac simulate <code> <grade>' to set the simulated grade of the given module. This simulated grade will be used to calculate the simulated GPA, i.e, GPA that uses the simulated grade (instead of actual grade) of each module.


    Subsequently, run 'gpac gpa --include-simulated' to see the simulated GPA and actual GPA.


  Note: <grade> can only be one of the following values:

  A+, A, A-, B+, B, B-, C+, C, D+, D, F, S, U


  Example: 

  In order to simulate using S/U option for a module of code CS1231S, 
  run 'gpac simulate CS1231S S' to set the simulated grade of CS1231S module to be Satisfactory.
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
      io.println("ERROR: argument <" <> arg_name <> ">: " <> issue)
      io.println(
        "Run 'gpac simulate --help' for more info on the "
        <> "<"
        <> arg_name
        <> "> argument.",
      )
    }
    Ok(#(code, grade)) -> {
      let result = backend.simulate_module_grade(code, grade)
      use <- defer(fn() {
        case result {
          Error(err) ->
            io.println(
              "ERROR: gpac failed to set simulated grade: "
              <> backend.error_description(err),
            )
          Ok(_) -> Nil
        }
      })
      case result {
        Ok(Nil) -> io.println("successfully set simulated grade of module!")
        Error(backend.NotInitialised) ->
          io.println(
            "gpac is not initialised, run 'gpac init' to initialise gpac and try again.",
          )
        _ -> Nil
      }
    }
  }
}

fn update_units_flag() -> glint.Flag(Int) {
  let help_text =
    "Use the flag --units=<INT> to specify the number of units, 

    <number> must be an integer greater than or equal to 0.
    "
  glint.int_flag("units")
  |> glint.flag_help(help_text)
  |> glint.flag_constraint(fn(units) {
    case units < 0 {
      True -> snag.error("must be greater than 0")
      False -> Ok(units)
    }
  })
  |> glint.flag_default(-1)
}

fn update_grade_flag() -> glint.Flag(String) {
  let help_text =
    "Use the flag --grade=<STRING> to specify the grade of the module,

  Note: <STRING> can only be one of the following values:

  A+, A, A-, B+, B, B-, C+, C, D+, D, F, S, U
    "
  glint.string_flag("grade")
  |> glint.flag_help(help_text)
  |> glint.flag_constraint(
    constraint.one_of([
      "A+", "A", "A-", "B+", "B", "B-", "C+", "C", "D+", "D", "F", "S", "U",
    ]),
  )
  |> glint.flag_default("")
}

pub fn update() -> glint.Command(Nil) {
  let help_text =
    "Update any module info. Run 'gpac update --help' for more info.
  "
  use <- glint.command_help(help_text)
  use <- glint.unnamed_args(glint.EqArgs(0))
  use module_code <- glint.named_arg("code")
  use module_units <- glint.flag(update_units_flag())
  use module_grade <- glint.flag(update_grade_flag())

  use named_args, _, flags <- glint.command()
  let code = module_code(named_args)
  let assert Ok(units) = module_units(flags)
  let assert Ok(grade) = module_grade(flags)

  let updated_fields = case units, grade {
    -1, "" -> #(None, None)
    u, "" -> #(Some(backend.Units(u)), None)
    -1, g -> {
      let decoder = backend.module_grade_decoder()
      let assert Ok(mod_grade) = decode.run(dynamic.string(g), decoder)
        as "grade is not of type Grade"
      #(None, Some(backend.Grade(mod_grade)))
    }
    u, g -> {
      let decoder = backend.module_grade_decoder()
      let assert Ok(mod_grade) = decode.run(dynamic.string(g), decoder)
        as "grade is not of type Grade"
      #(Some(backend.Units(u)), Some(backend.Grade(mod_grade)))
    }
  }

  let update_result = backend.update_module(code, updated_fields)
  use <- defer(fn() {
    case update_result {
      Error(err) ->
        io.println(
          "ERROR: gpac failed to update module: "
          <> backend.error_description(err),
        )
      Ok(_) -> Nil
    }
  })
  case update_result {
    Ok(Nil) -> io.println("successfully updated module info of module!")
    Error(backend.NotInitialised) ->
      io.println(
        "gpac is not initialised, run 'gpac init' to initialise gpac and try again.",
      )
    _ -> Nil
  }
}
