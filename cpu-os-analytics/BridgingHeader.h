//
//  BridgingHeader.h
//  cpu-os-analytics
//
//  Created by Chris Ho on 1/23/26.
//
//To access the Mach kernel APIs (needed for thread-level detail), you need a Bridging Header because these are C APIs that Swift needs a little help "seeing."
#ifndef Bridging_Header_h
#define Bridging_Header_h

#include <libproc.h>
#include <mach/mach.h>
#include <signal.h>
#include <sys/param.h>
#include <sys/sysctl.h>
#include <IOKit/ps/IOPowerSources.h>

#include "ProcessMonitor.h"

#endif
