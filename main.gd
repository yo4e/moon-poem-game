extends Node3D

const INK = Color("eeeade")
const GOLD = Color("edcc8a")
const MUTED = Color("b0bdcf")
const LANES = [-4.2,0.0,4.2]
const DEPTHS = [-2.8,0.3,3.4]
const MOVE_SPEED = 5.8
const POOLS = [
	["眠れない月が", "迷子のねこが", "真夜中のプリンが", "小さなため息が", "きのうのわたしが", "靴下の片方が", "旅する雲が", "おやすみの風が"],
	["ポケットの海で", "星くずの駅で", "だれもいない台所で", "やわらかな夢の中で", "月の裏がわで", "コーヒーの底で", "ひみつの屋上で", "午前二時の森で"],
	["そっと踊っている", "明日をあたためる", "休憩してもいいと言う", "宇宙にあくびをする", "きみに花を贈る", "小さな朝を待っている", "名前のない歌をうたう", "おかわりをねだる"]
]
var font: Font
var state = "title"
var elapsed = 0.0
var stage = 0
var poem: Array[String] = []
var drops: Array[Dictionary] = []
var sparks: Array[Dictionary] = []
var catcher_x = 0.0
var target_x = 0.0
var catcher_z = 0.0
var target_z = 0.0
var transition = 0.0
var flash_text = ""
var rounds = 0
var paused = false
var copied = false
var muted = false
var boat: Node3D
var camera: Camera3D
var overlay: Node2D
var player: AudioStreamPlayer
var main_button = Rect2(354,530,292,56)
var copy_button = Rect2(400,603,200,36)
var rng = RandomNumberGenerator.new()

func material(color: Color, unshaded = false) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if unshaded else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.roughness = 0.55
	return m

