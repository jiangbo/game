use crate::engine::Point;

use super::{RedHatBoyContext, RedHatBoyState};

const STARTING_POINT: i16 = -20;
const IDLE_FRAMES: u8 = 29;

#[derive(Copy, Clone)]
pub struct Idle;
impl RedHatBoyState<Idle> {
    pub fn new() -> Self {
        RedHatBoyState {
            context: RedHatBoyContext {
                frame: 0,
                position: Point {
                    x: STARTING_POINT,
                    y: super::FLOOR,
                },
                velocity: Point { x: 0, y: 0 },
            },
            _state: Idle,
        }
    }

    pub fn frame_name(&self) -> &str {
        "Idle"
    }

    pub fn run(self) -> RedHatBoyState<super::run::Running> {
        RedHatBoyState {
            context: self.context.reset_frame().run_right(),
            _state: super::run::Running {},
        }
    }

    pub fn update(mut self) -> Self {
        self.update_context(IDLE_FRAMES);
        self
    }
}

impl From<RedHatBoyState<Idle>> for super::RedHatBoyStateMachine {
    fn from(state: RedHatBoyState<Idle>) -> Self {
        super::RedHatBoyStateMachine::Idle(state)
    }
}
