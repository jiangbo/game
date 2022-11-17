use std::rc::Rc;

use crate::hittable::{Hit, HitRecord};
use crate::material::Material;
use crate::{ray::Ray, vector3::Point3};

pub struct Sphere {
    center: Point3,
    radius: f64,
    material: Rc<dyn Material>,
}

impl Sphere {
    pub fn new(center: Point3, radius: f64, material: Rc<dyn Material>) -> Sphere {
        Sphere {
            center,
            radius,
            material,
        }
    }
}

impl Hit for Sphere {
    fn hit(&self, ray: &Ray, min: f64, max: f64) -> Option<HitRecord> {
        // 球心到射线起点的向量，
        let oc = ray.origin() - self.center;

        let a = ray.direction().dot(ray.direction);
        let b = oc.dot(ray.direction());
        let c = oc.dot(oc) - self.radius * self.radius;
        let discriminant = b * b - a * c;

        if discriminant < 0.0 {
            return None;
        }

        let sqrt = discriminant.sqrt();
        let mut root = (-b - sqrt) / a;
        if root < min || max < root {
            root = (-b + sqrt) / a;
            if root < min || max < root {
                return None;
            }
        }

        let point = ray.at(root);
        let mut normal = (point - self.center) / self.radius;

        let face = ray.direction.dot(normal) < 0.0;
        if !face {
            normal = -1.0 * normal
        }

        Some(HitRecord {
            point,
            normal,
            t: root,
            face,
            material: Rc::clone(&self.material),
        })
    }
}