func mesh(parent: Node3D, shape: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var instance = MeshInstance3D.new()
	instance.mesh = shape
	instance.material_override = mat
	instance.position = pos
	parent.add_child(instance)
	return instance

func ball(parent: Node3D, pos: Vector3, radius: float, color: Color, flat = false) -> MeshInstance3D:
	var shape = SphereMesh.new()
	shape.radius = radius
	shape.height = radius*2
	shape.radial_segments = 16
	shape.rings = 8
	return mesh(parent,shape,material(color,flat),pos)

func _ready():
	font = load("res://assets/moon-jp.otf")
	rng.randomize()
	build_world()
	var canvas = CanvasLayer.new()
	add_child(canvas)
	overlay = Node2D.new()
	overlay.set_script(load("res://overlay.gd"))
	overlay.game = self
	canvas.add_child(overlay)
	player = AudioStreamPlayer.new()
	add_child(player)
	if "--self-test" in OS.get_cmdline_user_args(): call_deferred("self_test")

func build_world():
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("101c34")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("a4c2e5")
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world = WorldEnvironment.new()
	world.environment = env
	add_child(world)
	camera = Camera3D.new()
	camera.position = Vector3(0,6.2,16)
	add_child(camera)
	camera.look_at(Vector3(0,2.1,0))
	camera.fov = 48
	camera.current = true
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40,-25,0)
	light.light_color = Color("d9e4ff")
	light.light_energy = 1.2
	add_child(light)
	var water = PlaneMesh.new()
	water.size = Vector2(140,140)
	water.subdivide_width = 60
	water.subdivide_depth = 60
	var shader = Shader.new()
	shader.code = """shader_type spatial;
render_mode cull_disabled;
varying vec3 world_pos;
void vertex(){VERTEX.y += sin(VERTEX.x*1.4+TIME*.65)*.05+cos(VERTEX.z*1.1+TIME*.5)*.035;world_pos=VERTEX;}
void fragment(){float wave=sin(world_pos.x*1.4+world_pos.z*2.1+sin(world_pos.z*.6+world_pos.x*.8)*1.2+TIME*.8)*.5+.5;float glint=pow(wave,24.0)*.06;float trail=exp(-abs(world_pos.x-3.0)*.65)*.13;ALBEDO=mix(vec3(.025,.075,.13),vec3(.08,.18,.25),wave*.32)+vec3(.45,.48,.4)*(glint+trail);ROUGHNESS=.32;METALLIC=.45;}
"""
	var sea_mat = ShaderMaterial.new()
	sea_mat.shader = shader
	mesh(self,water,sea_mat,Vector3(0,-0.55,0))
	# Low islands establish an actual perspective horizon.
	for i in range(8):
		var island = SphereMesh.new()
		island.radius = 1.0
		island.height = 2.0
		var land = mesh(self,island,material(Color("152940"),true),Vector3(-32+i*9,-0.8,-33-rng.randf()*8))
		land.scale = Vector3(6+rng.randf()*4,1+rng.randf(),3)
	# Moon and stars are placed in the 3D sky behind the play field.
	ball(self,Vector3(9,10,-24),1.8,GOLD,true)
	ball(self,Vector3(9.75,10.45,-22.8),1.58,Color("101c34"),true)
	for i in range(95):
		ball(self,Vector3(rng.randf_range(-39,39),rng.randf_range(5.5,24),rng.randf_range(-50,-28)),rng.randf_range(.02,.065),Color("b9c7d6"),true)
	boat = Node3D.new()
	boat.scale = Vector3.ONE*1.25
	add_child(boat)
	var hull = CSGPolygon3D.new()
	var poly = PackedVector2Array()
	for i in range(25):
		var t = float(i)/24
		poly.append(Vector2(-.95+1.9*t,-sin(t*PI)*.4))
	for i in range(24,-1,-1):
		var t = float(i)/24
		poly.append(Vector2(-.95+1.9*t,-sin(t*PI)*.12))
	hull.polygon = poly
	hull.depth = .62
	hull.material = material(GOLD)
	boat.add_child(hull)
	# A tiny moon rabbit tends the lantern.
	ball(boat,Vector3(0,.13,0),.18,Color("eeebe4"))
	ball(boat,Vector3(0,.37,.03),.14,Color("eeebe4"))
	for x in [-.075,.075]:
		var ear = ball(boat,Vector3(x,.58,.02),.07,Color("eeebe4"))
		ear.scale = Vector3(.55,2.2,.7)
		ball(boat,Vector3(x*.6,.39,.155),.016,Color("333952"))
	var pole = CylinderMesh.new()
	pole.top_radius = .018
	pole.bottom_radius = .018
	pole.height = .66
	mesh(boat,pole,material(Color("c4a675")),Vector3(.48,.28,0))
	ball(boat,Vector3(.48,.67,0),.09,Color("ffe2a1"),true)
	var lantern = OmniLight3D.new()
	lantern.position = Vector3(.48,.7,0)
	lantern.light_color = Color("ffdc8c")
	lantern.light_energy = 1.1
	lantern.omni_range = 3
	boat.add_child(lantern)
	# Subtle water-space grid, to make the three depth bands readable.
	for x in LANES:
		for z in DEPTHS:
			var ring = TorusMesh.new()
			ring.inner_radius = .055
			ring.outer_radius = .075
			mesh(self,ring,material(Color("45677a"),true),Vector3(x,-.39,z))

func start_round():
	clear_drops()
	state = "play"
	poem.clear()
	stage = 0
	paused = false
	transition = 0
	catcher_x = 0
	target_x = 0
	catcher_z = 0
	target_z = 0
	copied = false
	spawn_words()

func clear_drops():
	for d in drops:
		d.node.queue_free()
		d.marker.queue_free()
		d.beam.queue_free()
	drops.clear()

