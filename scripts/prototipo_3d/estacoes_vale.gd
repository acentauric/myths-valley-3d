extends RefCounted
## Variações discretas do Recôncavo, sem neve nem troca de modelos.
## Materiais compartilhados continuam compartilhados; a cor base nunca deriva.
const MATA := [Color.WHITE, Color(1.04, 0.97, 0.88), Color(1.02, 0.94, 0.86), Color(0.86, 0.96, 0.91)]
const LUZ := [Color.WHITE, Color(1.02, 0.97, 0.90), Color(1.0, 0.95, 0.87), Color(0.89, 0.95, 1.0)]
const AVES := [1.0, 0.90, 0.80, 0.72]
const INSETOS := [1.0, 1.15, 0.80, 0.60]
static var _materiais: Dictionary = {}

static func registrar(material: BaseMaterial3D) -> void:
	if material == null:
		return
	if not material.has_meta("cor_sem_estacao"):
		material.set_meta("cor_sem_estacao", material.albedo_color)
	_materiais[material.get_instance_id()] = weakref(material)
	material.albedo_color = material.get_meta("cor_sem_estacao") * MATA[Relogio.estacao]

static func aplicar(estacao: int) -> void:
	for id in _materiais.keys():
		var material: BaseMaterial3D = _materiais[id].get_ref()
		if material == null:
			_materiais.erase(id)
		else:
			material.albedo_color = material.get_meta("cor_sem_estacao") * MATA[clampi(estacao, 0, 3)]
