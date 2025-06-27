import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string

const default_table_width = 80

const default_gap_width = 1

pub type Width {
  Absolute(Int)
  FractionalUnit(Int)
}

pub type Column {
  Column(data: String, width: Width)
}

pub type Table {
  Table(
    columns: List(Column),
    rows: List(List(String)),
    total_width: Option(Int),
    gap_width: Option(Int),
  )
}

fn calculate_widths(
  col_widths: List(Width),
  gap_width: Int,
  width_limit: Int,
) -> List(Int) {
  let #(abs_value_sum, fr_unit_sum) =
    col_widths
    |> list.fold(#(0, 0), fn(acc, col_width) {
      let #(abs_value_sum, fr_unit_sum) = acc
      case col_width {
        Absolute(value) -> #(abs_value_sum + value, fr_unit_sum)
        FractionalUnit(unit) -> #(abs_value_sum, fr_unit_sum + unit)
      }
    })
  let num_gaps = list.length(col_widths) + 1
  let gap_width_sum = num_gaps * gap_width

  let assertion_msg =
    "sum of Absolute(Int) in col_widths exceeded width_limit - gap_width_sum\n"
    <> "expected sum of Absolute(Int) in col_widths to be <= "
    <> int.to_string(width_limit)
    <> " - "
    <> int.to_string(gap_width_sum)
    <> "\n"
  let assert True = abs_value_sum <= width_limit - gap_width_sum
    as assertion_msg
  let fr_unit_abs_value =
    { width_limit - gap_width_sum - abs_value_sum } / fr_unit_sum

  let leftover_width =
    { width_limit - gap_width_sum - abs_value_sum } % fr_unit_sum

  let #(width_values, _) =
    col_widths
    |> list.fold(#([], leftover_width), fn(acc, width) {
      let #(width_values, leftover) = acc
      case width {
        Absolute(value) -> #([value, ..width_values], leftover)
        FractionalUnit(unit) -> {
          let abs_width = unit * fr_unit_abs_value
          case leftover > 0 {
            True -> #([abs_width + 1, ..width_values], leftover - 1)
            False -> #([abs_width, ..width_values], leftover)
          }
        }
      }
    })
  width_values
  |> list.reverse
}

fn split_by_size_inner(
  str: String,
  size: Int,
  acc: List(String),
) -> List(String) {
  case str {
    "" -> list.reverse(acc)
    _ -> {
      let str_len = string.length(str)
      let head = string.slice(str, 0, size)
      let rest = string.slice(str, size, str_len - size)
      split_by_size_inner(rest, size, [head, ..acc])
    }
  }
}

pub fn split_by_size(str: String, size: Int) -> List(String) {
  split_by_size_inner(str, size, [])
}

fn pad_list_end(list: List(a), desired_length: Int, with_value: a) {
  let assert True = desired_length > 0 as "desired_length cannot be negative"
  list
  |> list.append(list.repeat(with_value, desired_length - list.length(list)))
}

fn fill_nested_list_to_matrix(
  nested_list: List(List(a)),
  with_value: a,
) -> List(List(a)) {
  let max_row_len =
    nested_list
    |> list.map(fn(row) { list.length(row) })
    |> list.max(int.compare)
    |> result.unwrap(0)

  nested_list
  |> list.map(fn(row) { pad_list_end(row, max_row_len, with_value) })
}

fn text_wrap_row(row: List(String), col_widths: List(Int)) -> List(List(String)) {
  row
  |> list.zip(col_widths)
  |> list.map(fn(pair) {
    let #(text, col_width) = pair
    split_by_size(text, col_width)
  })
  |> fill_nested_list_to_matrix("")
  |> list.transpose
}

fn text_wrap_rows(
  rows: List(List(String)),
  col_widths: List(Int),
) -> List(List(String)) {
  rows
  |> list.flat_map(fn(row) { text_wrap_row(row, col_widths) })
}

fn pad_rows_values(
  rows: List(List(String)),
  col_widths: List(Int),
  with_value: String,
) -> List(List(String)) {
  rows
  |> list.map(fn(row) {
    row
    |> list.zip(col_widths)
    |> list.map(fn(pair) {
      let #(value, col_width) = pair
      string.pad_end(value, col_width, with_value)
    })
  })
}

pub fn table_to_string(table: Table) -> String {
  let num_cols = list.length(table.columns)
  table.rows
  |> list.each(fn(row) {
    let assert True = num_cols == list.length(row)
      as "number of values in each row has to be equal to the number of columns given"
  })

  let table_width = case table.total_width {
    Some(value) -> value
    None -> default_table_width
  }
  let gap_width = case table.gap_width {
    Some(value) -> value
    None -> default_gap_width
  }
  let col_widths =
    calculate_widths(
      table.columns
        |> list.map(fn(col) { col.width }),
      gap_width,
      table_width,
    )

  let col_headers_str =
    table.columns
    |> list.map(fn(col) { col.data })
    |> text_wrap_row(col_widths)
    |> pad_rows_values(col_widths, " ")
    |> list.map(fn(row) { "|" <> string.join(row, "|") <> "|" })
    |> list.prepend("+" <> string.repeat("-", table_width - 2) <> "+")
    |> string.join("\n")

  let rows_str =
    table.rows
    |> text_wrap_rows(col_widths)
    |> pad_rows_values(col_widths, " ")
    |> list.map(fn(row) { "|" <> string.join(row, "|") <> "|" })
    |> list.prepend(string.repeat("-", table_width))
    |> list.append(["+" <> string.repeat("-", table_width - 2) <> "+"])
    |> string.join("\n")

  col_headers_str <> "\n" <> rows_str
}
