use crate::game::HEIGHT;

use super::{RedHatBoyState, RedHatBoyStateMachine};
const JUMPING_FRAME_NAME: &str = "Jump";
const JUMPING_FRAMES: u8 = 35;
#[derive(Copy, Clone)]
pub struct Jumping;
impl RedHatBoyState<Jumping> {
    pub fn frame_name(&self) -> &str {
        JUMPING_FRAME_NAME
    }
    pub fn update(mut self) -> JumpingEndState {
        self.update_context(JUMPING_FRAMES);

        if self.context.position.y >= super::FLOOR {
            JumpingEndState::Landing(self.land_on(HEIGHT.into()))
        } else {
            JumpingEndState::Jumping(self)
        }
    }
    pub fn knock_out(self) -> RedHatBoyState<super::fall::Falling> {
        RedHatBoyState {
            context: self.context.reset_frame().stop(),
            _state: super::fall::Falling {},
        }
    }
    pub fn land_on(self, position: i16) -> RedHatBoyState<super::run::Running> {
        RedHatBoyState {
            context: self.context.reset_frame().set_on(position),
            _state: super::run::Running,
        }
    }
}

pub enum JumpingEndState {
    Landing(RedHatBoyState<super::run::Running>),
    Jumping(RedHatBoyState<Jumping>),
}
impl From<RedHatBoyState<Jumping>> for RedHatBoyStateMachine {
    fn from(state: RedHatBoyState<Jumping>) -> Self {
        RedHatBoyStateMachine::Jumping(state)
    }
}
impl From<JumpingEndState> for RedHatBoyStateMachine {
    fn from(state: JumpingEndState) -> Self {
        match state {
            JumpingEndState::Jumping(jumping) => jumping.into(),
            JumpingEndState::Landing(landing) => landing.into(),
        }
    }
}
