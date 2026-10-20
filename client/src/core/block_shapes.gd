class_name BlockShapes
extends RefCounted

## Piece shape catalog — MUST stay identical (order + cells) to
## server/src/game/shapes.ts. Cells are Vector2i (x=col, y=row) offsets
## normalized so min row = min col = 0.

const SHAPE_COUNT := 26

static var SHAPES: Array = [
	{"id": "single",    "cells": [Vector2i(0, 0)]},
	{"id": "domino_h",  "cells": [Vector2i(0, 0), Vector2i(1, 0)]},
	{"id": "domino_v",  "cells": [Vector2i(0, 0), Vector2i(0, 1)]},
	{"id": "tri_h",     "cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]},
	{"id": "tri_v",     "cells": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)]},
	{"id": "line4_h",   "cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]},
	{"id": "line4_v",   "cells": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3)]},
	{"id": "line5_h",   "cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)]},
	{"id": "line5_v",   "cells": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3), Vector2i(0, 4)]},
	{"id": "square2",   "cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]},
	{"id": "square3",   "cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)]},
	{"id": "corner_tl", "cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]},
	{"id": "corner_tr", "cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)]},
	{"id": "corner_bl", "cells": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)]},
	{"id": "corner_br", "cells": [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]},
	{"id": "l_big_a",   "cells": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2)]},
	{"id": "l_big_b",   "cells": [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 2), Vector2i(1, 2)]},
	{"id": "l_big_c",   "cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, 2)]},
	{"id": "l_big_d",   "cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2)]},
	{"id": "t_up",      "cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)]},
	{"id": "t_down",    "cells": [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]},
	{"id": "s_h",       "cells": [Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1)]},
	{"id": "z_h",       "cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)]},
	{"id": "rect_2x3",  "cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]},
	{"id": "plus",      "cells": [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)]},
	{"id": "u_shape",   "cells": [Vector2i(0, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]},
]

## Spawn weights mirrored from server/src/game/shapes.ts.
const SHAPE_WEIGHTS: Array[int] = [
	8, 10, 10, 9, 9, 7, 7, 5, 5, 9, 4, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 5, 5, 4, 3, 3,
]

static func cells(shape_index: int) -> Array:
	return SHAPES[shape_index]["cells"]

static func shape_id(shape_index: int) -> String:
	return SHAPES[shape_index]["id"]

## Bounding-box size of a shape as Vector2i(width, height).
static func bounds_of(cells: Array) -> Vector2i:
	var max_c := 0
	var max_r := 0
	for cell in cells:
		max_c = maxi(max_c, cell.x)
		max_r = maxi(max_r, cell.y)
	return Vector2i(max_c + 1, max_r + 1)
