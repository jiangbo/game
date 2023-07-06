use super::{RedHatBoyState, RedHatBoyStateMachine};

const FALLING_FRAME_NAME: &str = "Dead";
#[derive(Copy, Clone)]
pub struct KnockedOut;

impl RedHatBoyState<KnockedOut> {
    pub fn frame_name(&self) -> &str {
        FALLING_FRAME_NAME
    }
}

impl From<RedHatBoyState<KnockedOut>> for RedHatBoyStateMachine {
    fn from(state: RedHatBoyState<KnockedOut>) -> Self {
        RedHatBoyStateMachine::KnockedOut(state)
    }
}
