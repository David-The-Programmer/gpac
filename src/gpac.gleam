import gpac/internal/backend

pub fn main() -> Nil {
  echo backend.initialise()
  echo backend.add_module(backend.Module("CS2030S", 4, backend.AMinus))
  echo backend.add_module(backend.Module("CS2040S", 4, backend.AMinus))
  echo backend.add_module(backend.Module("CS2100", 4, backend.B))
  echo backend.list_modules()
  Nil
}
