class_name PersonagemProcedural
extends Node3D
signal golpe_concluido
signal golpe_impacto
## Humanoide estilizado construído por código (estilo "procedural"): serve ao jogador e
## aos moradores. Cada membro é um pivô com uma malha simples, animado por senos — sem
## esqueleto, sem GLB. Interface igual à dos animadores do modelo Tripo:
## update_motion, play_gesture, get_animation_names, get_current_animation.
## O modelo olha para +Z e tem a base no chão (y = 0); a altura total é `altura`.

const GESTOS := ["acenar", "concordar", "apontar", "coçar a cabeça", "alongar", "chamar", "reverência", "olhar em volta"]
const DURACAO_GESTO := 2.6
const DURACAO_GOLPE := 1.1
const VELOCIDADE_GOLPE := 1.875

## Paletas de 1887 no Recôncavo: algodão cru, anil, couro e palha.
const PALETAS := {
	"viajante": {"pele": "8d5a3b", "camisa": "e9dfc6", "calca": "3f4d63", "chapeu": "b89a5c", "cabelo": "2a1b12", "pes": "4a3324"},
	"pedro": {"pele": "6e4630", "camisa": "d8c9a3", "calca": "6b5a43", "chapeu": "c7ad70", "cabelo": "1c130d", "pes": ""},
	"benedito": {"pele": "5a3a26", "camisa": "cfc3a8", "calca": "4e4438", "chapeu": "9c8455", "cabelo": "d9d3c8", "pes": "3d2a1c"},
	"zefa": {"pele": "6a4630", "camisa": "b04a3f", "calca": "e6dcc4", "chapeu": "", "cabelo": "e7e2da", "pes": "", "saia": true, "lenco": "f0e6c8"},
	"cosme": {"pele": "7a5237", "camisa": "7f9c8a", "calca": "5b5040", "chapeu": "", "cabelo": "1a120c", "pes": ""},
	"tonho": {"pele": "8a5a3c", "camisa": "d9cfb4", "calca": "34495e", "chapeu": "c9b07a", "cabelo": "2b1d12", "pes": ""},
	"filo": {"pele": "5e3d2b", "camisa": "7c5c8c", "calca": "cbbfa5", "chapeu": "", "cabelo": "cfc8bd", "pes": "3d2a1c", "saia": true, "lenco": "e8dcc0"},
	"candinha": {"pele": "4f3322", "camisa": "d29a3c", "calca": "f0e7d2", "chapeu": "", "cabelo": "1a120c", "pes": "", "saia": true, "lenco": "f7f1e3"},
	"damiao": {"pele": "3f2a1c", "camisa": "6c6a63", "calca": "3b3a36", "chapeu": "5b5145", "cabelo": "111111", "pes": "2f221a"},
}

var altura := 1.78
var paleta: Dictionary = PALETAS["viajante"]
var _pivos: Dictionary = {}
var _materiais: Dictionary = {}
var _clock := 0.0
var _phase := 0.0
var _blend := 0.0
var _run_blend := 0.0
var _velocidade := 0.0
var _gesto := -1
var _gesto_tempo := 0.0
var _golpe_tempo := -1.0
var _golpes_restantes := 0
var _golpe_impacto_emitido := false
var _perna := 0.0
var _tronco := 0.0
var _construido := false


static func novo(nome_paleta: String, altura_m: float = 1.78) -> PersonagemProcedural:
	var personagem := PersonagemProcedural.new()
	personagem.name = "Personagem" + nome_paleta.capitalize()
	personagem.altura = altura_m
	personagem.paleta = PALETAS.get(nome_paleta, PALETAS["viajante"])
	return personagem


func _ready() -> void:
	if not _construido:
		construir()


