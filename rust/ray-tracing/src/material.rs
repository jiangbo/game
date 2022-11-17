use rand::Rng;

use crate::hittable::HitRecord;
use crate::ray::Ray;
use crate::vector3::{Color, Vector3};

// 材质
pub trait Material {
    fn scatter(&self, ray: &Ray, record: &HitRecord) -> Option<(Color, Ray)>;
}

pub struct Lambert {
    albedo: Color,
}

impl Lambert {
    pub fn new(albedo: Color) -> Self {
        Lambert { albedo }
    }
}

impl Material for Lambert {
    fn scatter(&self, _: &Ray, record: &HitRecord) -> Option<(Color, Ray)> {
        let mut direction = record.normal + Vector3::random_unit();

        if direction.near_zero() {
            direction = record.normal;
        }
        let scattered = Ray::new(record.point, direction);

        Some((self.albedo, scattered))
    }
}

pub struct Metal {
    albedo: Color,
    // 模糊属性
    fuzz: f64,
}

impl Metal {
    pub fn new(albedo: Color, fuzz: f64) -> Self {
        Metal { albedo, fuzz }
    }
}

impl Material for Metal {
    fn scatter(&self, ray: &Ray, record: &HitRecord) -> Option<(Color, Ray)> {
        let direction = ray.direction.unit();

        let normal = record.normal;
        let reflected = direction - 2.0 * direction.dot(normal) * normal;
        let ray = reflected + self.fuzz * Vector3::random_unit();
        let scattered = Ray::new(record.point, ray);

        match scattered.direction.dot(normal) > 0.0 {
            true => Some((self.albedo, scattered)),
            false => None,
        }
    }
}

pub struct Dielectric {
    // 折射率
    refraction: f64,
}

impl Dielectric {
    pub fn new(refraction: f64) -> Dielectric {
        Dielectric { refraction }
    }

    // 折射
    fn refract(uv: Vector3, n: Vector3, f: f64) -> Vector3 {
        let cos_theta = (-1.0 * uv).dot(n).min(1.0);
        let r = f * (uv + cos_theta * n);
        r - (1.0 - r.dot(r)).abs().sqrt() * n
    }

    fn reflectance(cosine: f64, ref_idx: f64) -> f64 {
        let r0 = ((1.0 - ref_idx) / (1.0 + ref_idx)).powi(2);
        r0 + (1.0 - r0) * (1.0 - cosine).powi(5)
    }
}

impl Material for Dielectric {
    fn scatter(&self, ray: &Ray, record: &HitRecord) -> Option<(Color, Ray)> {
        let ratio = match record.face {
            true => 1.0 / self.refraction,
            false => self.refraction,
        };

        let normal = record.normal;
        let direction = ray.direction().unit();
        let cos = (-1.0 * direction).dot(normal).min(1.0);
        let sin = (1.0 - cos.powi(2)).sqrt();

        let mut rand = rand::thread_rng();
        let cannot_refract = ratio * sin > 1.0;
        let will_reflect = Self::reflectance(cos, ratio) > rand.gen();

        let direction = match cannot_refract || will_reflect {
            true => direction - 2.0 * direction.dot(normal) * normal,
            false => Self::refract(direction, normal, ratio),
        };

        let scattered = Ray::new(record.point, direction);
        Some((Color::new(1.0, 1.0, 1.0), scattered))
    }
}
