#include <PR/ultratypes.h>
#include <PR/gbi.h>

#include "sm64.h"
#include "game/segment2.h"

#ifdef ENABLE_ARABIC
// Keep the large pre-shaped line textures in the native executable. On the
// PS4 port these addresses are normal linked pointers, so they do not depend
// on the legacy N64 segmented-memory lookup used by segment 2.
#include "text/ar/generated/dialog_line_textures.inc.c"
#include "text/ar/generated/ui_textures.inc.c"
#include "text/ar/generated/credit_textures.inc.c"
#endif
