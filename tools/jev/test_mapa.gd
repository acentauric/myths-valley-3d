extends "res://tools/jev/sessao.gd"
## #159: mapa pausa o corpo mas permite Escape, nunca esperar para sempre.
func _initialize() -> void:
    _conferir_mapa.call_deferred()
func _no_vale() -> bool:
    return true
func _conferir_mapa() -> void:
    var opcoes := _acoes({"screen": "world_map"})
    var ok := opcoes.size() == 1 and opcoes.has("close_screen")
    if not ok:
        push_error("AUTOPLAYER_MAPA: o mapa deve oferecer somente Escape")
    print("AUTOPLAYER_MAPA: %d falha(s)" % (0 if ok else 1))
    quit(0 if ok else 1)
