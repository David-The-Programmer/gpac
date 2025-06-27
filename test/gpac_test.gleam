import birdie
import gleam/io
import gleam/option.{Some}
import gleeunit
import gpac/internal/format

pub fn main() -> Nil {
  gleeunit.main()
}

// gleeunit test functions end in `_test`

pub fn split_by_size_test() {
  assert format.split_by_size("hello", 3) == ["hel", "lo"]
  assert format.split_by_size("hello", 5) == ["hello"]
}

pub fn table_to_string_row_value_length_equal_column_width_test() {
  format.Table(
    columns: [
      format.Column("col 1", format.Absolute(5)),
      format.Column("col 2", format.Absolute(5)),
    ],
    rows: [["hello", "world"], ["night", "sunny"]],
    total_width: Some(13),
    gap_width: Some(1),
  )
  |> format.table_to_string()
  |> birdie.snap("table to string test: row value length equal column width")
}

pub fn table_to_string_row_value_length_less_than_column_width_test() {
  format.Table(
    columns: [
      format.Column("col 1", format.Absolute(8)),
      format.Column("col 2", format.Absolute(8)),
    ],
    rows: [["hello", "world"], ["night", "sunny"]],
    total_width: Some(19),
    gap_width: Some(1),
  )
  |> format.table_to_string()
  |> birdie.snap(
    "table to string test: row value length less than column width (padding)",
  )
}

pub fn table_to_string_row_value_length_more_than_column_width_test() {
  format.Table(
    columns: [
      format.Column("col 1", format.Absolute(3)),
      format.Column("col 2", format.Absolute(3)),
    ],
    rows: [["hello", "world"], ["night", "sunny"]],
    total_width: Some(9),
    gap_width: Some(1),
  )
  |> format.table_to_string()
  |> birdie.snap(
    "table to string test: row value length more than column width (text wrapping)",
  )
}

pub fn table_to_string_fractional_units_test() {
  format.Table(
    columns: [
      format.Column("col 1", format.FractionalUnit(1)),
      format.Column("col 2", format.FractionalUnit(3)),
    ],
    rows: [["hello", "world"], ["night", "sunny"]],
    total_width: Some(23),
    gap_width: Some(1),
  )
  |> format.table_to_string()
  |> birdie.snap("table to string test: fractional units")
}

pub fn table_to_string_rightmost_column_expands_to_fit_table_width_if_sole_fractional_column_test() {
  format.Table(
    columns: [
      format.Column("col 1", format.Absolute(5)),
      format.Column("col 2", format.FractionalUnit(1)),
    ],
    rows: [["hello", "world"], ["night", "sunny"]],
    total_width: Some(20),
    gap_width: Some(1),
  )
  |> format.table_to_string()
  |> birdie.snap(
    "table to string test: rightmost column expands to fit table width if sole fractional column ",
  )
}

pub fn table_to_string_rightmost_column_does_not_expand_if_absolute_test() {
  format.Table(
    columns: [
      format.Column("col 1", format.Absolute(5)),
      format.Column("col 1", format.Absolute(5)),
    ],
    rows: [["hello", "world"], ["night", "sunny"]],
    total_width: Some(20),
    gap_width: Some(1),
  )
  |> format.table_to_string()
  |> birdie.snap(
    "table to string test: rightmost column does not expand if absolute",
  )
}

pub fn table_to_string_fractional_columns_expand_to_fit_table_width_if_cannot_fit_exactly_test() {
  io.println("")
  format.Table(
    columns: [
      format.Column("col 1", format.FractionalUnit(1)),
      format.Column("col 2", format.FractionalUnit(1)),
      format.Column("col 3", format.FractionalUnit(1)),
    ],
    rows: [["hello", "world", "lol"], ["night", "sunny", "bye"]],
    total_width: Some(12),
    gap_width: Some(1),
  )
  |> format.table_to_string()
  |> birdie.snap(
    "table to string test: fractional columns expand to fit table width if cannot fit exactly",
  )
}
