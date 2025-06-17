import gleam/io
import gleam/result
import glint
import gpac/internal/backend

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
  let help_text = "Initialises gpac to be ready for use."
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
