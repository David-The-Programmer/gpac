import gpac/internal/backend

pub fn main() -> Nil {
  echo backend.initialise()
  echo backend.add_module(backend.Module("CS2030S", 4, backend.AMinus))
  echo backend.add_module(backend.Module("GEA1000", 4, backend.A))
  echo backend.add_module(backend.Module("MA1301", 4, backend.A))
  echo backend.add_module(backend.Module("CS2100", 4, backend.B))
  echo backend.add_module(backend.Module("CS1231S", 4, backend.S))
  echo backend.list_modules()
  echo backend.remove_module("CS2030S")
  echo backend.list_modules()
  echo backend.gpa()
  Nil
}
