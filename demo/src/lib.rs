use wasm_bindgen::prelude::*;
use web_sys::console;

type Context = web_sys::CanvasRenderingContext2d;
type Color = (u8, u8, u8);
type Point = (f64, f64);
type Triangle = [Point; 3];

// This is like the `main` function, except for JavaScript.
#[wasm_bindgen(start)]
pub fn main_js() -> Result<(), JsValue> {
    console_error_panic_hook::set_once();

    console::log_1(&JsValue::from_str("Hello world!"));

    let window = web_sys::window().unwrap();
    let document = window.document().unwrap();
    let canvas = document
        .get_element_by_id("canvas")
        .unwrap()
        .dyn_into::<web_sys::HtmlCanvasElement>()
        .unwrap();
    let context = canvas
        .get_context("2d")
        .unwrap()
        .unwrap()
        .dyn_into::<web_sys::CanvasRenderingContext2d>()
        .unwrap();
    let triangle = [(300.0, 0.0), (0.0, 600.0), (600.0, 600.0)];
    sierpinski(&context, triangle, 5, (0, 255, 0));
    Ok(())
}

fn sierpinski(context: &Context, points: Triangle, depth: u8, color: Color) {
    draw_triangle(&context, points, color);

    use rand::Rng;
    let mut rng = rand::thread_rng();
    let color = (
        rng.gen_range(0..255),
        rng.gen_range(0..255),
        rng.gen_range(0..255),
    );
    let [top, left, right] = points;
    let depth = depth - 1;
    if depth > 0 {
        let left_mid = midpoint(top, left);
        let right_mid = midpoint(top, right);
        let bottom_mid = midpoint(left, right);
        sierpinski(&context, [top, left_mid, right_mid], depth, color);
        sierpinski(&context, [left_mid, left, bottom_mid], depth, color);
        sierpinski(&context, [right_mid, bottom_mid, right], depth, color);
    };
}

fn midpoint(p1: Point, p2: Point) -> Point {
    ((p1.0 + p2.0) / 2.0, (p1.1 + p2.1) / 2.0)
}

fn draw_triangle(context: &Context, triangle: Triangle, color: Color) {
    let color_str = format!("rgb({}, {}, {})", color.0, color.1, color.2);
    context.set_fill_style(&wasm_bindgen::JsValue::from_str(&color_str));
    let [top, left, right] = triangle;
    context.move_to(top.0, top.1);
    context.begin_path();
    context.line_to(left.0, left.1);
    context.line_to(right.0, right.1);
    context.line_to(top.0, top.1);
    context.close_path();
    context.fill();
    context.stroke();
}
