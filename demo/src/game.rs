use std::rc::Rc;

use gloo_utils::format::JsValueSerdeExt;

use crate::{
    browser,
    engine::{self, SpriteSheet},
    rhb, segments,
};

pub const HEIGHT: i16 = 600;
pub struct Walk {
    boy: rhb::RedHatBoy,
    backgrounds: [engine::Image; 2],
    obstacles: Vec<Box<dyn Obstacle>>,
    sheet: Rc<SpriteSheet>,
    stone: web_sys::HtmlImageElement,
    timeline: i16,
}
impl Walk {
    fn velocity(&self) -> i16 {
        -self.boy.walking_speed()
    }
    fn generate_next_segment(&mut self) {
        let mut rng = rand::thread_rng();
        let next_segment = rand::Rng::gen_range(&mut rng, 0..2);
        let mut next_obstacles = match next_segment {
            0 => segments::stone_and_platform(
                self.stone.clone(),
                self.sheet.clone(),
                self.timeline + OBSTACLE_BUFFER,
            ),
            1 => segments::platform_and_stone(
                self.stone.clone(),
                self.sheet.clone(),
                self.timeline + OBSTACLE_BUFFER,
            ),
            _ => vec![],
        };
        self.timeline = rightmost(&next_obstacles);
        self.obstacles.append(&mut next_obstacles);
    }
}
pub struct Platform {
    sheet: Rc<engine::SpriteSheet>,
    bounding_boxes: Vec<engine::Rect>,
    sprites: Vec<engine::Cell>,
    position: engine::Point,
}
impl Platform {
    pub fn new(
        sheet: Rc<engine::SpriteSheet>,
        position: engine::Point,
        sprite_names: &[&str],
        bounding_boxes: &[engine::Rect],
    ) -> Self {
        let sprites = sprite_names
            .iter()
            .filter_map(|sprite_name| sheet.cell(sprite_name).cloned())
            .collect();
        let bounding_boxes = bounding_boxes
            .iter()
            .map(|bounding_box| {
                engine::Rect::new_from_xy(
                    bounding_box.x() + position.x,
                    bounding_box.y() + position.y,
                    bounding_box.width,
                    bounding_box.height,
                )
            })
            .collect();
        Platform {
            sheet,
            position,
            sprites,
            bounding_boxes,
        }
    }
    fn bounding_boxes(&self) -> &Vec<engine::Rect> {
        &self.bounding_boxes
    }
}
impl Obstacle for Platform {
    fn move_horizontally(&mut self, x: i16) {
        self.position.x += x;
        self.bounding_boxes.iter_mut().for_each(|bounding_box| {
            bounding_box.set_x(bounding_box.position.x + x);
        });
    }

    fn check_intersection(&self, boy: &mut rhb::RedHatBoy) {
        if let Some(box_to_land_on) = self
            .bounding_boxes()
            .iter()
            .find(|&bounding_box| boy.bounding_box().intersects(bounding_box))
        {
            if boy.velocity_y() > 0 && boy.pos_y() < self.position.y {
                boy.land_on(box_to_land_on.y());
            } else {
                boy.knock_out();
            }
        }
    }

    fn draw(&self, renderer: &engine::Renderer) {
        let mut x = 0;
        self.sprites.iter().for_each(|sprite| {
            self.sheet.draw(
                renderer,
                &engine::Rect::new_from_xy(
                    sprite.frame.x,
                    sprite.frame.y,
                    sprite.frame.w,
                    sprite.frame.h,
                ),
                // Just use position and the standard widths in the tileset
                &engine::Rect::new_from_xy(
                    self.position.x + x,
                    self.position.y,
                    sprite.frame.w,
                    sprite.frame.h,
                ),
            );
            x += sprite.frame.w;
        });
    }

