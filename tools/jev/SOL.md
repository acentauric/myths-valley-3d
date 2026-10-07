# Jogador automático local

JOGAR_SOL.cmd inicia uma partida nova em perfil isolado e o robô local de robo.py sem limite de tempo. Decide por regras a partir do estado observado e das ações disponíveis, sem esperar respostas do agente externo, ler a configuração TypeSafe ou consumir API do Jev. Encerra ao concluir a história implementada, por F8, ao fechar a janela ou diante de erro de execução.

O objetivo é completar a campanha implementada usando os controles normais, sem teleportar, criar itens ou avançar missões artificialmente. As regras ainda estão em desenvolvimento: a sessão pode encontrar obstáculos que precisam ser tratados; iniciar o robô não garante concluir a campanha.

Veja [Teste automático](../../docs/testes/AUTOPLAYER.md) para o botão do menu,
as prioridades da política e as pausas entre ações de trabalho.

Relatório, decisões e capturas ficam na pasta exibida pelo lançador. Alterações em robo.py são recarregadas entre ações, preservando a partida; mudanças no GDScript e na ponte precisam de nova abertura. Para uma sessão limitada, passe --seconds 600.

O controle manual externo continua disponível com jogar.py --sol --seconds 600. Nesse modo, o agente responde a pending.json usando controle_sol.py; sem resposta em 180 segundos, a sessão encerra.
