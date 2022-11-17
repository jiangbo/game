use std::rc::Rc;

use crate::material::Material;
use crate::ray::Ray;
use crate::vector3::{Point3, Vector3};

pub trait Hit {
    fn hit(&self, ray: &Ray, min: f64, max: f64) -> Option<HitRecord>;
}

pub struct HitRecord {
    pub point: Point3,
    pub normal: Vector3,
    pub t: f64,
    pub material: Rc<dyn Material>,
    pub face: bool,
}

pub type World = Vec<Box<dyn Hit>>;

impl Hit for World {
    fn hit(&self, ray: &Ray, min: f64, max: f64) -> Option<HitRecord> {
        let mut result = None;
        let mut nearest = max;

        // 找到一个最近的
        for hittable in self {
            if let Some(record) = hittable.hit(ray, min, nearest) {
                nearest = record.t;
                result = Some(record);
            }
        }

        result
    }
}
