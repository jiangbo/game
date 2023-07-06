use crate::{engine, game};

const LOW_PLATFORM: i16 = 420;
const HIGH_PLATFORM: i16 = 375;
const FIRST_PLATFORM: i16 = 370;

const STONE_ON_GROUND: i16 = 546;

const FLOATING_PLATFORM_SPRITES: [&str; 3] = ["13.png", "14.png", "15.png"];
const PLATFORM_WIDTH: i16 = 384;
const PLATFORM_HEIGHT: i16 = 93;
const PLATFORM_EDGE_WIDTH: i16 = 60;
const PLATFORM_EDGE_HEIGHT: i16 = 54;
const FLOATING_PLATFORM_BOUNDING_BOXES: [engine::Rect; 3] = [
    engine::Rect::new_from_xy(0, 0, PLATFORM_EDGE_WIDTH, PLATFORM_EDGE_HEIGHT),
    engine::Rect::new_from_xy(
        PLATFORM_EDGE_WIDTH,
        0,
        PLATFORM_WIDTH - (PLATFORM_EDGE_WIDTH * 2),
        PLATFORM_HEIGHT,
    ),
    engine::Rect::new_from_xy(
        PLATFORM_WIDTH - PLATFORM_EDGE_WIDTH,
        0,
        PLATFORM_EDGE_WIDTH,
        PLATFORM_EDGE_HEIGHT,
    ),
];
pub fn stone_and_platform(
    stone: web_sys::HtmlImageElement,
    sprite_sheet: std::rc::Rc<engine::SpriteSheet>,
    offset_x: i16,
) -> Vec<Box<dyn game::Obstacle>> {
    const INITIAL_STONE_OFFSET: i16 = 150;
    vec![
        Box::new(game::Barrier::new(engine::Image::new(
            stone,
            engine::Point {
                x: offset_x + INITIAL_STONE_OFFSET,
                y: STONE_ON_GROUND,
            },
        ))),
        Box::new(create_floating_platform(
            sprite_sheet,
            engine::Point {
                x: offset_x + FIRST_PLATFORM,
                y: LOW_PLATFORM,
            },
        )),
    ]
}
fn create_floating_platform(
    sprite_sheet: std::rc::Rc<engine::SpriteSheet>,
    position: engine::Point,
) -> game::Platform {
    game::Platform::new(
        sprite_sheet,
        position,
        &FLOATING_PLATFORM_SPRITES,
        &FLOATING_PLATFORM_BOUNDING_BOXES,
    )
}

pub fn platform_and_stone(
    stone: web_sys::HtmlImageElement,
    sprite_sheet: std::rc::Rc<engine::SpriteSheet>,
    offset_x: i16,
) -> Vec<Box<dyn game::Obstacle>> {
    const INITIAL_STONE_OFFSET: i16 = 400;
    const INITIAL_PLATFORM_OFFSET: i16 = 200;

    vec![
        Box::new(game::Barrier::new(engine::Image::new(
            stone,
            engine::Point {
                x: offset_x + INITIAL_STONE_OFFSET,
                y: STONE_ON_GROUND,
            },
        ))),
        Box::new(create_floating_platform(
            sprite_sheet,
            engine::Point {
                x: offset_x + INITIAL_PLATFORM_OFFSET,
                y: HIGH_PLATFORM,
            },
        )),
    ]
}
