# Frost

Frost is a Zig library and application for converting between Conjunctive Normal Form (CNF, sometimes also Clausal Normal Form) and SAT formats.

## Installation

### As a Library

Add Frost to your Zig project using `zig fetch`:

```bash
zig fetch --save git+https://github.com/Entze/frost/#HEAD
```

Then add it to your `build.zig`:

```zig
const frost = b.dependency("frost", .{
    .target = target,
    .optimize = optimize,
});

exe.root_module.addImport("frost", frost.module("frost"));
```

### As an Application

Clone the repository and build:

```bash
git clone https://github.com/Entze/frost.git
cd frost
mise run build
```

## Usage

### As a Library

```zig
const frost = @import("frost");

// TODO: Add usage examples once API is developed
```

### As an Application

```bash
# TODO: Add usage examples once interface is developed
```

## Development

### Requirements

- Zig 0.15.2
- [mise](https://mise.jdx.dev/) (for task running and dev-dependency management)

### Building

Build the executable (output: `frost-{os}-{arch}[-{abi}]`):

```bash
zig build              # Default: build and install executable
zig build exe          # Explicitly build executable
# or using mise
mise run build:exe
mise run build:exe -- --profile ReleaseFast
```

Build libraries (output: `libfrost-{os}-{arch}[-{abi}].{a|so|dylib}` or `frost-{os}-{arch}[-{abi}].{lib|dll}` on Windows):

```bash
zig build lib-static   # Build static library
zig build lib-dynamic  # Build dynamic/shared library
# or using mise
mise run build:lib-static
mise run build:lib-dynamic
```

Build for release (all supported targets: Linux x86_64/aarch64 musl/gnu, macOS x86_64/aarch64, Windows x86_64/aarch64 gnu):

```bash
zig build release                           # Build for all supported targets (ReleaseFast)
zig build release -Drelease-profile=Debug   # Use Debug profile
# or using mise
mise run release
```

Configure target and optimization:

```bash
# Using zig build directly
zig build -Dtarget=x86_64-linux-musl -Doptimize=ReleaseSmall
zig build -Dtarget=aarch64-macos -Doptimize=ReleaseFast

# Using mise tasks with options
mise run build:exe -- --profile ReleaseSmall --target x86_64-linux-musl
mise run build:lib-static -- --profile ReleaseFast --target aarch64-macos
```

### Testing

```bash
zig build test         # Run all tests
mise run test          # Alternative using mise
```

### Documentation

```bash
zig build docs         # (Not yet implemented)
```

### Formatting

```bash
mise run fix --all
```

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

Please see [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines on:
- Development setup and workflow
- Release process using RELEASE.txt
- Code style and best practices
- Pull request guidelines

Before submitting, make sure to run `mise run check --all` and `mise run fix --all`.

## License

[GPL-3.0](https://www.gnu.org/licenses/gpl-3.0.en.html)
