use std::rc::Rc;

use camera::Camera;
use hittable::{Hit, World};
use material::{Dielectric, Lambert, Metal};
use rand::Rng;
use ray::Ray;
use sphere::Sphere;
use vector3::{Color, Point3, Vector3};

mod camera;
mod hittable;
mod material;
mod ray;
mod sphere;
mod vector3;

fn main() {
    const RATIO: f64 = 3.0 / 2.0;
    const WIDTH: u64 = 1200;
    const HEIGHT: u64 = ((WIDTH as f64) / RATIO) as u64;
    const SAMPLES_PER_PIXEL: u64 = 500;
    const MAX_DEPTH: u64 = 50;

    let world = random_scene();

    let camera = Camera::new(
        Point3::new(13.0, 2.0, 3.0),
        Point3::new(0.0, 0.0, 0.0),
        Vector3::new(0.0, 1.0, 0.0),
        20.0,
        RATIO,
        0.1,
        10.0,
    );

    // 输出图片，第一行输出 P3，表示像素图
    let mut content = String::from("P3");
    // 输出宽和高，和最大颜色值
    content.push_str(&format!("\n{WIDTH} {HEIGHT}\n255\n"));

    let mut rng = rand::thread_rng();
    for j in (0..HEIGHT).rev() {
        // 进度
        eprintln!("Scan lines remaining: {j}");
        for i in 0..WIDTH {
            let mut color = Color::default();
            for _ in 0..SAMPLES_PER_PIXEL {
                let random_u: f64 = rng.gen();
                let random_v: f64 = rng.gen();

                let u = ((i as f64) + random_u) / ((WIDTH - 1) as f64);
                let v = ((j as f64) + random_v) / ((HEIGHT - 1) as f64);

                color += ray_color(&camera.get_ray(u, v), &world, MAX_DEPTH);
            }
            content.push_str(&color.format_str(SAMPLES_PER_PIXEL as f64));
        }
    }
    println!("{}", content);
    eprintln!("Done.");
}

// 光线的颜色计算
fn ray_color(ray: &Ray, hittable: &dyn Hit, depth: u64) -> Color {
    // 超过最大深度，直接变成黑色
    if depth == 0 {
        return Color::new(0.0, 0.0, 0.0);
    }

    // 射线命中物体
    if let Some(record) = hittable.hit(ray, 0.001, f64::INFINITY) {
        // 命中物体根据材料散射光线
        return match record.material.scatter(ray, &record) {
            Some((attenuation, scattered)) => {
                attenuation * ray_color(&scattered, hittable, depth - 1)
            }
            None => Color::new(0.0, 0.0, 0.0),
        };
    }

    // 射线未命中，射线的单位向量
    let unit = ray.direction().unit();
    // 因为需要得到上下渐变的背景图，所以需要对 y 进行插值。
    let t = 0.5 * (unit.y + 1.0);
    // 线性插值，根据不同的光线得到在下面这个范围里的不同的颜色，并且是渐变色。
    (1.0 - t) * Color::new(1.0, 1.0, 1.0) + t * Color::new(0.5, 0.7, 1.0)
}

fn random_scene() -> World {
    let mut rng = rand::thread_rng();
    let mut world = World::new();

    let ground = Rc::new(Lambert::new(Color::new(0.5, 0.5, 0.5)));
    let ground = Sphere::new(Point3::new(0.0, -1000.0, 0.0), 1000.0, ground);

    world.push(Box::new(ground));

    for a in -11..=11 {
        for b in -11..=11 {
            let choose_mat: f64 = rng.gen();
            let center = Point3::new(
                (a as f64) + rng.gen_range(0.0..0.9),
                0.2,
                (b as f64) + rng.gen_range(0.0..0.9),
            );

            if choose_mat < 0.8 {
                let albedo = Color::random(0.0..1.0) * Color::random(0.0..1.0);
                let sphere_mat = Rc::new(Lambert::new(albedo));
                let sphere = Sphere::new(center, 0.2, sphere_mat);

                world.push(Box::new(sphere));
            } else if choose_mat < 0.95 {
                let albedo = Color::random(0.4..1.0);
                let fuzz = rng.gen_range(0.0..0.5);
                let sphere_mat = Rc::new(Metal::new(albedo, fuzz));
                let sphere = Sphere::new(center, 0.2, sphere_mat);

                world.push(Box::new(sphere));
            } else {
                // Glass
                let sphere_mat = Rc::new(Dielectric::new(1.5));
                let sphere = Sphere::new(center, 0.2, sphere_mat);

                world.push(Box::new(sphere));
            }
        }
    }

    let mat1 = Rc::new(Dielectric::new(1.5));
    let mat2 = Rc::new(Lambert::new(Color::new(0.4, 0.2, 0.1)));
    let mat3 = Rc::new(Metal::new(Color::new(0.7, 0.6, 0.5), 0.0));

    let sphere1 = Sphere::new(Point3::new(0.0, 1.0, 0.0), 1.0, mat1);
    let sphere2 = Sphere::new(Point3::new(-4.0, 1.0, 0.0), 1.0, mat2);
    let sphere3 = Sphere::new(Point3::new(4.0, 1.0, 0.0), 1.0, mat3);

    world.push(Box::new(sphere1));
    world.push(Box::new(sphere2));
    world.push(Box::new(sphere3));

    world
}
