use super::{RedHatBoyState, RedHatBoyStateMachine};

const FALLING_FRAMES: u8 = 29;
#[derive(Copy, Clone)]
pub struct Falling;
impl RedHatBoyState<Falling> {
    pub fn frame_name(&self) -> &str {
        "Dead"
    }

    pub fn knock_out(self) -> RedHatBoyState<super::over::KnockedOut> {
        RedHatBoyState {
            context: self.context,
            _state: super::over::KnockedOut {},
        }
    }

    pub fn update(mut self) -> FallingEndState {
        self.update_context(FALLING_FRAMES);
        if self.context.frame >= FALLING_FRAMES {
            FallingEndState::KnockedOut(self.knock_out())
        } else {
            FallingEndState::Falling(self)
        }
    }
}
pub enum FallingEndState {
    KnockedOut(RedHatBoyState<super::over::KnockedOut>),
    Falling(RedHatBoyState<Falling>),
}
impl From<FallingEndState> for RedHatBoyStateMachine {
    fn from(state: FallingEndState) -> Self {
        match state {
            FallingEndState::Falling(falling) => falling.into(),
            FallingEndState::KnockedOut(knocked_out) => knocked_out.into(),
        }
    }
}
impl From<RedHatBoyState<Falling>> for RedHatBoyStateMachine {
    fn from(state: RedHatBoyState<Falling>) -> Self {
        RedHatBoyStateMachine::Falling(state)
    }
}
