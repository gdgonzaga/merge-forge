extends RefCounted

# Layout rules shared by full-screen menus on a phone: keep a layout inside the
# display's safe area with a side margin, and make tab headers touch-sized.


# Android reports the window's safe rectangle in physical pixels. Desktop
# reports the whole display, which may be larger than the app window, so only
# Android's is applied.
static func inset_to_safe_area(layout: Control, viewport_size: Vector2, safe_area: Rect2i, screen_transform: Transform2D, platform_name: String, margin: float) -> void:
	var visible := Rect2(Vector2.ZERO, viewport_size)
	if platform_name == "Android" and safe_area.has_area():
		var to_canvas := screen_transform.affine_inverse()
		var start := to_canvas * Vector2(safe_area.position)
		var end := to_canvas * Vector2(safe_area.end)
		visible = visible.intersection(Rect2(start, end - start))
	layout.offset_left = visible.position.x + margin
	layout.offset_top = visible.position.y + margin
	layout.offset_right = visible.end.x - viewport_size.x - margin
	layout.offset_bottom = visible.end.y - viewport_size.y - margin


# Tall tab headers: the font size, and vertical padding on every tab style.
static func size_tabs_for_touch(tabs: TabContainer, font_size: int, vertical_padding: float) -> void:
	tabs.add_theme_font_size_override("font_size", font_size)
	for style_name: String in ["tab_selected", "tab_unselected", "tab_hovered", "tab_disabled"]:
		var style: StyleBox = tabs.get_theme_stylebox(style_name).duplicate()
		style.set_content_margin(SIDE_TOP, vertical_padding)
		style.set_content_margin(SIDE_BOTTOM, vertical_padding)
		tabs.add_theme_stylebox_override(style_name, style)