## Monta o corpo. Proporções em função da altura: pernas 47 %, tronco 30 %, cabeça 15 %.
func construir() -> void:
	_construido = true
	for child in get_children():
		child.queue_free()
	_pivos.clear()
	var h := altura
	var coxa := 0.235 * h
	var canela := 0.22 * h
	var pe := 0.035 * h
	_perna = coxa + canela + pe
	_tronco = 0.30 * h
	var cabeca := 0.14 * h
	var ombro_x := 0.115 * h
	var largura_tronco := 0.24 * h
	var saia := bool(paleta.get("saia", false))

	var quadril := _pivo("Quadril", self, Vector3(0, _perna, 0))
	var pelvis := _malha_caixa(Vector3(largura_tronco * 0.92, 0.08 * h, 0.13 * h), _cor("calca"))
	pelvis.position = Vector3(0, 0.03 * h, 0)
	quadril.add_child(pelvis)
	var tronco := _malha_caixa(Vector3(largura_tronco, _tronco - 0.05 * h, 0.14 * h), _cor("camisa"))
	tronco.position = Vector3(0, 0.07 * h + (_tronco - 0.05 * h) * 0.5, 0)
	quadril.add_child(tronco)
	if saia:
		var saia_malha := _malha_cilindro(largura_tronco * 0.55, largura_tronco * 0.95, coxa + canela * 0.85, _cor("calca"))
		saia_malha.position = Vector3(0, -(coxa + canela * 0.85) * 0.5 + 0.02 * h, 0)
		quadril.add_child(saia_malha)

	var pescoco := _pivo("Pescoco", quadril, Vector3(0, _tronco + 0.02 * h, 0))
	var pescoco_malha := _malha_cilindro(0.03 * h, 0.035 * h, 0.05 * h, _cor("pele"))
	pescoco_malha.position = Vector3(0, 0.02 * h, 0)
	pescoco.add_child(pescoco_malha)
	var cabeca_pivo := _pivo("Cabeca", pescoco, Vector3(0, 0.045 * h, 0))
	var cabeca_malha := _malha_esfera(cabeca * 0.5, _cor("pele"))
	cabeca_malha.position = Vector3(0, cabeca * 0.5, 0)
	cabeca_malha.scale = Vector3(0.9, 1.0, 0.92)
	cabeca_pivo.add_child(cabeca_malha)
	var nariz := _malha_caixa(Vector3(0.02 * h, 0.03 * h, 0.03 * h), _cor("pele"))
	nariz.position = Vector3(0, cabeca * 0.45, cabeca * 0.45)
	cabeca_pivo.add_child(nariz)
	for lado in [-1.0, 1.0]:
		var olho := _malha_esfera(0.012 * h, Color("1d1712"))
		olho.position = Vector3(lado * cabeca * 0.18, cabeca * 0.58, cabeca * 0.4)
		cabeca_pivo.add_child(olho)
	if String(paleta.get("chapeu", "")) != "":
		var aba := _malha_cilindro(cabeca * 0.62, cabeca * 0.62, 0.012 * h, _cor("chapeu"))
		aba.position = Vector3(0, cabeca * 0.86, 0)
		cabeca_pivo.add_child(aba)
		var copa := _malha_cilindro(cabeca * 0.36, cabeca * 0.4, cabeca * 0.42, _cor("chapeu"))
		copa.position = Vector3(0, cabeca * 0.86 + cabeca * 0.21, 0)
		cabeca_pivo.add_child(copa)
	elif String(paleta.get("lenco", "")) != "":
		var lenco := _malha_esfera(cabeca * 0.52, _cor("lenco"))
		lenco.position = Vector3(0, cabeca * 0.58, -cabeca * 0.02)
		lenco.scale = Vector3(0.94, 0.78, 0.94)
		cabeca_pivo.add_child(lenco)
	else:
		var cabelo := _malha_esfera(cabeca * 0.5, _cor("cabelo"))
		cabelo.position = Vector3(0, cabeca * 0.56, -cabeca * 0.05)
		cabelo.scale = Vector3(0.94, 0.72, 0.9)
		cabeca_pivo.add_child(cabelo)

	for lado in [-1.0, 1.0]:
		var sufixo := "E" if lado < 0.0 else "D"
		var ombro := _pivo("Ombro" + sufixo, quadril, Vector3(lado * (ombro_x + 0.03 * h), _tronco - 0.02 * h, 0))
		var braco := _malha_capsula(0.032 * h, 0.16 * h, _cor("camisa"))
		braco.position = Vector3(0, -0.08 * h, 0)
		ombro.add_child(braco)
		var cotovelo := _pivo("Cotovelo" + sufixo, ombro, Vector3(0, -0.16 * h, 0))
		var antebraco := _malha_capsula(0.028 * h, 0.15 * h, _cor("pele"))
		antebraco.position = Vector3(0, -0.075 * h, 0)
		cotovelo.add_child(antebraco)
		var mao := _malha_esfera(0.03 * h, _cor("pele"))
		mao.position = Vector3(0, -0.16 * h, 0)
		cotovelo.add_child(mao)
		var coxa_pivo := _pivo("Coxa" + sufixo, self, Vector3(lado * 0.06 * h, _perna, 0))
		var coxa_malha := _malha_capsula(0.045 * h, coxa, _cor("pele") if saia else _cor("calca"))
		coxa_malha.position = Vector3(0, -coxa * 0.5, 0)
		coxa_pivo.add_child(coxa_malha)
		var joelho := _pivo("Joelho" + sufixo, coxa_pivo, Vector3(0, -coxa, 0))
		var canela_malha := _malha_capsula(0.038 * h, canela, _cor("pele") if saia else _cor("calca"))
		canela_malha.position = Vector3(0, -canela * 0.5, 0)
		joelho.add_child(canela_malha)
		var pe_cor := _cor("pes") if String(paleta.get("pes", "")) != "" else _cor("pele")
		var pe_malha := _malha_caixa(Vector3(0.07 * h, pe, 0.13 * h), pe_cor)
		pe_malha.position = Vector3(0, -canela - pe * 0.5, 0.03 * h)
		joelho.add_child(pe_malha)
	update_motion(0.0, 0.0)


