use super::{RedHatBoyState, RedHatBoyStateMachine};

const RUNNING_SPEED: i16 = 3;
const SLIDING_FRAMES: u8 = 14;
pub enum SlidingEndState {
    Running(RedHatBoyState<super::run::Running>),
    Sliding(RedHatBoyState<Sliding>),
}
#[derive(Copy, Clone)]
pub struct Sliding;
impl RedHatBoyState<Sliding> {
    pub fn frame_name(&self) -> &str {
        "Slide"
    }
    pub fn update(mut self) -> SlidingEndState {
        self.update_context(SLIDING_FRAMES);
        if self.context.frame >= SLIDING_FRAMES {
            SlidingEndState::Running(self.stand())
        } else {
            SlidingEndState::Sliding(self)
        }
    }
    pub fn stand(self) -> RedHatBoyState<super::run::Running> {
        RedHatBoyState {
            context: self.context.reset_frame(),
            _state: super::run::Running,
        }
    }
    pub fn land_on(self, position: i16) -> RedHatBoyState<Sliding> {
        RedHatBoyState {
            context: self.context.set_on(position),
            _state: Sliding {},
        }
    }
    pub fn knock_out(self) -> RedHatBoyState<super::fall::Falling> {
        RedHatBoyState {
            context: self.context.reset_frame().stop(),
            _state: super::fall::Falling {},
        }
    }
}

impl From<RedHatBoyState<Sliding>> for RedHatBoyStateMachine {
    fn from(state: RedHatBoyState<Sliding>) -> Self {
        RedHatBoyStateMachine::Sliding(state)
    }
}
impl From<SlidingEndState> for RedHatBoyStateMachine {
    fn from(end_state: SlidingEndState) -> Self {
        match end_state {
            SlidingEndState::Running(running_state) => running_state.into(),
            SlidingEndState::Sliding(sliding_state) => sliding_state.into(),
        }
    }
}
