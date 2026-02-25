# ccat

A minimal command-line tool that reads a file and copies its contents to the clipboard. Written in [Zig](https://ziglang.org/).

## Features

- Reads any file and copies its full contents to the system clipboard
- Cross-platform clipboard support:
  - **macOS** — `pbcopy`
  - **Linux** — `wl-copy` (Wayland) or `xclip` (X11)

## Requirements

- [Zig](https://ziglang.org/download/) >= 0.15.2
- A supported clipboard tool on Linux (`wl-copy` or `xclip`)

## Build

```sh
zig build
```

For an optimized release build:

```sh
zig build -Doptimize=ReleaseFast
```

The binary will be at `zig-out/bin/ccat`.

## Usage

```sh
ccat <file_path>
```

**Examples:**

```sh
# Copy the contents of a file to the clipboard
ccat README.md

# Then paste it anywhere with Ctrl+V / Cmd+V
```

## How It Works

1. Opens the specified file and reads its contents into memory.
2. Spawns the platform-appropriate clipboard command (`pbcopy`, `wl-copy`, or `xclip`).
3. Pipes the file contents to the clipboard command's stdin.
4. Prints `Copied` on success.