    fn right(&self) -> i16 {
        self.bounding_boxes()
            .last()
            .unwrap_or(&engine::Rect::default())
            .right()
    }
}
pub enum WalkTheDog {
    Loading,
    Loaded(Walk),
}
impl WalkTheDog {
    pub fn new() -> Self {
        WalkTheDog::Loading
    }
}
const TIMELINE_MINIMUM: i16 = 1000;
const OBSTACLE_BUFFER: i16 = 20;
#[async_trait::async_trait(?Send)]
impl engine::Game for WalkTheDog {
    async fn initialize(&mut self) -> anyhow::Result<()> {
        match self {
            WalkTheDog::Loading => {
                let stone = engine::load_image("Stone.png").await?;

                let tiles = browser::fetch_json("tiles.json").await?;
                let sprite_sheet = Rc::new(engine::SpriteSheet::new(
                    tiles.into_serde::<engine::Sheet>()?,
                    engine::load_image("tiles.png").await?,
                ));

                let background = engine::load_image("BG.png").await?;
                let point = engine::Point {
                    x: background.width() as i16,
                    y: 0,
                };
                let backgrounds = [
                    engine::Image::new(background.clone(), engine::Point::default()),
                    engine::Image::new(background, point),
                ];

                let timeline = rightmost(&segments::stone_and_platform(
                    stone.clone(),
                    sprite_sheet.clone(),
                    0,
                ));
                let walk = Walk {
                    boy: rhb::RedHatBoy::new().await?,
                    backgrounds,
                    obstacles: segments::stone_and_platform(stone.clone(), sprite_sheet.clone(), 0),
                    sheet: sprite_sheet,
                    stone,
                    timeline,
                };
                *self = WalkTheDog::Loaded(walk);
                Ok(())
            }
            WalkTheDog::Loaded(_) => Err(anyhow::anyhow!("Error: Game is initialized!")),
        }
    }

    fn update(&mut self, keystate: &engine::KeyState) {
        if let WalkTheDog::Loaded(walk) = self {
            if keystate.is_pressed("ArrowRight") {
                walk.boy.run_right();
            }
            if keystate.is_pressed("ArrowDown") {
                walk.boy.slide();
            }
            if keystate.is_pressed("Space") {
                walk.boy.jump();
            }

            walk.boy.update();
            let velocity = walk.velocity();
            let [first_background, second_background] = &mut walk.backgrounds;
            first_background.move_horizontally(velocity);
            second_background.move_horizontally(velocity);
            if first_background.right() < 0 {
                first_background.set_x(second_background.right());
            }
            if second_background.right() < 0 {
                second_background.set_x(first_background.right());
            }
            walk.obstacles.retain(|obstacle| obstacle.right() > 0);
            walk.obstacles.iter_mut().for_each(|obstacle| {
                obstacle.move_horizontally(velocity);
                obstacle.check_intersection(&mut walk.boy);
            });
            if walk.timeline < TIMELINE_MINIMUM {
                walk.generate_next_segment()
            } else {
                walk.timeline += velocity;
            }
        }
    }
    fn draw(&self, renderer: &engine::Renderer) {
        renderer.clear(&engine::Rect {
            position: engine::Point::default(),
            width: 600,
            height: HEIGHT,
        });
        if let WalkTheDog::Loaded(walk) = self {
            walk.backgrounds.iter().for_each(|background| {
                background.draw(renderer);
            });
            walk.boy.draw(renderer);
            walk.obstacles.iter().for_each(|obstacle| {
                obstacle.draw(renderer);
            });
        }
    }
}
pub trait Obstacle {
    fn check_intersection(&self, boy: &mut rhb::RedHatBoy);
    fn draw(&self, renderer: &engine::Renderer);
    fn move_horizontally(&mut self, x: i16);
    fn right(&self) -> i16;
}
pub struct Barrier {
    image: engine::Image,
}
impl Barrier {
    pub fn new(image: engine::Image) -> Self {
        Barrier { image }
    }
}
impl Obstacle for Barrier {
    fn check_intersection(&self, boy: &mut rhb::RedHatBoy) {
        if boy.bounding_box().intersects(self.image.bounding_box()) {
            boy.knock_out()
        }
    }

    fn draw(&self, renderer: &engine::Renderer) {
        self.image.draw(renderer);
    }

    fn move_horizontally(&mut self, x: i16) {
        self.image.move_horizontally(x);
    }

    fn right(&self) -> i16 {
        self.image.right()
    }
}
fn rightmost(obstacle_list: &Vec<Box<dyn Obstacle>>) -> i16 {
    obstacle_list
        .iter()
        .map(|obstacle| obstacle.right())
        .max_by(|x, y| x.cmp(&y))
        .unwrap_or(0)
}