func update_motion(speed: float, delta: float) -> void:
	if not _construido:
		return
	_velocidade = speed
	_clock += delta
	var moving := clampf(speed / 1.0, 0.0, 1.0)
	var smoothing := 1.0 - exp(-10.0 * delta)
	_blend = lerpf(_blend, moving, smoothing)
	_run_blend = lerpf(_run_blend, clampf((speed - 3.0) / 3.0, 0.0, 1.0), smoothing)
	_phase += delta * lerpf(8.0, 12.5, _run_blend) * minf(speed / 2.4, 1.0)
	var stride := sin(_phase) * _blend
	var leg_angle := lerpf(0.5, 0.78, _run_blend)
	var arm_angle := lerpf(0.36, 0.62, _run_blend)
	var knee_angle := lerpf(0.7, 1.1, _run_blend)
	var breath := sin(_clock * 2.1) * (1.0 - _blend * 0.7)
	var quadril: Node3D = _pivos["Quadril"]
	quadril.position.y = _perna + absf(sin(_phase * 2.0)) * 0.025 * _blend + breath * 0.004
	quadril.rotation.x = _run_blend * 0.16 + _blend * 0.04
	quadril.rotation.z = -stride * 0.04
	quadril.rotation.y = -stride * 0.06
	if _golpe_tempo >= 0.0:
		_golpe_tempo += delta * VELOCIDADE_GOLPE
		_aplicar_golpe()
		if not _golpe_impacto_emitido and _golpe_tempo >= DURACAO_GOLPE * 0.5:
			_golpe_impacto_emitido = true
			golpe_impacto.emit()
		if _golpe_tempo >= DURACAO_GOLPE:
			golpe_concluido.emit()
			if _golpes_restantes > 1:
				_golpes_restantes -= 1
				_golpe_tempo = 0.0
				_golpe_impacto_emitido = false
			else:
				_golpes_restantes = 0
				_golpe_tempo = -1.0
		return
	_pivos["CoxaE"].rotation.x = stride * leg_angle
	_pivos["CoxaD"].rotation.x = -stride * leg_angle
	_pivos["JoelhoE"].rotation.x = knee_angle * maxf(0.0, sin(_phase - 1.2)) * _blend
	_pivos["JoelhoD"].rotation.x = knee_angle * maxf(0.0, sin(_phase + PI - 1.2)) * _blend
	var gesto_ativo := _gesto >= 0 and speed < 0.25
	if _gesto >= 0 and speed >= 0.25:
		_gesto = -1
	if gesto_ativo:
		_gesto_tempo += delta
		_aplicar_gesto(delta)
		if _gesto_tempo >= DURACAO_GESTO:
			_gesto = -1
		return
	_pivos["OmbroE"].rotation = Vector3(-stride * arm_angle, 0.0, -0.16)
	_pivos["OmbroD"].rotation = Vector3(stride * arm_angle, 0.0, 0.16)
	_pivos["CotoveloE"].rotation.x = -0.35 - _run_blend * 0.9 - maxf(0.0, -stride) * 0.4
	_pivos["CotoveloD"].rotation.x = -0.35 - _run_blend * 0.9 - maxf(0.0, stride) * 0.4
	_pivos["Pescoco"].rotation = Vector3(_run_blend * 0.12, 0.0, 0.0)
	_pivos["Cabeca"].rotation = Vector3(0.0, sin(_clock * 0.7) * 0.18 * (1.0 - _blend), 0.0)


