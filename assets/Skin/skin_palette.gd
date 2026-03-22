extends Node
class_name SkinPalette

# 30 tones (light -> deep). Chosen to stay in realistic ranges.
static func colors() -> Array[Color]:
	return [
		# Very light
		Color(0.98, 0.86, 0.78),
		Color(0.97, 0.84, 0.75),
		Color(0.96, 0.82, 0.72),
		Color(0.95, 0.80, 0.69),
		Color(0.94, 0.78, 0.66),

		# Light
		Color(0.92, 0.75, 0.62),
		Color(0.90, 0.72, 0.58),
		Color(0.88, 0.69, 0.55),
		Color(0.86, 0.66, 0.52),
		Color(0.84, 0.63, 0.49),

		# Light-medium
		Color(0.81, 0.60, 0.45),
		Color(0.78, 0.57, 0.42),
		Color(0.75, 0.54, 0.39),
		Color(0.72, 0.51, 0.36),
		Color(0.69, 0.48, 0.33),

		# Medium
		Color(0.66, 0.45, 0.31),
		Color(0.63, 0.43, 0.29),
		Color(0.60, 0.40, 0.27),
		Color(0.57, 0.38, 0.26),
		Color(0.54, 0.35, 0.24),

		# Medium-deep
		Color(0.50, 0.33, 0.23),
		Color(0.46, 0.30, 0.21),
		Color(0.43, 0.28, 0.20),
		Color(0.40, 0.26, 0.18),
		Color(0.37, 0.24, 0.17),

		# Deep
		Color(0.34, 0.22, 0.15),
		Color(0.30, 0.20, 0.14),
		Color(0.27, 0.18, 0.13),
		Color(0.24, 0.16, 0.12),
		Color(0.21, 0.14, 0.10),
	]
