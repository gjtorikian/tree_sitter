use crate::point::Point;

#[magnus::wrap(class = "TreeSitter::Range")]
#[derive(Clone)]
pub struct Range {
    start_byte: usize,
    end_byte: usize,
    start_point: Point,
    end_point: Point,
}

impl Range {
    pub fn new(start_byte: usize, end_byte: usize, start_point: Point, end_point: Point) -> Self {
        Self {
            start_byte,
            end_byte,
            start_point,
            end_point,
        }
    }

    pub fn start_byte(&self) -> usize {
        self.start_byte
    }

    pub fn end_byte(&self) -> usize {
        self.end_byte
    }

    pub fn start_point(&self) -> Point {
        self.start_point.clone()
    }

    pub fn end_point(&self) -> Point {
        self.end_point.clone()
    }

    pub fn size(&self) -> usize {
        self.end_byte - self.start_byte
    }

    pub fn inspect(&self) -> String {
        format!(
            "#<TreeSitter::Range start_byte={} end_byte={} size={}>",
            self.start_byte,
            self.end_byte,
            self.size()
        )
    }
}
