//! The Camera uses user input to smoothly influence it's position and rotation.
//! This state is used to derive view and projection matrices for rendering.

const std = @import("std");
const zm = @import("zmath");

pub const Camera = struct {
    // Kinematics
    position: zm.Vec,
    velocity: zm.Vec,
    // Scalars
    yaw: f32,
    pitch: f32,
    aspect: f32,
    fov: f32,
    // Vectors
    look: zm.Vec,
    right: zm.Vec,
    above: zm.Vec,
    // Matrices
    view: zm.Mat,
    proj: zm.Mat,
    world_to_clip: zm.Mat,

    pub fn init() Camera {
        var cam = Camera{
            .position = @splat(0),
            .velocity = @splat(0),

            .yaw = -90,
            .pitch = 0,
            .aspect = 1,
            .fov = undefined,

            .look = undefined,
            .right = undefined,
            .above = undefined,

            .view = undefined,
            .proj = undefined,
            .world_to_clip = undefined,
        };

        cam.calcVecs();
        cam.setFov(75);

        return cam;
    }

    pub fn turn(cam: *Camera, mouse_delta: zm.Vec) void {
        if (mouse_delta[0] == 0 and mouse_delta[1] == 0) return;
        cam.setAngle(
            cam.yaw + mouse_delta[0] * SENS,
            cam.pitch + mouse_delta[1] * SENS,
        );
    }

    pub fn step(cam: *Camera, input: zm.Vec, time_delta: f32) void {
        var acc = zm.f32x4s(0);
        acc += zm.f32x4s(input[0]) * cam.right;
        acc += zm.f32x4s(input[1]) * UP;
        acc += zm.f32x4s(input[2]) * cam.look;

        if (zm.lengthSq3(acc)[0] > 0) {
            if (zm.lengthSq3(acc)[0] > 1) {
                acc = zm.normalize3(acc);
            }

            cam.velocity += zm.f32x4s(time_delta * SPEED / ACC_TIME) * acc;

            if (zm.length3(cam.velocity)[0] > SPEED) {
                cam.velocity = zm.normalize3(cam.velocity) * zm.f32x4s(SPEED);
            }
        } else if (zm.lengthSq3(cam.velocity)[0] == 0) return;

        const power = time_delta * (1 - zm.length3(acc)[0]) * FRICTION;
        cam.velocity *= @splat(std.math.pow(f32, 2, -power));
        cam.position += cam.velocity * zm.f32x4s(time_delta);

        cam.calcView();
    }

    pub fn scroll(cam: *Camera, input: zm.Vec) void {
        if (input[1] == 0) return;
        cam.position += cam.look * zm.f32x4s(input[1] * SPEED * SCROLL);
        cam.calcView();
    }

    pub fn calcAspect(cam: *Camera, resolution: zm.Vec) void {
        cam.aspect = resolution[0] / resolution[1];
        cam.calcProj();
    }

    fn setAngle(cam: *Camera, yaw: f32, pitch: f32) void {
        cam.yaw = @mod(yaw, 360);
        cam.pitch = zm.clamp(pitch, -PITCH_MAX, PITCH_MAX);
        cam.calcVecs();
    }

    fn calcVecs(cam: *Camera) void {
        const y = std.math.degreesToRadians(f32, cam.yaw);
        const p = std.math.degreesToRadians(f32, cam.pitch);
        const c = @cos(p);
        cam.look = zm.normalize3(zm.f32x4(@cos(y) * c, @sin(p), @sin(y) * c, 0));
        cam.right = zm.normalize3(zm.cross3(cam.look, UP));
        cam.above = zm.normalize3(zm.cross3(cam.look, cam.right));
        cam.calcView();
    }

    fn setFov(cam: *Camera, fov: f32) void {
        cam.fov = std.math.degreesToRadians(f32, fov);
        cam.calcProj();
    }

    fn calcView(cam: *Camera) void {
        cam.view = zm.lookToRh(cam.position, cam.look, UP);
        cam.world_to_clip = zm.mul(cam.view, cam.proj);
    }

    fn calcProj(cam: *Camera) void {
        cam.proj = zm.perspectiveFovRhGl(cam.fov, cam.aspect, NEAR, FAR);
        cam.world_to_clip = zm.mul(cam.view, cam.proj);
    }
};

const SPEED = 2.5;
const SCROLL = 0.2;
const ACC_TIME = 0.125;
const FRICTION = 12.5;

const SENS = 0.022 * 4;
const PITCH_MAX = 89;
const UP = zm.f32x4(0, 1, 0, 0);

const NEAR = std.math.pow(f32, 2, -4);
const FAR = std.math.pow(f32, 2, 12);