func spawn_words():
	clear_drops()
	var choices = POOLS[stage].duplicate()
	choices.shuffle()
	var depths = DEPTHS.duplicate()
	depths.shuffle()
	for i in range(3):
		var node = Node3D.new()
		node.position = Vector3(LANES[i],5.8+i*.3,depths[i])
		add_child(node)
		var label = Label3D.new()
		label.font = font
		label.text = choices[i]
		label.font_size = 48
		label.pixel_size = .0075
		label.outline_size = 12
		label.modulate = INK
		label.outline_modulate = Color("172a41")
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		node.add_child(label)
		var shard = PrismMesh.new()
		shard.size = Vector3(.07,.22,.05)
		mesh(node,shard,material(GOLD,true),Vector3(0,-.3,0))
		var ring = TorusMesh.new()
		ring.inner_radius = .83
		ring.outer_radius = .87
		var marker = mesh(self,ring,material(GOLD,true),Vector3(LANES[i],-.34,depths[i]))
		var beam_shape = CylinderMesh.new()
		beam_shape.top_radius = .011
		beam_shape.bottom_radius = .011
		beam_shape.height = 1
		var beam_mat = material(Color(.85,.78,.56,.22),true)
		beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var beam = mesh(self,beam_shape,beam_mat,Vector3(LANES[i],2.5,depths[i]))
		beam.scale.y = 5.8
		drops.append({"text":choices[i],"node":node,"marker":marker,"beam":beam,"speed":.75+stage*.035})

func collect(index: int):
	if state != "play" or transition > 0 or index < 0 or index >= drops.size(): return
	poem.append(drops[index].text)
	flash_text = drops[index].text
	for i in range(12):
		var particle = ball(self,Vector3(catcher_x,.6,catcher_z),.035,GOLD,true)
		sparks.append({"node":particle,"v":Vector3(rng.randf_range(-1,1),rng.randf_range(.7,1.7),rng.randf_range(-.5,.5)),"life":1.0})
	chime(stage)
	clear_drops()
	stage += 1
	transition = 1.3

func chime(note: int):
	if muted or DisplayServer.get_name() == "headless": return
	var samples = PackedByteArray()
	var frequency = [523.25,659.25,783.99][note%3]
	for i in range(11025):
		var t = float(i)/22050
		var sample = int(sin(t*frequency*TAU)*exp(-t*9)*minf(t*100,1)*.18*32767)
		samples.append(sample & 255)
		samples.append((sample>>8)&255)
	var wave = AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = 22050
	wave.data = samples
	player.stream = wave
	player.play()

func nearest_lane(x: float) -> int:
	var best = 0
	for i in range(3):
		if absf(LANES[i]-x)<absf(LANES[best]-x): best = i
	return best

func set_pointer(pos: Vector2):
	# Intersect the ray with the water plane: mouse, touch and drag all steer in X/Z.
	var origin = camera.project_ray_origin(pos)
	var direction = camera.project_ray_normal(pos)
	if absf(direction.y) > .001:
		var distance = (-.34-origin.y)/direction.y
		if distance > 0:
			var hit = origin+direction*distance
			target_x = clampf(hit.x,-5.6,5.6)
			target_z = clampf(hit.z,-3.5,4.1)

func within_catch(point: Vector3) -> bool:
	return Vector2(point.x-catcher_x,point.z-catcher_z).length() < .96

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_M: muted = not muted
			KEY_ESCAPE:
				if state == "play": paused = not paused
			KEY_SPACE, KEY_ENTER:
				if state != "play": start_round()
				elif paused: paused = false
			
	if event is InputEventMouseMotion and state == "play" and (event.button_mask & MOUSE_BUTTON_MASK_LEFT): set_pointer(event.position)
	if event is InputEventScreenDrag and state == "play": set_pointer(event.position)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT: tap(event.position)
	if event is InputEventScreenTouch and event.pressed: tap(event.position)

