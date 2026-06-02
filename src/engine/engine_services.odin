package engine

// ─── Engine services boundary ────────────────────────────────────────────────

ENGINE_SERVICE_MAX :: 16

Engine_Service_Id :: int
Engine_Service_Callback :: proc()

Engine_Service_Registration :: struct {
	id:  Engine_Service_Id,
	ctx: rawptr,
}

Engine_Services_Config :: struct {
	diagnostics_init:           Engine_Service_Callback,
	diagnostics_shutdown:       Engine_Service_Callback,
	runtime_assets_init:        Engine_Service_Callback,
	runtime_assets_shutdown:    Engine_Service_Callback,
}

Engine_Services :: struct {
	config:                      Engine_Services_Config,
	diagnostics_initialized:     bool,
	runtime_assets_initialized:  bool,
	service_count:               int,
	services:                    [ENGINE_SERVICE_MAX]Engine_Service_Registration,
}

engine_services_default_config :: proc() -> Engine_Services_Config {
	return Engine_Services_Config{}
}

engine_services_make :: proc(config: Engine_Services_Config) -> Engine_Services {
	return Engine_Services {
		config = config,
	}
}

engine_services_init_diagnostics :: proc(services: ^Engine_Services) {
	if services == nil || services.config.diagnostics_init == nil {
		return
	}

	services.config.diagnostics_init()
	services.diagnostics_initialized = true
}

engine_services_shutdown_diagnostics :: proc(services: ^Engine_Services) {
	if services == nil || !services.diagnostics_initialized {
		return
	}

	if services.config.diagnostics_shutdown != nil {
		services.config.diagnostics_shutdown()
	}
	services.diagnostics_initialized = false
}

engine_services_init_runtime_assets :: proc(services: ^Engine_Services) {
	if services == nil || services.config.runtime_assets_init == nil {
		return
	}

	services.config.runtime_assets_init()
	services.runtime_assets_initialized = true
}

engine_services_shutdown_runtime_assets :: proc(services: ^Engine_Services) {
	if services == nil || !services.runtime_assets_initialized {
		return
	}

	if services.config.runtime_assets_shutdown != nil {
		services.config.runtime_assets_shutdown()
	}
	services.runtime_assets_initialized = false
}

engine_services_register :: proc(
	services: ^Engine_Services,
	id: Engine_Service_Id,
	ctx: rawptr,
) -> bool {
	if services == nil || id < 0 || ctx == nil {
		return false
	}

	index, found := engine_services_find_index(services, id)
	if found {
		services.services[index].ctx = ctx
		return true
	}

	if services.service_count >= ENGINE_SERVICE_MAX {
		return false
	}

	services.services[services.service_count] = Engine_Service_Registration {
		id  = id,
		ctx = ctx,
	}
	services.service_count += 1
	return true
}

engine_services_has :: proc(services: ^Engine_Services, id: Engine_Service_Id) -> bool {
	_, found := engine_services_find_index(services, id)
	return found
}

engine_services_get :: proc(services: ^Engine_Services, id: Engine_Service_Id) -> rawptr {
	index, found := engine_services_find_index(services, id)
	if !found {
		return nil
	}
	return services.services[index].ctx
}

@(private = "file")
engine_services_find_index :: proc(
	services: ^Engine_Services,
	id: Engine_Service_Id,
) -> (index: int, found: bool) {
	if services == nil || id < 0 {
		return -1, false
	}

	for i in 0 ..< services.service_count {
		if services.services[i].id == id {
			return i, true
		}
	}
	return -1, false
}