func _aplicar_gesto(_delta: float) -> void:
	var t := _gesto_tempo
	var onda := sin(t * 9.0)
	var subir := smoothstep(0.0, 0.35, t) * (1.0 - smoothstep(DURACAO_GESTO - 0.5, DURACAO_GESTO, t))
	var ombro_e: Node3D = _pivos["OmbroE"]
	var ombro_d: Node3D = _pivos["OmbroD"]
	var cotovelo_e: Node3D = _pivos["CotoveloE"]
	var cotovelo_d: Node3D = _pivos["CotoveloD"]
	var cabeca: Node3D = _pivos["Cabeca"]
	var quadril: Node3D = _pivos["Quadril"]
	ombro_e.rotation = Vector3(0.0, 0.0, -0.16)
	cotovelo_e.rotation.x = -0.35
	cabeca.rotation = Vector3.ZERO
	quadril.rotation.x = 0.0
	match _gesto:
		0: # acenar: braço direito alto balançando
			ombro_d.rotation = Vector3(-PI * 0.85 * subir, 0.0, 0.3 + onda * 0.25 * subir)
			cotovelo_d.rotation.x = -0.5 * subir
			cabeca.rotation.z = -0.1 * subir
		1: # concordar
			ombro_d.rotation = Vector3(0.0, 0.0, 0.16)
			cotovelo_d.rotation.x = -0.35
			cabeca.rotation.x = 0.28 * maxf(0.0, sin(t * 6.0)) * subir
		2: # apontar à frente
			ombro_d.rotation = Vector3(-PI * 0.5 * subir, 0.0, 0.05)
			cotovelo_d.rotation.x = -0.05
			cabeca.rotation.y = -0.2 * subir
		3: # coçar a cabeça
			ombro_d.rotation = Vector3(-PI * 0.75 * subir, 0.0, -0.9 * subir)
			cotovelo_d.rotation.x = -2.2 * subir + onda * 0.08
			cabeca.rotation.z = 0.18 * subir
		4: # alongar
			ombro_d.rotation = Vector3(-PI * 0.95 * subir, 0.0, 0.25)
			ombro_e.rotation = Vector3(-PI * 0.95 * subir, 0.0, -0.25)
			cotovelo_d.rotation.x = -0.15
			cotovelo_e.rotation.x = -0.15
			quadril.rotation.x = -0.1 * subir
		5: # chamar: braço na boca
			ombro_d.rotation = Vector3(-PI * 0.45 * subir, 0.3 * subir, -0.4 * subir)
			cotovelo_d.rotation.x = -2.3 * subir
			cabeca.rotation.y = 0.35 * subir
		6: # reverência
			ombro_d.rotation = Vector3(0.6 * subir, 0.0, 0.16)
			cotovelo_d.rotation.x = -1.4 * subir
			quadril.rotation.x = 0.5 * subir
			cabeca.rotation.x = 0.3 * subir
		_: # olhar em volta
			ombro_d.rotation = Vector3(0.0, 0.0, 0.16)
			cotovelo_d.rotation.x = -0.35
			cabeca.rotation.y = sin(t * 2.4) * 0.7 * subir


