use crate::{browser, engine};

mod state;
pub struct RedHatBoy {
    state: state::RedHatBoyStateMachine,
    sheet: engine::Sheet,
    image: web_sys::HtmlImageElement,
}

impl RedHatBoy {
    pub async fn new() -> anyhow::Result<Self> {
        let json = browser::fetch_json("rhb.json").await?;
        use gloo_utils::format::JsValueSerdeExt;

        Ok(RedHatBoy {
            state: state::RedHatBoyStateMachine::default(),
            sheet: json.into_serde::<engine::Sheet>()?,
            image: engine::load_image("rhb.png").await?,
        })
    }

    pub fn draw(&self, renderer: &engine::Renderer) {
        let sprite = self.current_sprite().expect("Cell not found");
        renderer.draw_image(
            &self.image,
            &engine::Rect::new_from_xy(
                sprite.frame.x,
                sprite.frame.y,
                sprite.frame.w,
                sprite.frame.h,
            ),
            &self.destination_box(),
        );
        renderer.draw_rect(&self.destination_box());
    }
    fn frame_name(&self) -> String {
        format!(
            "{} ({}).png",
            self.state.frame_name(),
            (self.state.context().frame / 3) + 1
        )
    }
    fn current_sprite(&self) -> Option<&engine::Cell> {
        self.sheet.frames.get(&self.frame_name())
    }
    pub fn destination_box(&self) -> engine::Rect {
        let sprite = self.current_sprite().expect("Cell not found");
        engine::Rect::new_from_xy(
            self.state.context().position.x + sprite.sprite_source_size.x,
            self.state.context().position.y + sprite.sprite_source_size.y,
            sprite.frame.w,
            sprite.frame.h,
        )
    }
    pub fn bounding_box(&self) -> engine::Rect {
        const X_OFFSET: i16 = 18;
        const Y_OFFSET: i16 = 14;
        const WIDTH_OFFSET: i16 = 28;
        engine::Rect::new_from_xy(
            self.destination_box().x() + X_OFFSET,
            self.destination_box().y() + Y_OFFSET,
            self.destination_box().width - WIDTH_OFFSET,
            self.destination_box().height - Y_OFFSET,
        )
    }
    pub fn walking_speed(&self) -> i16 {
        self.state.context().velocity.x
    }
    pub fn pos_y(&self) -> i16 {
        self.state.context().position.y
    }
    pub fn velocity_y(&self) -> i16 {
        self.state.context().velocity.y
    }
    pub fn update(&mut self) {
        self.transition(state::Event::Update);
    }
    pub fn run_right(&mut self) {
        self.transition(state::Event::Run);
    }
    pub fn slide(&mut self) {
        self.transition(state::Event::Slide);
    }
    pub fn jump(&mut self) {
        self.transition(state::Event::Jump);
    }

    pub fn land_on(&mut self, position: i16) {
        self.transition(state::Event::Land(position));
    }

    pub fn knock_out(&mut self) {
        self.transition(state::Event::KnockOut);
    }
    fn transition(&mut self, event: state::Event) {
        self.state = self.state.transition(event);
    }
}
