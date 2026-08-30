mod delete;
mod progress;

use anyhow::Result;
use clap::Parser;
use std::fs;
use std::io::{self, BufRead, BufReader};
use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::time::Instant;

#[derive(Parser)]
#[command(about = "Parallel file deletion using unlinkat() with directory fd caching")]
struct Args {
    #[arg(short, long)]
    stdin: bool,

    #[arg(value_name = "DIR")]
    directory: Option<PathBuf>,

    /// Number of parallel threads (default: auto-detected)
    #[arg(short = 'j', long)]
    threads: Option<usize>,

    #[arg(short, long)]
    quiet: bool,
}

fn detect_optimal_threads() -> usize {
    #[cfg(all(target_arch = "aarch64", target_vendor = "apple"))]
    {
        let mut performance_cores: libc::c_int = 0;
        let mut value_size = std::mem::size_of_val(&performance_cores);

        // SAFETY: The name is NUL-terminated, `performance_cores` is writable for
        // `value_size` bytes, and null new-value arguments make this a read.
        let status = unsafe {
            libc::sysctlbyname(
                c"hw.perflevel0.physicalcpu".as_ptr(),
                std::ptr::from_mut(&mut performance_cores).cast(),
                &mut value_size,
                std::ptr::null_mut(),
                0,
            )
        };

        if status == 0
            && value_size == std::mem::size_of_val(&performance_cores)
            && performance_cores > 0
        {
            return performance_cores as usize;
        }
    }

    std::thread::available_parallelism()
        .map(|n| n.get())
        .unwrap_or(4)
}

fn main() -> Result<()> {
    let args = Args::parse();
    let start = Instant::now();

    let threads = args.threads.unwrap_or_else(detect_optimal_threads);

    rayon::ThreadPoolBuilder::new()
        .num_threads(threads)
        .build_global()?;

    let paths = if args.stdin {
        collect_stdin()?
    } else if let Some(dir) = args.directory {
        collect_dir(&dir)?
    } else {
        anyhow::bail!("Provide --stdin or <DIR>");
    };

    let total = paths.len();
    if !args.quiet {
        println!("Deleting {} files with {} threads", total, threads);
    }

    let deleted = Arc::new(AtomicU64::new(0));
    let errors = Arc::new(AtomicU64::new(0));
    let done = Arc::new(AtomicBool::new(false));

    let progress_handle = if !args.quiet {
        Some(progress::spawn_reporter(
            Arc::clone(&deleted),
            Arc::clone(&errors),
            Arc::clone(&done),
            total,
            start,
        ))
    } else {
        None
    };

    let grouped = delete::group_by_parent(paths);
    delete::delete_with_dirfd(grouped, &deleted, &errors);

    done.store(true, Ordering::Relaxed);
    if let Some(handle) = progress_handle {
        handle.join().ok();
    }

    let elapsed = start.elapsed();
    let del = deleted.load(Ordering::Relaxed);
    let err = errors.load(Ordering::Relaxed);
    let rate = del as f64 / elapsed.as_secs_f64();

    if !args.quiet {
        println!("\n\nCompleted!");
        println!("  Deleted: {}", del);
        println!("  Errors: {}", err);
        println!("  Time: {:.2}s", elapsed.as_secs_f64());
        println!("  Rate: {:.0} files/sec", rate);
    }

    Ok(())
}

fn collect_stdin() -> Result<Vec<PathBuf>> {
    let stdin = io::stdin();
    let reader = BufReader::with_capacity(1024 * 1024, stdin.lock());
    Ok(reader
        .lines()
        .map(|line| line.map(PathBuf::from))
        .collect::<io::Result<_>>()?)
}

fn collect_dir(dir: &Path) -> Result<Vec<PathBuf>> {
    let mut paths = Vec::new();
    let mut stack = vec![dir.to_path_buf()];

    while let Some(d) = stack.pop() {
        for entry in fs::read_dir(d)? {
            let entry = entry?;
            let path = entry.path();
            if entry.file_type()?.is_dir() {
                stack.push(path);
            } else {
                paths.push(path);
            }
        }
    }
    Ok(paths)
}
