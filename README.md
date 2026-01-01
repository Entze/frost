# Frost ❄️

Frost is a Zig library and application for converting between Conjunctive Normal Form (CNF, sometimes also Clausal Normal Form) and SAT formats. It supports conversion to and from DIMACS CNF and DIMACS SAT formats, and provides preprocessing capabilities for SAT solvers.

## Installation

### Using Zig Package Manager (Library)

Add Frost to your Zig project:

```bash
zig fetch --save git+https://github.com/Entze/frost/#HEAD
```

Then import it in your `build.zig`:

```zig
const frost = b.dependency("frost", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("frost", frost.module("frost"));
```

### From Source (Application)

```bash
git clone https://github.com/Entze/frost.git
cd frost
zig build
# Executable available at zig-out/bin/frost
```

For detailed build instructions, cross-compilation, and development setup, see [CONTRIBUTING.md](CONTRIBUTING.md).

## Usage

### Library Usage

```zig
const frost = @import("frost");

// API documentation available at https://entze.github.io/frost/
// Examples coming soon as the API stabilizes
```

For complete library documentation, visit [entze.github.io/frost](https://entze.github.io/frost/).

### Command-Line Usage

```bash
# CLI interface is under development
# Usage examples will be added as features are implemented
frost --help
```

## Support

- **Documentation**: [entze.github.io/frost](https://entze.github.io/frost/)
- **Issue Tracker**: [github.com/Entze/frost/issues](https://github.com/Entze/frost/issues)
- **Contributing**: See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup and guidelines

## Authors and Acknowledgment

**Author**: Lukas Grassauer ([@Entze](https://github.com/Entze))

### Acknowledgments

Acknowledgments for influences, inspirations, and resources will be added here.

## License

This project is licensed under the [GPL-3.0](https://www.gnu.org/licenses/gpl-3.0.en.html) license.

## Project Status

Frost is under active development and currently in draft state. The API is evolving and may change between versions. Contributions and feedback are welcome!

For information on contributing, please see [CONTRIBUTING.md](CONTRIBUTING.md).

**Development Resources:**
- [ROADMAP.md](ROADMAP.md) - Planned features and project direction
- [CHANGELOG.md](CHANGELOG.md) - Release history and change log

