package engine

Camera_Manager :: struct {
	x:        int,
	y:        int,
	target_x: int,
	target_y: int,
	zoom:     f32,
}

camera_manager_make :: proc() -> Camera_Manager {
	return Camera_Manager{zoom = 1}
}

camera_manager_zoom :: proc(camera: ^Camera_Manager) -> f32 {
	if camera == nil || camera.zoom <= 0 {
		return 1
	}
	return camera.zoom
}

camera_manager_set_zoom :: proc(camera: ^Camera_Manager, zoom: f32) {
	if camera == nil {
		return
	}
	camera.zoom = clamp(zoom, 1, 1.2)
}

camera_manager_update :: proc(
	camera: ^Camera_Manager,
	focus_x: int,
	focus_y: int,
	viewport_width: int,
	viewport_height: int,
	world_width: int,
	world_height: int,
	snap: bool = false,
) {
	if camera == nil {
		return
	}

	zoom := camera_manager_zoom(camera)
	view_width := int(f32(viewport_width) / zoom)
	view_height := int(f32(viewport_height) / zoom)

	cam_x := focus_x - view_width / 2
	cam_y := focus_y - view_height / 2

	if cam_x < 0 {cam_x = 0}
	if cam_y < 0 {cam_y = 0}
	if cam_x + view_width > world_width {cam_x = world_width - view_width}
	if cam_y + view_height > world_height {cam_y = world_height - view_height}

	if world_width < view_width {
		cam_x = -(view_width - world_width) / 2
	}
	if world_height < view_height {
		cam_y = -(view_height - world_height) / 2
	}

	camera.target_x = cam_x
	camera.target_y = cam_y

	if snap {
		camera.x = cam_x
		camera.y = cam_y
		return
	}

	LERP_SPEED :: 0.2
	diff_x := cam_x - camera.x
	diff_y := cam_y - camera.y
	// Integer lerp with minimum step of 1 to guarantee convergence.
	// Without this, diffs of 2-5 produce int(f32(diff)*0.2) = 0, stalling the camera.
	step_x := int(f32(diff_x) * LERP_SPEED)
	step_y := int(f32(diff_y) * LERP_SPEED)
	if diff_x != 0 && step_x == 0 {step_x = 1 if diff_x > 0 else -1}
	if diff_y != 0 && step_y == 0 {step_y = 1 if diff_y > 0 else -1}
	camera.x += step_x
	camera.y += step_y
}
