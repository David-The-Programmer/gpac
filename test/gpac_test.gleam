import gleam/io
import gleeunit
import gpac/internal/frontend

pub fn main() -> Nil {
  gleeunit.main()
}

// gleeunit test functions end in `_test`

pub fn split_by_size_test() {
  assert frontend.split_by_size("hello", 3) == ["hel", "lo"]
}
