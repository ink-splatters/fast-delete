use rayon::prelude::*;
use std::cell::RefCell;
use std::collections::HashMap;
use std::fs;
use std::io;
use std::os::unix::ffi::OsStrExt;
use std::path::PathBuf;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;

thread_local! {
    static FILENAME_BUF: RefCell<Vec<u8>> = RefCell::new(Vec::with_capacity(256));
    static PARENT_BUF: RefCell<Vec<u8>> = RefCell::new(Vec::with_capacity(4096));
}

pub fn group_by_parent(paths: Vec<PathBuf>) -> HashMap<PathBuf, Vec<PathBuf>> {
    let mut groups: HashMap<PathBuf, Vec<PathBuf>> = HashMap::new();
    for path in paths {
        if let Some(parent) = path.parent() {
            groups.entry(parent.to_path_buf()).or_default().push(path);
        }
    }
    groups
}

/// Delete files using unlinkat() with directory fd caching.
///
/// Opens each directory once, then deletes files within using unlinkat().
/// Parallel across directories, serial within each directory.
pub fn delete_with_dirfd(
    groups: HashMap<PathBuf, Vec<PathBuf>>,
    deleted: &Arc<AtomicU64>,
    errors: &Arc<AtomicU64>,
) {
    let dirs: Vec<_> = groups.into_iter().collect();

    dirs.par_iter().for_each(|(parent, files)| {
        let dirfd = PARENT_BUF.with(|buf| {
            let mut buf = buf.borrow_mut();
            buf.clear();
            buf.extend_from_slice(parent.as_os_str().as_bytes());
            buf.push(0);

            unsafe {
                libc::open(
                    buf.as_ptr() as *const i8,
                    libc::O_RDONLY | libc::O_DIRECTORY | libc::O_CLOEXEC,
                )
            }
        });

        if dirfd < 0 {
            for file in files {
                if fs::remove_file(file).is_err() {
                    errors.fetch_add(1, Ordering::Relaxed);
                } else {
                    deleted.fetch_add(1, Ordering::Relaxed);
                }
            }
            return;
        }

        for file in files {
            if let Some(filename) = file.file_name() {
                let filename_bytes = filename.as_bytes();

                if filename_bytes.contains(&0) {
                    errors.fetch_add(1, Ordering::Relaxed);
                    continue;
                }

                let result = FILENAME_BUF.with(|buf| {
                    let mut buf = buf.borrow_mut();
                    buf.clear();
                    buf.extend_from_slice(filename_bytes);
                    buf.push(0);

                    unsafe { libc::unlinkat(dirfd, buf.as_ptr() as *const i8, 0) }
                });

                if result == 0 {
                    deleted.fetch_add(1, Ordering::Relaxed);
                } else {
                    let err = io::Error::last_os_error();
                    if err.kind() != io::ErrorKind::NotFound {
                        errors.fetch_add(1, Ordering::Relaxed);
                    } else {
                        deleted.fetch_add(1, Ordering::Relaxed);
                    }
                }
            }
        }

        unsafe {
            libc::close(dirfd);
        }
    });
}
