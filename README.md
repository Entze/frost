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

Build the executable:

```bash
zig build              # Build for native target (default step)
zig build exe          # Explicitly build executable
```

Build libraries:

```bash
zig build lib-static   # Build static library
zig build lib-dynamic  # Build dynamic/shared library
```

Build for release (multiple targets):

```bash
zig build release                           # Build for all supported targets (ReleaseFast)
zig build release -Drelease-profile=Debug   # Use Debug profile
```

### Build Options

Configure target and optimization:

```bash
zig build -Dtarget=x86_64-linux-musl -Doptimize=ReleaseSmall
zig build -Dtarget=aarch64-macos -Doptimize=ReleaseFast
```

### Output Naming Convention

Build artifacts include target information in their names:

- **Executables**: `frost-{os}-{arch}[-{abi}][.exe]`
  - Example: `frost-linux-x86_64-musl`, `frost-windows-aarch64-gnu.exe`

- **Static Libraries**: `libfrost-{os}-{arch}[-{abi}].a` (or `.lib` on Windows)
  - Example: `libfrost-linux-x86_64-gnu.a`, `frost-windows-x86_64-gnu.lib`

- **Shared Libraries**: `libfrost-{os}-{arch}[-{abi}].so` (or `.dll`/`.dylib` per platform)
  - Example: `libfrost-linux-aarch64-musl.so`, `libfrost-macos-aarch64.dylib`

### Supported Release Targets

The `release` step builds for these platforms:

- **Linux**: x86_64 (musl/gnu), aarch64 (musl/gnu)
- **macOS**: x86_64, aarch64
- **Windows**: x86_64 (gnu), aarch64 (gnu)

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
