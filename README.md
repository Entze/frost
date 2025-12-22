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

```bash
mise run build
```

### Testing

```bash
mise run test
```

### Formatting

```bash
mise run fix --all
```

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

Please make sure to update tests as appropriate and run `mise run fix --all` before submitting.

## License

[GPL-3.0](https://www.gnu.org/licenses/gpl-3.0.en.html)
