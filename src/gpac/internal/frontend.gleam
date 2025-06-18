import gleam/dynamic
import gleam/dynamic/decode
import gleam/int
import gleam/io
import gleam/list
import gleam/result
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
  let validate_num_args = case unnamed_args {
    [_, _, _] -> Ok(unnamed_args)
    _ ->
      Error(InvalidNumberArgs(
        "Expected 3 arguments, got"
        <> list.length(unnamed_args) |> int.to_string
        <> " arguments instead. 
        Run 'gpac add --help' for more info on the arguments.",
      ))
  }
  use args <- result.try(validate_num_args)
  let assert [code, units, grade] = args
  use module_units <- result.try(
    int.base_parse(units, 10)
    |> result.map_error(fn(_) {
      InvalidArgType(
        "Expected '<module_units>' to be a number, 0, 1, 2, 4, etc', got '"
        <> units
        <> "' instead." <>
        "
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
        <> "' instead." <>
        "
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
