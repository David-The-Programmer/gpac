import gpac/internal/backend

pub fn main() -> Nil {
  echo backend.initialise()
  echo backend.add_module(backend.Module("CS2030S", 4, backend.APlus))
  Nil
}
