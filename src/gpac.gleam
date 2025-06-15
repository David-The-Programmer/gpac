import gpac/internal/backend

pub fn main() -> Nil {
  echo backend.initialise()
  echo backend.add_module("CS2030S", 4, backend.APlus)
  Nil
}
