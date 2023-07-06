use super::{RedHatBoyState, RedHatBoyStateMachine};

const RUN_FRAME_NAME: &str = "Run";
const RUNNING_FRAMES: u8 = 23;

const JUMP_SPEED: i16 = -35;
#[derive(Copy, Clone)]
pub struct Running;
impl RedHatBoyState<Running> {
    pub fn frame_name(&self) -> &str {
        RUN_FRAME_NAME
    }
    pub fn update(mut self) -> Self {
        self.update_context(RUNNING_FRAMES);
        self
    }
    pub fn slide(self) -> RedHatBoyState<super::slid::Sliding> {
        RedHatBoyState {
            context: self.context.reset_frame(),
            _state: super::slid::Sliding {},
        }
    }

    pub fn jump(self) -> RedHatBoyState<super::jump::Jumping> {
        RedHatBoyState {
            context: self.context.set_vertical_velocity(JUMP_SPEED).reset_frame(),
            _state: super::jump::Jumping {},
        }
    }
    pub fn knock_out(self) -> RedHatBoyState<super::fall::Falling> {
        RedHatBoyState {
            context: self.context,
            _state: super::fall::Falling {},
        }
    }
    pub fn land_on(self, position: i16) -> RedHatBoyState<Running> {
        RedHatBoyState {
            context: self.context.set_on(position),
            _state: Running {},
        }
    }
}

impl From<RedHatBoyState<Running>> for RedHatBoyStateMachine {
    fn from(state: RedHatBoyState<Running>) -> Self {
        RedHatBoyStateMachine::Running(state)
    }
}
