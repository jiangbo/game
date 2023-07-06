#[macro_use]
mod browser;
mod engine;
mod game;
mod rhb;
mod segments;

#[wasm_bindgen::prelude::wasm_bindgen(start)]
pub fn main_js() -> anyhow::Result<(), wasm_bindgen::JsValue> {
    console_error_panic_hook::set_once();
    log!("hello world");

    browser::spawn_local(async {
        let game = game::WalkTheDog::new();
        engine::GameLoop::start(game)
            .await
            .expect("Could not start game loop");
    });
    Ok(())
}
