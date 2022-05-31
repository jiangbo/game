use std::fmt;

use fixedbitset::FixedBitSet;

pub struct Universe {
    width: u32,
    height: u32,
    cells: FixedBitSet,
}

impl Universe {
    fn get_index(&self, row: u32, column: u32) -> usize {
        (row * self.width + column) as usize
    }

    fn live_neighbor_count(&self, row: u32, column: u32) -> u8 {
        let mut count = 0;

        for delta_row in [self.height - 1, 0, 1] {
            for delta_col in [self.width - 1, 0, 1] {
                if delta_row == 0 && delta_col == 0 {
                    continue;
                }

                let neighbor_row = (row + delta_row) % self.height;
                let neighbor_col = (column + delta_col) % self.width;
                let idx = self.get_index(neighbor_row, neighbor_col);
                count += self.cells[idx] as u8;
            }
        }
        count
    }
}

impl Universe {
    pub fn tick(&mut self) {
        let mut next = self.cells.clone();
        for row in 0..self.height {
            for col in 0..self.width {
                let idx = self.get_index(row, col);
                let cell = self.cells[idx];
                let lives = self.live_neighbor_count(row, col);

                let next_cell = match (cell, lives) {
                    (true, x) if !(2..=3).contains(&x) => false,
                    (true, 2) | (true, 3) | (false, 3) => true,
                    (otherwise, _) => otherwise,
                };
                next.set(idx, next_cell);
            }
        }
        self.cells = next;
    }

    pub fn new(width: u32, height: u32) -> Universe {
        let size = (width * height) as usize;
        let mut cells = FixedBitSet::with_capacity(size);
        (0..size).for_each(|i| cells.set(i, fastrand::bool()));
        Universe {
            width,
            height,
            cells,
        }
    }
}

impl fmt::Display for Universe {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        let capacity = (self.width + 1) * self.height;
        let mut buffer = Vec::with_capacity(capacity as usize);
        for row in 0..self.height {
            for column in 0..self.width {
                let idx = self.get_index(row, column);
                let symbol = if self.cells[idx] { b'Q' } else { b'-' };
                buffer.push(symbol);
            }
            buffer.push(b'\n');
        }
        write!(f, "{}", String::from_utf8(buffer).unwrap())?;
        Ok(())
    }
}
