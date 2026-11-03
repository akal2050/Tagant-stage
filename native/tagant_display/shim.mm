// Godot's iOS plugin loader declares the init/deinit functions with C++ linkage.
// This shim forwards them to the Swift side.

extern "C" void tagant_display_start_swift(void);

void tagant_display_init() {
	tagant_display_start_swift();
}

void tagant_display_deinit() {
}
