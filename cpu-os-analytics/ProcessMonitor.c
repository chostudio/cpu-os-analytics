//
//  ProcessMonitor.c
//  cpu-os-analytics
//
//  Uses libproc (C) to read process data. CPU time from proc_taskinfo is in Mach absolute
//  time ticks; we convert to seconds via mach_timebase_info and let Swift compute percentage from deltas.
//

#include "ProcessMonitor.h"
#include <libproc.h>
#include <sys/sysctl.h>
#include <sys/time.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <mach/mach_time.h>

static double timeval_to_seconds(const struct timeval *tv) {
	return (double)tv->tv_sec + (double)tv->tv_usec / 1000000.0;
}

int process_monitor_snapshot(process_entry_t *entries, int max_entries, int *out_count, double *out_sample_time) {
	if (!entries || max_entries <= 0 || !out_count || !out_sample_time) {
		return -1;
	}

	/* Sample time at start so all entries share the same logical snapshot time */
	struct timeval tv;
	if (gettimeofday(&tv, NULL) != 0) {
		return -1;
	}
	*out_sample_time = timeval_to_seconds(&tv);

	/* First call: return value is BYTES needed to hold all PIDs (per Apple docs) */
	int need_bytes = proc_listpids(PROC_ALL_PIDS, 0, NULL, 0);
	if (need_bytes <= 0) {
		*out_count = 0;
		return 0;
	}

	/* Allocate exactly that many bytes; second call takes buffer size in bytes */
	void *pids_buf = malloc((size_t)need_bytes);
	if (!pids_buf) {
		return -1;
	}

	int bytes_used = proc_listpids(PROC_ALL_PIDS, 0, pids_buf, need_bytes);
	if (bytes_used <= 0) {
		free(pids_buf);
		*out_count = 0;
		return 0;
	}
	pid_t *pids = (pid_t *)pids_buf;
	int num_pids = bytes_used / (int)sizeof(pid_t);

	// #region agent log
	/* DEBUG: Log mach_timebase_info to check tick-to-nanosecond conversion (Hypothesis 1) */
	{
		mach_timebase_info_data_t tbi;
		mach_timebase_info(&tbi);
		FILE *lf = fopen("/Users/chrisho/Desktop/cpu-os-analytics/.cursor/debug.log", "a");
		if (lf) {
			fprintf(lf, "{\"hypothesisId\":\"H1\",\"location\":\"ProcessMonitor.c:timebase\",\"message\":\"mach_timebase_info\",\"data\":{\"numer\":%u,\"denom\":%u,\"ns_per_tick\":%.6f},\"timestamp\":%.0f}\n",
				tbi.numer, tbi.denom, (double)tbi.numer/(double)tbi.denom, *out_sample_time*1000.0);
			fclose(lf);
		}
	}
	// #endregion

	int logged_count = 0;
	int written = 0;
	for (int i = 0; i < num_pids && written < max_entries; i++) {
		pid_t pid = pids[i];
		if (pid <= 0) {
			continue;
		}

		struct proc_taskinfo task_info;
		int task_size = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &task_info, sizeof(task_info));
		if (task_size != sizeof(task_info)) {
			continue;
		}

		/* Process name */
		char name_buf[PROCESS_ENTRY_NAME_MAX];
		if (proc_name(pid, name_buf, sizeof(name_buf)) <= 0) {
			strncpy(name_buf, "Unknown", sizeof(name_buf) - 1);
			name_buf[sizeof(name_buf) - 1] = '\0';
		}

		/* CPU time: pti_total_user and pti_total_system are in Mach absolute time ticks.
		   On Apple Silicon, 1 tick ≠ 1 ns; convert via mach_timebase_info (numer/denom). */
		uint64_t total_ticks = task_info.pti_total_user + task_info.pti_total_system;
		mach_timebase_info_data_t tbi;
		mach_timebase_info(&tbi);
		double cpu_time_sec = (double)total_ticks * (double)tbi.numer / (double)tbi.denom / 1e9;

		// #region agent log
		/* DEBUG: Log raw tick values and computed cpu_time for first 3 processes with nonzero CPU (Hypothesis 1,4) */
		if (logged_count < 3 && total_ticks > 0) {
			FILE *lf = fopen("/Users/chrisho/Desktop/cpu-os-analytics/.cursor/debug.log", "a");
			if (lf) {
				fprintf(lf, "{\"hypothesisId\":\"H1\",\"runId\":\"post-fix\",\"location\":\"ProcessMonitor.c:cpu_calc\",\"message\":\"raw_cpu_values\",\"data\":{\"pid\":%d,\"name\":\"%s\",\"pti_total_user\":%llu,\"pti_total_system\":%llu,\"total_ticks\":%llu,\"cpu_time_sec\":%.6f},\"timestamp\":%.0f}\n",
					pid, name_buf, task_info.pti_total_user, task_info.pti_total_system, total_ticks, cpu_time_sec, *out_sample_time*1000.0);
				fclose(lf);
			}
			logged_count++;
		}
		// #endregion

		/* Memory: resident size from proc_taskinfo (avoids proc_pid_rusage which can fault) */
		double memory_mb = (double)task_info.pti_resident_size / (1024.0 * 1024.0);

		if (written >= max_entries) {
			break;
		}
		process_entry_t *e = &entries[written];
		e->pid = (int32_t)pid;
		strncpy(e->name, name_buf, PROCESS_ENTRY_NAME_MAX - 1);
		e->name[PROCESS_ENTRY_NAME_MAX - 1] = '\0';
		e->cpu_time_sec = cpu_time_sec;
		e->memory_mb = memory_mb;
		e->threads = (int)task_info.pti_threadnum;
		written++;
	}

	free(pids_buf);
	*out_count = written;
	return 0;
}
