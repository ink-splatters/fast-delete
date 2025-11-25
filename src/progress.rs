use std::io::{self, Write};
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::Arc;
use std::thread;
use std::time::{Duration, Instant};

pub fn spawn_reporter(
    deleted: Arc<AtomicU64>,
    errors: Arc<AtomicU64>,
    done: Arc<AtomicBool>,
    total: usize,
    start: Instant,
) -> thread::JoinHandle<()> {
    thread::spawn(move || {
        run(deleted, errors, done, total, start);
    })
}

fn run(
    deleted: Arc<AtomicU64>,
    errors: Arc<AtomicU64>,
    done: Arc<AtomicBool>,
    total: usize,
    start: Instant,
) {
    let mut last_count = 0u64;
    let mut last_time = Instant::now();

    while !done.load(Ordering::Relaxed) {
        thread::sleep(Duration::from_millis(500));

        let current_count = deleted.load(Ordering::Relaxed);
        let current_errors = errors.load(Ordering::Relaxed);
        let now = Instant::now();
        let elapsed = now.duration_since(start);

        let delta_count = current_count - last_count;
        let delta_time = now.duration_since(last_time).as_secs_f64();
        let inst_rate = if delta_time > 0.0 {
            delta_count as f64 / delta_time
        } else {
            0.0
        };

        let overall_rate = if elapsed.as_secs_f64() > 0.0 {
            current_count as f64 / elapsed.as_secs_f64()
        } else {
            0.0
        };

        let remaining = total.saturating_sub(current_count as usize);
        let eta_secs = if overall_rate > 0.0 {
            remaining as f64 / overall_rate
        } else {
            0.0
        };

        let progress_pct = (current_count as f64 / total as f64) * 100.0;

        print!(
            "\r[{:.1}%] {} / {} files | {:.0} files/sec | ETA: {:.0}s | Errors: {}     ",
            progress_pct, current_count, total, inst_rate, eta_secs, current_errors
        );
        io::stdout().flush().ok();

        last_count = current_count;
        last_time = now;
    }

    let final_count = deleted.load(Ordering::Relaxed);
    let final_errors = errors.load(Ordering::Relaxed);
    print!(
        "\r[100.0%] {} / {} files | Errors: {}     ",
        final_count, total, final_errors
    );
    io::stdout().flush().ok();
}
