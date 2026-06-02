package engine

// ─── Engine services boundary ────────────────────────────────────────────────

Engine_Service_Callback :: proc()

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
