class_name Antialias
extends RefCounted
## Temporal anti-aliasing (TAA) on top of the project's 2x MSAA: MSAA smooths the edges of geometry, not what's drawn
## inside it -- the feather cards' cut-out edges, the scales on a bird's toes, fine texture -- which speckle from pixel to
## pixel; TAA blends each pixel over the last frames (jittered), clearing it, at the cost of a slight softening and
## faint trails behind fast motion. On by default in the game, the range and the menu; `--no-taa`, or F7 to compare.

static var taa := true


static func apply(node: Node, args: PackedStringArray) -> void:
	if args.has("--no-taa"):
		taa = false
	node.get_viewport().use_taa = taa


## F7: on or off. Returns whether it's on now.
static func toggle(node: Node) -> bool:
	taa = not taa
	node.get_viewport().use_taa = taa
	return taa
