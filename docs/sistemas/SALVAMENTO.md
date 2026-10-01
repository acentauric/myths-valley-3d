# Salvamento do vale

O autoload Salvamento serializa os sistemas presentes no vale; Partida
liga a vaga escolhida ao jogo. A abertura oferece três vagas, confirma
antes de recomeçar uma ocupada e permite explorar sem salvar.

O perfil `MythsValleyPrototype3D` foi preservado para manter partidas
existentes. Não renomeie esse diretório sem uma migração explícita de saves.

O portão `tests/salvamento.gd` confere partida nova, restauração e as vagas.
Execute-o pelo runner com perfil temporário. Campo novo de sistema precisa
ter uma decisão explícita sobre persistência e uma verificação do ciclo
salvar/carregar; não basta conferir a escrita do JSON.
