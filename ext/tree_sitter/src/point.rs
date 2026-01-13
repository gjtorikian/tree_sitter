use magnus::{RArray, Ruby};

#[magnus::wrap(class = "TreeSitter::Point")]
#[derive(Clone)]
pub struct Point {
    row: usize,
    column: usize,
}

impl Point {
    pub fn new(row: usize, column: usize) -> Self {
        Self { row, column }
    }

    pub fn from_ts(point: tree_sitter::Point) -> Self {
        Self {
            row: point.row,
            column: point.column,
        }
    }

    pub fn row(&self) -> usize {
        self.row
    }

    pub fn column(&self) -> usize {
        self.column
    }

    pub fn to_a(&self) -> RArray {
        let ruby = Ruby::get().unwrap();
        let array = ruby.ary_new();
        let _ = array.push(self.row);
        let _ = array.push(self.column);
        array
    }

    pub fn inspect(&self) -> String {
        format!("#<TreeSitter::Point row={} column={}>", self.row, self.column)
    }

    pub fn eq(&self, other: &Point) -> bool {
        self.row == other.row && self.column == other.column
    }
}
