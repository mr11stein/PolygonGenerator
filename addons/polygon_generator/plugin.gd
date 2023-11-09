@tool
extends EditorPlugin
var _polygon2d: Polygon2D

var tolerance:int = 3
var vertex_spacing:int = 40
var margin_outside:int = 10
var undo_redo = UndoRedo.new()


var button = Button.new()

func _make_visible(visible):
	button.visible = visible
	pass

func _edit(object) -> void:
	_polygon2d = object

func _handles(object) -> bool:
	return object is Polygon2D

func _enter_tree():
	button.text = "Generate Mesh"
	button.connect("pressed", generate_mesh);
	add_control_to_container(CONTAINER_CANVAS_EDITOR_MENU, button)
	pass

func _exit_tree():
	button.get_parent().remove_child(button)
	button.queue_free()
	pass

const delta_angle = -deg_to_rad(45)

func pixel_is_opaque(image: Image, pixel: Vector2) -> bool:
	return image.get_pixel(pixel.x, pixel.y).a > 0

func pixel_is_transparent(image: Image, pixel: Vector2) -> bool:
	return image.get_pixel(pixel.x, pixel.y).a == 0.0

func bresenham_low(p1: Vector2i, p2: Vector2i):
	var d:Vector2i = p2 - p1
	var y_increment:int = 1
	if d.y < 0:
		y_increment = -1
		d.y = -d.y
	var D:int = (2* d.y) - d.x
	var point:Vector2i = p1
	var points = Array()
	for i in range(abs(d.x)):
		point.x = p1.x + i
		points.append(point)
		if D > 0:
			point.y += y_increment
			D = D+ (2* (d.y -d.x))
		else:
			D = D+ 2*d.y
	return points

func bresenham_high(p1: Vector2i, p2: Vector2i):
	var d:Vector2i = p2 - p1
	var x_increment:int = 1
	if d.x < 0:
		x_increment = -1
		d.x = -d.x
	var D:int = (2* d.x) - d.y
	var point:Vector2i = p1
	var points = Array()
	for i in range(abs(d.y)):
		point.y = p1.y + i
		points.append(point)
		if D > 0:
			point.x += x_increment
			D = D+ (2* (d.x -d.y))
		else:
			D = D+ 2*d.x
	return points

func bresenham(p1: Vector2i, p2: Vector2i) -> Array:
	var d = p2 - p1
	if abs(d.y) < abs(d.x):
		if(d.x > 0):
			return bresenham_low(p1,p2)
		else:
			var result = bresenham_low(p2,p1)
			return result
	else:
		if(d.y > 0):
			return bresenham_high(p1,p2)
		else:
			var result = bresenham_high(p2,p1)
			return result

func bresenham2(p1: Vector2i, p2: Vector2i) -> Array:
	var point:Vector2i = p1
	var points = Array()
	var d = p2-p1
	var d_abs = abs(d)

	var x_increment = 1 if d.x > 0 else -1
	var y_increment = 1 if d.y > 0 else -1

	if d_abs.y > d_abs.x:
		var temp_x = d_abs.x
		d_abs.x = d_abs.y
		d_abs.y = temp_x

	var error: int = d_abs.x / 2
	point.y = p1.y

	if p1.y < p2.y:
		y_increment = 1
	else:
		y_increment = -1

	for x in range(p1.x, p2.x + 1):
		if d.x > 0:
			point.x = x
			points.append(point)
		else:
			point.x = p2.x - (x - p1.x)
			point.y =  p2.y - (point.y - p1.y)
			points.append(point)
		
		error = error - d_abs.y
		if error < 0:
			point.y = point.y + y_increment
			error = error + d_abs.x	
	return points

func is_out_of_bounds(image: Image, point: Vector2) -> bool:
	return point.x < 0 or point.y < 0 or point.x >= image.get_width() or point.y >= image.get_height()


func keeps_distance_to_border(image: Image, point: Vector2):
	for angle in range(0,360, 1):
		var direction = Vector2(1,0)
		var point_on_circle = point + (margin_outside * direction.rotated(deg_to_rad(angle)))
		if is_out_of_bounds(image, point_on_circle):
			continue
		if pixel_is_opaque(image, point_on_circle):
			return false
	return true


func generate_mesh():
	var image 
	if(_polygon2d.texture is CanvasTexture):
		image = _polygon2d.texture.diffuse_texture.get_image()
	else:
		image = _polygon2d.texture.get_image()
	var size = Vector2(image.get_width(), image.get_height())
	var uv_polygon = PackedVector2Array()

	for x in [size.x/2, size.x/2 + vertex_spacing]:
		for y in range(0, size.y-1):
			var point = Vector2(x,y)
			if pixel_is_opaque(image, point):
				var uv = (point-Vector2(0, margin_outside))
				uv = uv.clamp(Vector2(0,0), size - Vector2(1,1))
				uv_polygon.append(uv)
				break

	if uv_polygon.size() < 2: pass

	var total_loops = 0
	while uv_polygon.size() < 3 or uv_polygon[0].distance_to(uv_polygon[-1]) > vertex_spacing:
		var previous_point = uv_polygon[-1]
		var inclination = (previous_point - uv_polygon[-2]).normalized()
		var test_point = previous_point + (inclination * vertex_spacing)
		total_loops+=1
		if(total_loops > 1000): 
			break

		var inner_loops = 0
		test_point = test_point.clamp(Vector2(0,0), size - Vector2(1,1))

		#case tunneling/wall
		var next_direction = test_point - previous_point
		var next_length = next_direction.length()
		next_direction = next_direction.normalized()
		var edge_point = null
		var angle_direction = 1
		for t in range(0, next_length):
			var point = previous_point + t * next_direction
			if pixel_is_opaque(image, point):
				angle_direction = -1
		
		#case hit perpendicular
		var point_added = false
		for angle in range(0,360, 5):
			inclination = inclination.rotated(deg_to_rad(angle_direction * angle)).normalized()
			var actual_vertex_spacing = vertex_spacing/2 if angle > 45 else vertex_spacing
			test_point = previous_point + (inclination * actual_vertex_spacing)
			if is_out_of_bounds(image, test_point):
				continue
			if pixel_is_opaque(image, test_point): continue
			var perpendicular = Vector2(-inclination.y, inclination.x)
			var extended = test_point + perpendicular * actual_vertex_spacing * 2 
			var direction_perpendicular = extended - test_point
			var length_perpendicular = direction_perpendicular.length()
			direction_perpendicular = direction_perpendicular.normalized()
			for t in range(0, length_perpendicular):
				var point = test_point + t * direction_perpendicular
				if(point.x < 0 or point.x >= size.x or point.y < 0 or point.y >= size.y):
					point = point.clamp(Vector2(0,0), size - Vector2(1,1))
				if pixel_is_opaque(image, point) :
					var uv = Vector2(point.x, point.y) - perpendicular * (margin_outside+3)
					if not keeps_distance_to_border(image, uv):
						break
					uv_polygon.append(uv)
					point_added = true
					break
			if point_added: 
				#point added, stop circular search
				break
		if not point_added: 
			break
	_polygon2d.uv = uv_polygon
	_polygon2d.polygon = uv_polygon
	pass
