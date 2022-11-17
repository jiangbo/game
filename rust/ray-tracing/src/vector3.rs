use std::ops::{Add, AddAssign, Div, Mul, Range, Sub};

use rand::Rng;

pub type Color = Vector3;
pub type Point3 = Vector3;

#[derive(Default, Clone, Copy)]
pub struct Vector3 {
    pub x: f64,
    pub y: f64,
    pub z: f64,
}

impl Vector3 {
    pub fn new(x: f64, y: f64, z: f64) -> Self {
        Self { x, y, z }
    }

    pub fn format_str(&self, samples: f64) -> String {
        let ir = (256.0 * (self.x / samples).sqrt().clamp(0.0, 0.999)) as u64;
        let ig = (256.0 * (self.y / samples).sqrt().clamp(0.0, 0.999)) as u64;
        let ib = (256.0 * (self.z / samples).sqrt().clamp(0.0, 0.999)) as u64;

        format!("{ir} {ig} {ib}\n")
    }

    /// 向量的长度
    pub fn length(self) -> f64 {
        self.dot(self).sqrt()
    }

    /// 向量的点乘
    pub fn dot(self, other: Vector3) -> f64 {
        self.x * other.x + self.y * other.y + self.z * other.z
    }

    // 向量的叉乘
    pub fn cross(self, other: Vector3) -> Vector3 {
        Vector3 {
            x: self.y * other.z - self.z * other.y,
            y: self.z * other.x - self.x * other.z,
            z: self.x * other.y - self.y * other.x,
        }
    }

    ///  单位向量
    pub fn unit(self) -> Vector3 {
        self / self.length()
    }

    pub fn random_unit() -> Self {
        loop {
            let mut rand = rand::thread_rng();

            let vector3 = Vector3 {
                x: rand.gen_range(-1.0..1.0),
                y: rand.gen_range(-1.0..1.0),
                z: rand.gen_range(-1.0..1.0),
            };

            if vector3.length() < 1.0 {
                return vector3.unit();
            }
        }
    }

    pub fn random_in_unit_disk() -> Vector3 {
        let mut rand = rand::thread_rng();
        loop {
            let p = Vector3::new(rand.gen_range(-1.0..1.0), rand.gen_range(-1.0..1.0), 0.0);
            if p.length() < 1.0 {
                return p;
            }
        }
    }

    pub fn random(range: Range<f64>) -> Vector3 {
        let mut rng = rand::thread_rng();
        Vector3 {
            x: rng.gen_range(range.clone()),
            y: rng.gen_range(range.clone()),
            z: rng.gen_range(range),
        }
    }

    pub fn near_zero(&self) -> bool {
        const EPS: f64 = 1.0e-8;
        self.x.abs() < EPS && self.y.abs() < EPS && self.z.abs() < EPS
    }
}

// 向量的加法
impl Add for Vector3 {
    type Output = Self;

    fn add(self, rhs: Self) -> Self {
        Vector3 {
            x: self.x + rhs.x,
            y: self.y + rhs.y,
            z: self.z + rhs.z,
        }
    }
}

// 向量的加法
impl AddAssign for Vector3 {
    fn add_assign(&mut self, rhs: Self) {
        *self = self.add(rhs)
    }
}

// 向量的减法
impl Sub for Vector3 {
    type Output = Self;

    fn sub(self, rhs: Self) -> Self {
        Self {
            x: self.x - rhs.x,
            y: self.y - rhs.y,
            z: self.z - rhs.z,
        }
    }
}

// 向量和数字的乘法
impl Mul<f64> for Vector3 {
    type Output = Self;

    fn mul(self, rhs: f64) -> Self {
        Self {
            x: self.x * rhs,
            y: self.y * rhs,
            z: self.z * rhs,
        }
    }
}

// 向量和数字的乘法
impl Mul<Vector3> for f64 {
    type Output = Vector3;

    fn mul(self, rhs: Vector3) -> Vector3 {
        rhs * self
    }
}

impl Mul for Vector3 {
    type Output = Self;

    fn mul(self, other: Vector3) -> Self {
        Vector3 {
            x: self.x * other.x,
            y: self.y * other.y,
            z: self.z * other.z,
        }
    }
}

// 向量的除法
impl Div<f64> for Vector3 {
    type Output = Self;

    fn div(self, rhs: f64) -> Self {
        Self {
            x: self.x / rhs,
            y: self.y / rhs,
            z: self.z / rhs,
        }
    }
}
