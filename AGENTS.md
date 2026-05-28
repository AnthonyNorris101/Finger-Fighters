# AGENTS.md

## Cursor Cloud specific instructions

### Project overview
This is **Finger Fighters**, a Godot 4.6.1 mobile gacha RPG game written in GDScript. It has zero external service dependencies — no databases, no backend, no package managers. The entire project runs within Godot.

### Running the project headlessly
Godot is installed at `/usr/local/bin/godot` (v4.6.1-stable).

```bash
# Import/validate project (checks GDScript compilation, registers classes)
godot --headless --path /workspace --import

# Run a scene headlessly (e.g. the GachaSystem test)
godot --headless --path /workspace --scene res://GachaSystem.tscn --quit-after 1

# Run main scene (turn_queue)
godot --headless --path /workspace --quit-after 3
```

### Key caveats
- **No traditional lint/test commands**: This project has no `npm`, `pip`, CI configs, or test frameworks. Validation is done via `godot --headless --import` (checks GDScript parsing/class registration) and running scenes with `--quit-after`.
- **Missing unit `.tres` files**: The `GachaTest.gd` script references unit resource files (`res://src/main/resources/units/*.tres`) that are not yet committed. This causes runtime `push_error()` messages (not crashes) — the system falls back to placeholder units. This is expected.
- **UID warning**: On first import you may see `Unrecognized UID: "uid://8gx6bjwgk5om"` — this resolves itself after the `.godot/` cache directory is built by `--import`.
- **`--quit-after` flag**: Use `--quit-after <seconds>` to auto-terminate headless scene runs. Without it, scenes run indefinitely.
- **No `.godot/` in repo**: The `.godot/` directory (editor cache, imported resources) is gitignored. Run `godot --headless --path /workspace --import` to regenerate it.
