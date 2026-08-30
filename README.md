# fast-delete

Parallel _file_ deletion using `unlinkat()` with directory fd caching.

## Build

```bash
cargo build --release
```

### With nix

```bash
nix --extra-experimental-features 'nix-command flakes' build .#fast-delete-native
./result/bin/fdel --help
```

Checks:

```bash
nix --extra-experimental-features 'nix-command flakes' flake check
```

## Usage

```bash
# From fd
fd -t f . /path | fdel --stdin

# Recursive
fdel /path/to/dir
```

## Options

```
-s, --stdin       Read paths from stdin
-j, --threads N   Thread count (default: auto-detect, override if needed)
-q, --quiet       No progress output
```

## How it works

1. Groups files by parent directory
1. Opens each directory once with `open(dir, O_DIRECTORY)`
1. Deletes files with `unlinkat(dirfd, filename, 0)`
1. Thread-local buffers (zero allocations per file)

This avoids repeated path resolution and reduces syscalls.

## License

MIT