func tap(pos: Vector2):
	if Rect2(866,29,100,34).has_point(pos): muted = not muted
	elif state != "play" and main_button.has_point(pos): start_round()
	elif state == "result" and copy_button.has_point(pos):
		DisplayServer.clipboard_set("月のことば拾い 3D\n\n"+"\n".join(poem))
		copied = true
	elif state == "play":
		set_pointer(pos)
		if paused: paused = false

func _process(delta):
	if not paused:
		elapsed += delta
		if state == "play":
			var axis = Vector2(
				float(Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A)),
				float(Input.is_physical_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W)))
			if axis.length() > 0:
				var destination = Vector2(catcher_x,catcher_z)+axis.normalized()*MOVE_SPEED*delta
				target_x = clampf(destination.x,-5.6,5.6)
				target_z = clampf(destination.y,-3.5,4.1)
			var moved = Vector2(catcher_x,catcher_z).move_toward(Vector2(target_x,target_z),MOVE_SPEED*delta)
			catcher_x = moved.x
			catcher_z = moved.y
		boat.position = Vector3(catcher_x,.05+sin(elapsed*1.6)*.045,catcher_z if state=="play" else 2.4)
		boat.rotation.z = sin(elapsed*1.3)*.035
		boat.rotation.y = -.15+sin(elapsed*.5)*.06
		for s in sparks:
			s.node.position += s.v*delta
			s.v.y -= delta
			s.life -= delta
			s.node.scale = Vector3.ONE*maxf(.001,s.life)
			if s.life <= 0: s.node.queue_free()
		sparks = sparks.filter(func(s):return s.life>0)
		if state == "play":
			if transition>0:
				transition -= delta
				if transition<=0:
					if stage == 3:
						state = "result"
						rounds += 1
					else: spawn_words()
			else:
				for i in range(drops.size()):
					drops[i].node.position.y -= drops[i].speed*delta
					var height = maxf(.01,drops[i].node.position.y+.34)
					drops[i].beam.scale.y = height
					drops[i].beam.position.y = height/2-.34
					if drops[i].node.position.y <= .78 and drops[i].node.position.y >= .15 and within_catch(drops[i].node.position):
						collect(i)
						break
				if not drops.is_empty() and drops[2].node.position.y<-.9: spawn_words()
	overlay.queue_redraw()

