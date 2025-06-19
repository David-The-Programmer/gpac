import argv
import glint
import gpac/internal/frontend

pub fn main() -> Nil {
  glint.new()
  |> glint.with_name("gpac")
  |> glint.pretty_help(glint.default_pretty_help())
  |> glint.add(at: [], do: frontend.gpac())
  |> glint.add(at: ["init"], do: frontend.init())
  |> glint.add(at: ["add"], do: frontend.add())
  |> glint.add(at: ["list"], do: frontend.list())
  |> glint.add(at: ["remove"], do: frontend.remove())
  |> glint.run(argv.load().arguments)
  Nil
}
