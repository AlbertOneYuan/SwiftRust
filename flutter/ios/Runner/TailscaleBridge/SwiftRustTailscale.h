// SwiftRust, 2026-11-21. SPDX-License-Identifier: AGPL-3.0-only
#include "tailscale.h"
// output is malloc-allocated; caller must free it. No credentials are logged.
int SwiftRustTSAction(tailscale sd, const char *action, char **output);
int SwiftRustTSClose(tailscale sd);
