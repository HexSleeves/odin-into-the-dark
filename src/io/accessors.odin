package gameio

// Accessor for the package-global logger, so other packages can pass it to the
// logger procs without taking the address of the global directly.

logger_state :: proc() -> ^Game_Logger {
	return &g_logger
}
