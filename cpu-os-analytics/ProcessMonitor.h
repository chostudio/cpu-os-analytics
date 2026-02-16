//
//  ProcessMonitor.h
//  cpu-os-analytics
//
//  C API for process snapshot (CPU, memory, etc.) using libproc.
//  Used so CPU time and percentage are computed with correct struct layout and timing.
//

#ifndef ProcessMonitor_h
#define ProcessMonitor_h

#include <stdint.h>
#include <stddef.h>

#define PROCESS_ENTRY_NAME_MAX 256

typedef struct {
	int32_t pid;
	char name[PROCESS_ENTRY_NAME_MAX];
	double cpu_time_sec;
	double memory_mb;
	int threads;
} process_entry_t;

/// Fills \c entries with current process list; \c out_count is set to number of entries written.
/// \c out_sample_time is set to seconds since epoch (from gettimeofday) when the snapshot was taken.
/// Returns 0 on success, -1 on error (e.g. proc_listpids failed).
int process_monitor_snapshot(process_entry_t *entries, int max_entries, int *out_count, double *out_sample_time);

#endif /* ProcessMonitor_h */
