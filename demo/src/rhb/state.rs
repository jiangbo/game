use crate::engine::Point;

mod fall;
mod idle;
mod jump;
mod over;
mod run;
mod slid;
const RUNNING_SPEED: i16 = 5;
const GRAVITY: i16 = 1;
pub const FLOOR: i16 = 479;
const PLAYER_HEIGHT: i16 = crate::game::HEIGHT - FLOOR;
const TERMINAL_VELOCITY: i16 = 20;
pub enum Event {
    Run,
    Slide,
    Update,
    Jump,
    KnockOut,
    Land(i16),
}
#[derive(Copy, Clone)]
pub enum RedHatBoyStateMachine {
    Idle(RedHatBoyState<idle::Idle>),
    Running(RedHatBoyState<run::Running>),
    Sliding(RedHatBoyState<slid::Sliding>),
    Jumping(RedHatBoyState<jump::Jumping>),
    Falling(RedHatBoyState<fall::Falling>),
    KnockedOut(RedHatBoyState<over::KnockedOut>),
}

impl Default for RedHatBoyStateMachine {
    fn default() -> Self {
        RedHatBoyStateMachine::Idle(RedHatBoyState::new())
    }
}
impl RedHatBoyStateMachine {
    pub fn transition(self, event: Event) -> Self {
        match (self, event) {
            (RedHatBoyStateMachine::Idle(state), Event::Run) => state.run().into(),
            (RedHatBoyStateMachine::Running(state), Event::Jump) => state.jump().into(),
            (RedHatBoyStateMachine::Running(state), Event::Slide) => state.slide().into(),
            (RedHatBoyStateMachine::Running(state), Event::KnockOut) => state.knock_out().into(),
            (RedHatBoyStateMachine::Running(state), Event::Land(position)) => {
                state.land_on(position).into()
            }
            (RedHatBoyStateMachine::Jumping(state), Event::Land(position)) => {
                state.land_on(position).into()
            }
            (RedHatBoyStateMachine::Jumping(state), Event::KnockOut) => state.knock_out().into(),
            (RedHatBoyStateMachine::Sliding(state), Event::KnockOut) => state.knock_out().into(),
            (RedHatBoyStateMachine::Sliding(state), Event::Land(position)) => {
                state.land_on(position).into()
            }
            (RedHatBoyStateMachine::Idle(state), Event::Update) => state.update().into(),
            (RedHatBoyStateMachine::Running(state), Event::Update) => state.update().into(),
            (RedHatBoyStateMachine::Jumping(state), Event::Update) => state.update().into(),
            (RedHatBoyStateMachine::Sliding(state), Event::Update) => state.update().into(),
            (RedHatBoyStateMachine::Falling(state), Event::Update) => state.update().into(),
            _ => self,
        }
    }
    pub fn frame_name(&self) -> &str {
        match self {
            RedHatBoyStateMachine::Idle(state) => state.frame_name(),
            RedHatBoyStateMachine::Running(state) => state.frame_name(),
            RedHatBoyStateMachine::Sliding(state) => state.frame_name(),
            RedHatBoyStateMachine::Jumping(state) => state.frame_name(),
            RedHatBoyStateMachine::Falling(state) => state.frame_name(),
            RedHatBoyStateMachine::KnockedOut(state) => state.frame_name(),
        }
    }
    pub fn context(&self) -> &RedHatBoyContext {
        match self {
            RedHatBoyStateMachine::Idle(state) => state.context(),
            RedHatBoyStateMachine::Running(state) => state.context(),
            RedHatBoyStateMachine::Sliding(state) => state.context(),
            RedHatBoyStateMachine::Jumping(state) => state.context(),
            RedHatBoyStateMachine::Falling(state) => state.context(),
            RedHatBoyStateMachine::KnockedOut(state) => state.context(),
        }
    }
}

#[derive(Copy, Clone)]
pub struct RedHatBoyState<S> {
    pub context: RedHatBoyContext,
    pub _state: S,
}
impl<S> RedHatBoyState<S> {
    pub fn context(&self) -> &RedHatBoyContext {
        &self.context
    }
    pub fn update_context(&mut self, frames: u8) {
        self.context = self.context.update(frames);
    }
}
#[derive(Copy, Clone)]
pub struct RedHatBoyContext {
    pub frame: u8,
    pub position: Point,
    pub velocity: Point,
}
impl RedHatBoyContext {
    pub fn update(mut self, frame_count: u8) -> Self {
        if self.velocity.y < TERMINAL_VELOCITY {
            self.velocity.y += GRAVITY;
        }
        self.velocity.y += GRAVITY;

        if self.frame < frame_count {
            self.frame += 1;
        } else {
            self.frame = 0;
        }

        // self.position.x += self.velocity.x;
        self.position.y += self.velocity.y;

        if self.position.y > FLOOR {
            self.position.y = FLOOR;
        }

        self
    }
    fn set_on(mut self, position: i16) -> Self {
        let position = position - PLAYER_HEIGHT;
        self.position.y = position;
        self
    }
    pub fn reset_frame(mut self) -> Self {
        self.frame = 0;
        self
    }
    pub fn run_right(mut self) -> Self {
        self.velocity.x += RUNNING_SPEED;
        self
    }
    pub fn set_vertical_velocity(mut self, y: i16) -> Self {
        self.velocity.y = y;
        self
    }
    pub fn stop(mut self) -> Self {
        self.velocity.x = 0;
        self
    }
}
