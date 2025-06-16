import glint
import gleam/io

pub fn gpac() -> glint.Command(Nil) {
  let help_text = "CLI tool to calculate GPA and simulate S/U options."
  use <- glint.command_help(help_text)
  use _, _, _<- glint.command()
  io.println("Try 'gpac --help' for more information.")
}

// pub fn init() -> glint.Command(Nil) {
//   
// }
