package engine

Camera_Manager :: struct {
	x:        int,
	y:        int,
	target_x: int,
	target_y: int,
}

camera_manager_make :: proc() -> Camera_Manager {
	return Camera_Manager{}
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

	cam_x := focus_x - viewport_width / 2
	cam_y := focus_y - viewport_height / 2

	if cam_x < 0 {cam_x = 0}
	if cam_y < 0 {cam_y = 0}
	if cam_x + viewport_width > world_width {cam_x = world_width - viewport_width}
	if cam_y + viewport_height > world_height {cam_y = world_height - viewport_height}

	if world_width < viewport_width {
		cam_x = -(viewport_width - world_width) / 2
	}
	if world_height < viewport_height {
		cam_y = -(viewport_height - world_height) / 2
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
	camera.x += int(f32(diff_x) * LERP_SPEED)
	camera.y += int(f32(diff_y) * LERP_SPEED)

	if camera_manager_abs(diff_x) <= 1 {camera.x = cam_x}
	if camera_manager_abs(diff_y) <= 1 {camera.y = cam_y}
}

@(private = "file")
camera_manager_abs :: proc(v: int) -> int {
	if v < 0 {
		return -v
	}
	return v
}