func text(ui: Node2D, words: String, pos: Vector2, size: int, color = INK):
	ui.draw_string(font,pos,words,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func center(ui: Node2D, words: String, y: float, size: int, color = INK):
	var width = font.get_string_size(words,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	text(ui,words,Vector2(500-width/2,y),size,color)

func panel(ui: Node2D, rect: Rect2, color: Color, border: Color, radius=18):
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	ui.draw_style_box(style,rect)

func button(ui: Node2D, label: String):
	panel(ui,main_button,GOLD,Color("ffe6b0"),28)
	center(ui,label,565,18,Color("202d40"))

func draw_gui(ui: Node2D):
	text(ui,"MOON / WORD / POEM     ·     3D",Vector2(38,49),13,MUTED)
	text(ui,"音 "+("OFF" if muted else "ON")+"  · M",Vector2(872,49),13,MUTED)
	if state == "title":
		panel(ui,Rect2(251,145,498,302),Color(.045,.09,.16,.84),Color(.4,.53,.65,.34),24)
		center(ui,"月のことば拾い",228,40)
		center(ui,"月の海を、自由に散歩。",283,21,GOLD)
		center(ui,"奥にも、手前にも、言葉が降る。",345,17)
		center(ui,"水面の金色の輪へ、舟を動かして。",378,16,MUTED)
		center(ui,"こぼしても大丈夫。また降ってきます。",414,14,MUTED)
		button(ui,"月の海へ、出かける")
		center(ui,"W A S D ／ 矢印キー  ·  水面をクリック・ドラッグ",636,14)
		center(ui,"Space / Enter でもはじめられます",663,12,MUTED)
	elif state == "play":
		text(ui,"ことば  "+str(mini(stage+1,3))+" / 3",Vector2(38,102),20,GOLD)
		for i in range(3): ui.draw_circle(Vector2(44+i*23,126),4,GOLD if i<stage else Color("536d85"))
		if transition>0: center(ui,"「"+flash_text+"」",471,24,GOLD)
		panel(ui,Rect2(65,598,870,75),Color(.045,.08,.13,.84),Color(.3,.45,.56,.35),16)
		center(ui,"　／　".join(poem) if not poem.is_empty() else "好きな言葉の、金色の輪へ。奥にも手前にも動けます。",628,16)
		center(ui,"W A S D ／ 矢印キー ・ 水面をクリック     ·     Esc でひと休み",654,13,MUTED)
		if paused:
			ui.draw_rect(Rect2(0,0,1000,700),Color(.025,.045,.09,.85))
			center(ui,"ひと休み。",320,36,GOLD)
			center(ui,"クリック、Space、または Esc でつづける",372,17)
	else:
		panel(ui,Rect2(225,148,550,338),Color(.045,.085,.15,.93),Color(.43,.54,.65,.5),24)
		center(ui,"今夜、拾った詩",202,18,GOLD)
		for i in range(poem.size()): center(ui,poem[i],274+i*61,25)
		center(ui,"第 "+str(rounds)+" 夜   ·   正解のない、ちいさな詩。",454,14,MUTED)
		button(ui,"もうひとつ、拾いにいく")
		center(ui,"コピーしました" if copied else "詩をコピー",627,14,GOLD)
		center(ui,"Space / Enter でもう一度",658,12,MUTED)

func self_test():
	assert(camera is Camera3D and boat.get_child(0) is CSGPolygon3D)
	start_round()
	assert(drops.size()==3 and drops[0].node is Node3D)
	for i in range(3):
		collect(1)
		assert(poem.size()==i+1)
		_process(1.4)
	assert(state=="result" and rounds==1)
	start_round()
	assert(stage==0 and poem.is_empty())
	paused = true
	var before = drops[0].node.position.y
	_process(.5)
	assert(drops[0].node.position.y==before)
	paused = false
	catcher_x = LANES[0]
	target_x = catcher_x
	catcher_z = drops[0].node.position.z+2.0
	target_z = catcher_z
	drops[0].node.position.y = .8
	_process(.05)
	assert(poem.is_empty(),"Same X but wrong Z must not catch")
	catcher_z = drops[0].node.position.z
	target_z = catcher_z
	drops[0].node.position.y = .8
	_process(.05)
	assert(poem.size()==1)
	clear_drops()
	transition = 0
	spawn_words()
	for d in drops:d.node.position.y = -1
	_process(.01)
	assert(drops[0].node.position.y>5)
	assert(not within_catch(Vector3(catcher_x,0,catcher_z+1.5)))
	assert(within_catch(Vector3(catcher_x+.3,0,catcher_z+.3)))
	set_pointer(camera.unproject_position(Vector3(2,-.34,3)))
	assert(absf(target_x-2)<.01 and absf(target_z-3)<.01)
	set_pointer(camera.unproject_position(Vector3(-2,-.34,-3)))
	assert(absf(target_x+2)<.01 and absf(target_z+3)<.01)
	Input.use_accumulated_input = false
	var key = InputEventKey.new()
	key.physical_keycode = KEY_W
	key.keycode = KEY_W
	key.pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	var old_z = catcher_z
	_process(.1)
	assert(catcher_z<old_z,"W must move toward the horizon")
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	key = InputEventKey.new()
	key.physical_keycode = KEY_S
	key.keycode = KEY_S
	key.pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	old_z = catcher_z
	_process(.1)
	assert(catcher_z>old_z,"S must move toward the foreground")
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	print("PASS: real 3D world, start, three stages, result, replay, pause, XZ catch, wrong-depth rejection, near/far pointer mapping, W/S depth steering, missed-word respawn")
	get_tree().quit()
