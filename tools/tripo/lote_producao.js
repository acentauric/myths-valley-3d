// Produção em lote no Tripo Studio, do prompt ao GLB baixado. Complemento de lote_studio.js.
// Cole lote_studio.js e depois este arquivo no console da aba logada do Studio (ou injete pela
// ponte do Playwright MCP); espere a página fazer uma chamada autenticada (abrir o Espaço 3D
// basta) e chame:
//   __mv.produzirLote(ITENS, 10)   // ITENS = [{key, prompt, faces, tex, tpose, rig, presets}]
//   __mv.producao()                // andamento de cada item
// Cada item passa por: geração (Modelo HD H3.1, 55 créditos) → retopologia Malha Smart em quads
// (40) → [rig (20) + uma animação por vez] → exportação GLB → download para a pasta Downloads.
// `rig`: 'nenhum' (padrão), 'auto' (o Studio decide bípede/quadrúpede pelo pre_rig_check) ou
// 'biped'/'quadruped'. `presets`: lista de presets; vazio usa os do tipo de rig.
// O estado fica em localStorage (mv-producao): rodar de novo continua de onde parou e nunca
// gera duas vezes o mesmo item. A aba precisa ficar visível (o Chrome segura downloads de
// abas escondidas). Não imprime nem guarda token: usa os cabeçalhos da própria página.
(function () {
  const mv = window.__mv;
  if (!mv || !mv.api) throw new Error('cole lote_studio.js antes deste arquivo');
  mv.prod = JSON.parse(localStorage.getItem('mv-producao') || '{}');
  mv.salvarProd = () => localStorage.setItem('mv-producao', JSON.stringify(mv.prod));
  mv.PRESETS = {
    biped: ['preset:biped:idle', 'preset:biped:walk', 'preset:biped:run', 'preset:biped:greet_01', 'preset:biped:agree', 'preset:biped:look_around'],
    quadruped: ['preset:quadruped:walk'],
    // Do cliente do Studio (chunk BANs6Mft.js): aquático e serpente só têm `march`; ave, nada.
    aquatic: ['preset:aquatic:march'],
    serpentine: ['preset:serpentine:march'],
    avian: [],
  };
  // O pre_rig_check é só um conselho: a beata de saia longa e xale veio "riggable: false" e
  // o rig Mixamo forçado saiu bom, com os seis clipes. Com o tipo dito no item, rigamos
  // assim mesmo; no 'auto', a recusa deixa o modelo parado (o jogo anima por código).
  mv.rigar = async (pid, tipo) => {
    const c = await mv.api('operation/pre_rig_check', { model_version: 'v3.0-20260909', project_id: pid });
    const explicito = tipo && tipo !== 'auto';
    if (c.code !== 0 || (!c.data.riggable && !explicito)) throw new Error('não rigável ' + JSON.stringify(c).slice(0, 160));
    const rigType = explicito ? tipo : (c.data.rig_type || 'biped');
    const j = await mv.api('operation/rigging_model', { model_version: 'v3.0-20260909', project_id: pid, rig_type: rigType, spec: rigType === 'biped' ? 'mixamo' : 'tripo' });
    if (j.code !== 0) throw new Error('rig ' + rigType + ' ' + JSON.stringify(j).slice(0, 160));
    return { op: j.data.operation_id, rigType };
  };
  mv.reanimar = async (pid, preset, rigType) => {
    const j = await mv.api('operation/retarget_model', { animations: [preset], model_version: 'default', project_id: pid, rig_type: rigType });
    if (j.code !== 0) throw new Error('retarget ' + preset + ' ' + JSON.stringify(j).slice(0, 160));
    return j.data.operation_id;
  };
  // Saldo de verdade da conta (a soma das carteiras). O cabeçalho do Studio só se atualiza ao
  // recarregar a página. O extrato fica em wm-billing/records?limit=100&offset=N.
  mv.saldo = async () => {
    const j = await mv.api('wm-billing/wallet', undefined, 'GET');
    return ((j.data && j.data.types) || []).reduce((a, t) => a + (t.balance || 0), 0);
  };
  mv.produzir = async (item) => {
    const st = (mv.prod[item.key] = mv.prod[item.key] || {});
    // Piso de créditos: geração sem saldo para a retopologia vira um HD de milhões de faces
    // que o jogo não usa — melhor nem começar.
    if (!st.pid) {
      const precisa = 95 + (item.rig && item.rig !== 'nenhum' ? 20 : 0);
      const tem = await mv.saldo().catch(() => 0);
      if (tem < precisa) { st.erro = 'sem créditos (' + tem + ' < ' + precisa + ')'; st.passo = 'parado'; mv.salvarProd(); return st; }
    }
    const passo = (nome) => { st.passo = nome; st.em = Date.now(); mv.salvarProd(); };
    try {
      if (!st.pid) {
        passo('gerando');
        const d = await mv.gerar(item.prompt, !!item.tpose);
        st.task = d.task_id; st.pid = d.project_id; mv.salvarProd();
      }
      if (!st.gerado) { await mv.waitOp(st.task, 'gerar ' + item.key, 1800000); st.gerado = true; passo('gerado'); }
      if (!st.remeshDone) {
        if (!st.remeshId) { st.remeshId = await mv.remesh(st.pid, item.faces || 3000); passo('retopologia'); }
        await mv.waitOp(st.remeshId, 'remesh ' + item.key, 1800000); st.remeshDone = true; passo('retopologia ok');
      }
      let rig = item.rig && item.rig !== 'nenhum' && !st.rigFalhou;
      if (rig && !st.rigDone) {
        // Sem rig possível (bicho que o Studio não sabe rigar), o modelo segue parado: o jogo
        // anima por código. Nunca se perde o asset por causa do rig.
        try {
          if (!st.rigOp) { const r = await mv.rigar(st.pid, item.rig); st.rigOp = r.op; st.rigType = r.rigType; passo('rig ' + r.rigType); }
          await mv.waitOp(st.rigOp, 'rig ' + item.key, 1200000); st.rigDone = true; passo('rig ok');
        } catch (e) { st.rigFalhou = String(e).slice(0, 160); rig = false; mv.salvarProd(); }
      }
      if (rig) {
        st.anims = st.anims || {};
        const presets = (item.presets && item.presets.length) ? item.presets : (mv.PRESETS[st.rigType] || []);
        for (const p of presets) {
          if (st.anims[p] === 'ok' || st.anims[p] === 'falhou') continue;
          try { passo('animando ' + p); await mv.waitOp(await mv.reanimar(st.pid, p, st.rigType), 'retarget ' + p, 1200000); st.anims[p] = 'ok'; }
          catch (e) { st.anims[p] = 'falhou'; st.animErro = String(e).slice(0, 160); }
          mv.salvarProd();
        }
      }
      if (!st.exportId) {
        passo('exportando');
        if (rig) {
          const det = (await mv.api('project/detail/v3/' + st.pid + '?locale=pt-BR', undefined, 'GET')).data;
          const ids = ((det.operator && det.operator.retarget) || []).filter((r) => r.status === 'success').map((r) => r.id);
          const j = await mv.api('operation/export', { animate_in_place: true, animations: ids, bake_animation_frame: 0, enable_bake_animation: false, export_orientation: '-y', export_vertex_colors: false, fbx_preset: 'blender', format: 'gltf', model_version: 'default', name: item.key + '_tripo', pack_uv: false, project_id: st.pid, texture_packaging: 'zip', texture_size: item.tex || 1024, with_animation: ids.length > 0 });
          if (j.code !== 0) throw new Error('export ' + JSON.stringify(j).slice(0, 200));
          st.exportId = j.data.operation_id;
        } else {
          st.exportId = await mv.exportar(st.pid, item.key + '_tripo', item.tex || 1024);
        }
        mv.salvarProd();
      }
      if (!st.exportDone) { await mv.waitOp(st.exportId, 'export ' + item.key, 900000); st.exportDone = true; passo('exportado'); }
      if (!st.baixado) { await mv.download(st.exportId, item.key + '_tripo'); st.baixado = true; passo('baixado'); }
      st.erro = null; mv.salvarProd();
    } catch (e) { st.erro = String(e).slice(0, 240); st.erroEm = Date.now(); mv.salvarProd(); }
    return st;
  };
  // Rig forçado num item que já saiu parado (rigFalhou): rig, os presets do tipo e uma
  // exportação nova com os clipes, baixada como <chave>_tripo (n).glb.
  mv.forcarRig = async (key, tipo = 'biped') => {
    const st = mv.prod[key];
    try {
      const j = await mv.api('operation/rigging_model', { model_version: 'v3.0-20260909', project_id: st.pid, rig_type: tipo, spec: tipo === 'biped' ? 'mixamo' : 'tripo' });
      if (j.code !== 0) throw new Error('rig ' + JSON.stringify(j).slice(0, 200));
      await mv.waitOp(j.data.operation_id, 'rig ' + key, 1200000);
      st.rigDone = true; st.rigType = tipo; delete st.rigFalhou; st.anims = {};
      delete st.exportId; st.exportDone = false; st.baixado = false; mv.salvarProd();
      return await mv.produzir({ key, rig: tipo, tex: 1024 });
    } catch (e) { st.forcarErro = String(e).slice(0, 300); mv.salvarProd(); return st; }
  };
  // Vários lotes podem correr juntos (um de modelos novos e outro de retopologia, por
  // exemplo): o fim de um não para o outro. `mv.parado = true` para todos depois do item
  // em curso. Dois itens do MESMO projeto não podem ir no mesmo lote (a retopologia e a
  // exportação de um pegariam a malha do outro): faça um lote depois do outro.
  mv.produzirLote = async (itens, paralelo = 8) => {
    mv.parado = false; mv.lotesAtivos = (mv.lotesAtivos || 0) + 1;
    const fila = itens.slice(); const trabalhadores = [];
    for (let w = 0; w < paralelo; w++) trabalhadores.push((async () => { while (fila.length && !mv.parado) { await mv.produzir(fila.shift()); await mv.sleep(800); } })());
    await Promise.all(trabalhadores); mv.lotesAtivos--; return 'produção fim';
  };
  // Item de um projeto que já existe (retopologia de uma árvore pronta, versão leve ou de
  // longe): {key, pid, faces, tex}. Pula a geração e segue da retopologia em diante.
  mv.reaproveitar = (itens) => { for (const it of itens) { const st = (mv.prod[it.key] = mv.prod[it.key] || {}); if (!st.pid) { st.pid = it.pid; st.gerado = true; } } mv.salvarProd(); return itens; };
  // URLs assinadas e novas dos GLBs já exportados, para baixar fora do navegador quando o Chrome
  // segura o download (aba escondida ou janela minimizada). Salve com o `filename` do
  // browser_evaluate e baixe com tools/tripo/baixar_links.py; a URL não aparece no console.
  mv.links = async () => {
    const out = {};
    for (const [k, v] of Object.entries(mv.prod)) {
      if (!v.exportDone) continue;
      const j = await mv.api('operation/download_with_name', { file_name: k + '_tripo', operator_id: v.exportId });
      if (j.code === 0 && j.data && j.data.model_url) out[k] = j.data.model_url;
    }
    return out;
  };
  mv.producao = () => Object.fromEntries(Object.entries(mv.prod).map(([k, v]) => [k, (v.baixado ? 'OK' : (v.passo || '-')) + (v.erro ? ' ERRO: ' + v.erro.slice(0, 100) : '') + (v.rigFalhou ? ' (sem rig: ' + v.rigFalhou.slice(0, 60) + ')' : '') + (v.animErro ? ' (anim: ' + v.animErro.slice(0, 60) + ')' : '')]));
  console.log('__mv.produzirLote pronto');
})();
