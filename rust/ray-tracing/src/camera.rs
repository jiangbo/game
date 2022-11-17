use super::ray::Ray;
use super::vector3::{Point3, Vector3};

pub struct Camera {
    origin: Point3,
    corner: Point3,
    horizontal: Vector3,
    vertical: Vector3,
    cu: Vector3,
    cv: Vector3,
    radius: f64,
}

impl Camera {
    pub fn new(
        origin: Point3,
        at: Point3,
        vup: Vector3,
        fov: f64,
        ratio: f64,
        aperture: f64,
        focus: f64,
    ) -> Camera {
        let theta = std::f64::consts::PI / 180.0 * fov;
        let viewport_height = 2.0 * (theta / 2.0).tan();
        let viewport_width = ratio * viewport_height;

        let cw = (origin - at).unit();
        let cu = vup.cross(cw);
        let cv = cw.cross(cu);

        let horizontal = focus * viewport_width * cu;
        let vertical = focus * viewport_height * cv;

        let corner = origin - horizontal / 2.0 - vertical / 2.0 - focus * cw;

        Camera {
            origin,
            horizontal,
            vertical,
            corner,
            cu,
            cv,
            radius: aperture / 2.0,
        }
    }

    pub fn get_ray(&self, u: f64, v: f64) -> Ray {
        let rd = self.radius * Vector3::random_in_unit_disk();
        let offset = self.cu * rd.x + self.cv * rd.y;
        let vector3 = self.corner + u * self.horizontal + v * self.vertical;

        Ray {
            origin: self.origin + offset,
            direction: vector3 - self.origin - offset,
        }
    }
}
