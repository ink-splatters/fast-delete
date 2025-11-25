# fast-delete

Parallel _file_ deletion using `unlinkat()` with directory fd caching.

## Build

```bash
cargo build --release
```

## Usage

```bash
# From fd
fd -t f . /path | ./target/release/fdel --stdin

# Recursive
./target/release/fdel /path/to/dir
```

## Options

```
-s, --stdin       Read paths from stdin
-j, --threads N   Thread count (default: auto-detect, override if needed)
-q, --quiet       No progress output
```

## How it works

1. Groups files by parent directory
2. Opens each directory once with `open(dir, O_DIRECTORY)`
3. Deletes files with `unlinkat(dirfd, filename, 0)`
4. Thread-local buffers (zero allocations per file)

This avoids repeated path resolution and reduces syscalls.

## License

MIT