func play_gesture(index: int) -> String:
	if index < 0 or index >= GESTOS.size():
		return ""
	_golpe_tempo = -1.0
	_golpes_restantes = 0
	_gesto = index
	_gesto_tempo = 0.0
	return GESTOS[index]


func play_chop(repeticoes: int = 2) -> String:
	_gesto = -1
	_golpes_restantes = maxi(repeticoes, 1)
	_golpe_tempo = 0.0
	_golpe_impacto_emitido = false
	return "Golpear"


func gesture_ativa() -> bool:
	return _golpe_tempo >= 0.0 or _gesto >= 0


func chop_ativo() -> bool:
	return _golpe_tempo >= 0.0


func stop_chop() -> void:
	_golpes_restantes = 0
	_golpe_tempo = -1.0
	_golpe_impacto_emitido = false


func _aplicar_golpe() -> void:
	var preparar := smoothstep(0.0, 0.42, _golpe_tempo) * (1.0 - smoothstep(0.42, 0.68, _golpe_tempo))
	var impacto := smoothstep(0.42, 0.68, _golpe_tempo) * (1.0 - smoothstep(0.88, DURACAO_GOLPE, _golpe_tempo))
	_pivos["OmbroD"].rotation = Vector3(-1.7 * preparar + 0.95 * impacto, 0.0, -0.22)
	_pivos["CotoveloD"].rotation.x = -0.9 * preparar - 0.35 * impacto
	_pivos["OmbroE"].rotation = Vector3(0.0, 0.0, -0.16)
	_pivos["CotoveloE"].rotation.x = -0.35
	_pivos["Quadril"].rotation.x = -0.12 * impacto


func get_animation_names() -> PackedStringArray:
	return PackedStringArray(GESTOS)


func get_current_animation() -> StringName:
	if _golpe_tempo >= 0.0:
		return &"golpear"
	if _gesto >= 0:
		return StringName(GESTOS[_gesto])
	if _velocidade > 3.4:
		return &"correr"
	if _velocidade > 0.25:
		return &"andar"
	return &"parado"


func _pivo(nome: String, pai: Node, posicao: Vector3) -> Node3D:
	var pivo := Node3D.new()
	pivo.name = nome
	pivo.position = posicao
	pai.add_child(pivo)
	_pivos[nome] = pivo
	return pivo


func _cor(chave: String) -> Color:
	var valor := String(paleta.get(chave, ""))
	return Color(valor) if valor != "" else Color("8d5a3b")


func _material(cor: Color) -> StandardMaterial3D:
	if _materiais.has(cor):
		return _materiais[cor]
	var material := StandardMaterial3D.new()
	material.albedo_color = cor
	material.roughness = 0.85
	_materiais[cor] = material
	return material


func _instancia(mesh: Mesh, cor: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _material(cor)
	return instance


func _malha_caixa(size: Vector3, cor: Color) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	return _instancia(box, cor)


func _malha_esfera(raio: float, cor: Color) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = raio
	sphere.height = raio * 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	return _instancia(sphere, cor)


func _malha_capsula(raio: float, comprimento: float, cor: Color) -> MeshInstance3D:
	var capsule := CapsuleMesh.new()
	capsule.radius = raio
	capsule.height = maxf(comprimento, raio * 2.0)
	capsule.radial_segments = 10
	capsule.rings = 4
	return _instancia(capsule, cor)


func _malha_cilindro(raio_topo: float, raio_base: float, comprimento: float, cor: Color) -> MeshInstance3D:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = raio_topo
	cylinder.bottom_radius = raio_base
	cylinder.height = comprimento
	cylinder.radial_segments = 12
	cylinder.rings = 1
	return _instancia(cylinder, cor)
