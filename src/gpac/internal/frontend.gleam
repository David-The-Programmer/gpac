import gleam/dynamic
import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import glint
import gpac/internal/backend

type FrontendError {
  InvalidArgType(message: String)
  InvalidArgValue(message: String)
  InvalidNumberArgs(message: String)
  InvalidFlagType(message: String)
  InvalidFlagValue(message: String)
  DecodeError(message: String, err: List(decode.DecodeError))
  CommandBackendError(message: String, err: backend.BackendError)
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
  let assert Ok(force_value) = force(flags)

  let #(init_called, result) = case force_value {
    True -> {
      io.println("gpac will re-initialise forcefully...")
      #(True, backend.initialise())
    }
    False ->
      case backend.is_initialised() {
        Ok(False) -> {
          io.println("initialising gpac...")
          #(True, backend.initialise())
        }
        Ok(True) -> {
          io.println(
            "gpac is already initialised, use --force to override, but proceed with caution, run 'gpac init --help to find out more.",
          )
          #(False, Ok(Nil))
        }
        err -> #(False, result.map(err, fn(_) { Nil }))
      }
  }
  case init_called, result {
    True, Ok(Nil) -> io.println("gpac successfully initialised!")
    False, Ok(Nil) -> io.println("")
    _, Error(_) -> io.println("gpac failed to initialise, exiting...")
  }
}

fn add_cmd_computation(unnamed_args: List(String)) -> Result(Nil, FrontendError) {
  let assert [code, units, grade] = unnamed_args
  use module_units <- result.try(
    int.base_parse(units, 10)
    |> result.map_error(fn(_) {
      InvalidArgType(
        "Expected '<module_units>' to be a number, 0, 1, 2, 4, etc', got '"
        <> units
        <> "' instead."
        <> "
        Run 'gpac add --help' for more info on the '<module_units>' argument",
      )
    }),
  )
  let decoder = backend.module_grade_decoder()
  use module_grade <- result.try(
    decode.run(dynamic.string(grade), decoder)
    |> result.map_error(fn(e) {
      DecodeError(
        "Expected '<module_grade>' to be of a specific value: 'A+', 'B-', 'C', etc, but got"
          <> "'"
          <> grade
          <> "' instead."
          <> "
        Run 'gpac add --help' for more info on the '<module_grade>' argument",
        e,
      )
    }),
  )
  use _ <- result.try(
    backend.add_module(backend.Module(code, module_units, module_grade))
    |> result.map_error(fn(e) {
      CommandBackendError(
        "failed to add module, gpac internal backend failed.",
        e,
      )
    }),
  )
  Ok(Nil)
}

pub fn add() -> glint.Command(Nil) {
  let help_text =
    "Add module code, module units and module grade info to gpac.


  Usage: gpac add <module_code> <module_units> <module_grade> 


  <module_grade> can only be 1 of the following values:

  A+, A, A-, B+, B, B-, C+, C, D+, D, F, S, U
  "
  use <- glint.command_help(help_text)
  use <- glint.unnamed_args(glint.EqArgs(3))
  use _, unnamed_args, _ <- glint.command()
  case add_cmd_computation(unnamed_args) {
    Ok(_) -> io.println("successfully added module!")
    Error(InvalidNumberArgs(msg)) -> io.println(msg)
    Error(InvalidArgType(msg)) -> io.println(msg)
    Error(InvalidArgValue(msg)) -> io.println(msg)
    Error(DecodeError(msg, _)) -> io.println(msg)
    Error(CommandBackendError(msg, _)) -> io.println(msg)
    _ -> io.println("failed to add module, unexpected failure.")
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
    [mod.code, int.to_string(mod.units), backend.grade_to_string(mod.grade)]
  })
  |> pretty_print_table(["Module Code", "Units", "Grade"], table_width)
}

pub fn list() -> glint.Command(Nil) {
  let help_text = "Lists all modules stored in gpac."
  use <- glint.command_help(help_text)
  use <- glint.unnamed_args(glint.EqArgs(0))
  use _, _, _ <- glint.command()

  case backend.list_modules() {
    Ok(modules) -> pretty_print_mods(modules)
    Error(_) -> io.println("failed to retrieve modules for listing.")
  }
}

pub fn remove() -> glint.Command(Nil) {
  let help_text =
    "Deletes all module info of given module code.


  Usage: gpac remove <module_code>

  "
  use <- glint.command_help(help_text)
  use <- glint.unnamed_args(glint.EqArgs(1))
  use _, unnamed_args, _ <- glint.command()
  let assert [module_code] = unnamed_args
  let remove_result =
    backend.remove_module(module_code)
    |> result.map_error(fn(e) {
      case e {
        backend.ModuleNotFound -> {
          let err_msg =
            "failed to remove module of module code: "
            <> module_code
            <> ", module not found."
          CommandBackendError(err_msg, e)
        }
        _ -> {
          let err_msg =
            "failed to remove module of module code: " <> module_code
          CommandBackendError(err_msg, e)
        }
      }
    })
  case remove_result {
    Ok(Nil) ->
      io.println(
        "successfully remove module info of module code: " <> module_code,
      )
    Error(CommandBackendError(msg, _)) -> io.println(msg)
    _ -> io.println("failed to remove module.")
  }
}

pub fn gpa() -> glint.Command(Nil) {
  let help_text = "Calculates the cumulative GPA of all modules added to gpac"
  use <- glint.command_help(help_text)
  use <- glint.unnamed_args(glint.EqArgs(0))
  use _, _, _ <- glint.command()

  case backend.gpa() {
    Ok(cumulative_gpa) ->
      io.println("Cumulative GPA: " <> float.to_string(cumulative_gpa))
    Error(_) -> io.println("failed to calculated GPA")
  }
}
