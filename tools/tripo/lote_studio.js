// Lote no Tripo Studio pelo console do navegador (sessão já logada em studio.tripo3d.ai).
// Fluxo por projeto: history → remesh (Malha Smart, quads, alvo de polígonos) → progress →
// export GLB (textura 1K/2K) → progress → download_with_name → download no navegador.
// Usa a mesma sessão e os mesmos endpoints internos que a interface (v2/studio/…), com os
// cabeçalhos que a própria página envia; não imprime nem guarda token nenhum.
// Como usar: abrir qualquer projeto no Studio, colar este arquivo no console, depois
//   __mv.lote(PLANO, 6)  // PLANO = [{key, id, faces, tex}], tex = 1024 ou 2048
//   __mv.resumo()        // acompanhar; o estado fica em localStorage (mv-lote-state)
// A aba precisa ficar visível: o Chrome segura downloads de abas escondidas.
// Retopologia custa 40 créditos por projeto (setembro/2026); exportar é grátis.
(function () {
  const of = window.fetch;
  window.__inits = window.__inits || {};
  window.fetch = async function (input, init) {
    const url = typeof input === 'string' ? input : (input && input.url);
    if (/api\.tripo3d\.ai\/v2\/studio/.test(url) && init && init.headers) {
      window.__inits.last = { headers: init.headers, t: Date.now() };
    }
    return of.apply(this, arguments);
  };
  const mv = (window.__mv = window.__mv || {});
  mv.api = async function (path, body, method = 'POST') {
    const h = window.__inits.last && window.__inits.last.headers;
    if (!h) throw new Error('a página ainda não fez nenhuma chamada autenticada; aguarde alguns segundos');
    const headers = h instanceof Headers ? new Headers(h) : Object.assign({}, h);
    const r = await of('https://api.tripo3d.ai/v2/studio/' + path, {
      method, headers, credentials: 'include', body: body !== undefined ? JSON.stringify(body) : undefined,
    });
    return r.json();
  };
  mv.state = JSON.parse(localStorage.getItem('mv-lote-state') || '{}');
  mv.save = () => localStorage.setItem('mv-lote-state', JSON.stringify(mv.state));
  mv.sleep = (ms) => new Promise((r) => setTimeout(r, ms));
  mv.progress = async (ids) => { const j = await mv.api('progress', { ids }); if (j.code !== 0) throw new Error('progress ' + j.message); return j.data; };
  mv.waitOp = async (id, label, timeoutMs = 1200000) => {
    const t0 = Date.now();
    while (Date.now() - t0 < timeoutMs) {
      const d = await mv.progress([id]); const p = d && d[0];
      if (p && p.status === 'success') return p;
      if (p && /fail|error|cancel/i.test(p.status)) throw new Error(label + ' ' + p.status);
      await mv.sleep(6000);
    }
    throw new Error(label + ' timeout');
  };
  mv.textToModelOp = async (pid) => {
    const j = await mv.api('project/history/' + pid + '?locale=pt-BR', undefined, 'GET');
    const g = ((j.data && j.data.history) || []).filter((x) => x.type === 'text_to_model' || x.type === 'image_to_model');
    if (!g.length) throw new Error('sem geração base em ' + pid);
    return g[g.length - 1].operator_id;
  };
  mv.detail = async (pid) => (await mv.api('project/detail/v3/' + pid + '?locale=pt-BR', undefined, 'GET')).data;
  mv.remesh = async (pid, faces) => {
    const g = await mv.textToModelOp(pid);
    const j = await mv.api('operation/remesh', { bake: true, face_limit: faces, model_version: 'default', part_name_list: ['tripo_node_' + g], project_id: pid, quad: true, smart_poly: true });
    if (j.code !== 0) throw new Error('remesh ' + JSON.stringify(j).slice(0, 200));
    return j.data.operation_id;
  };
  mv.exportar = async (pid, name, tex) => {
    const j = await mv.api('operation/export', { animate_in_place: true, animations: [], bake_animation_frame: 0, enable_bake_animation: false, export_orientation: '-y', export_vertex_colors: false, fbx_preset: 'blender', format: 'gltf', model_version: 'default', name, pack_uv: false, project_id: pid, texture_packaging: 'zip', texture_size: tex, with_animation: false });
    if (j.code !== 0) throw new Error('export ' + JSON.stringify(j).slice(0, 200));
    return j.data.operation_id;
  };
  mv.download = async (opId, name) => {
    const j = await mv.api('operation/download_with_name', { file_name: name, operator_id: opId });
    if (j.code !== 0 || !j.data || !j.data.model_url) throw new Error('download ' + JSON.stringify(j).slice(0, 200));
    const a = document.createElement('a'); a.href = j.data.model_url; a.download = name + '.glb'; a.style.display = 'none';
    document.body.appendChild(a); a.click(); await mv.sleep(1500); a.remove();
    return true;
  };
  mv.processar = async (item) => {
    const st = (mv.state[item.key] = mv.state[item.key] || {});
    try {
      if (!st.remeshDone) {
        if (!st.remeshId) {
          const d = await mv.detail(item.id);
          if (d.operator && d.operator.type === 'remesh' && d.operator.status === 'success') { st.remeshDone = true; st.remeshId = d.operator.operator_id; }
          else if (d.operator && d.operator.type === 'remesh' && d.operator.status === 'running') { st.remeshId = d.operator.operator_id; }
          else { st.remeshId = await mv.remesh(item.id, item.faces); st.remeshAt = Date.now(); }
          mv.save();
        }
        if (!st.remeshDone) { await mv.waitOp(st.remeshId, 'remesh ' + item.key); st.remeshDone = true; mv.save(); }
      }
      if (!st.exportId) { st.exportId = await mv.exportar(item.id, item.key + '_tripo', item.tex); mv.save(); }
      if (!st.exportDone) { await mv.waitOp(st.exportId, 'export ' + item.key, 600000); st.exportDone = true; mv.save(); }
      if (!st.downloaded) { await mv.download(st.exportId, item.key + '_tripo'); st.downloaded = true; st.doneAt = Date.now(); mv.save(); }
      st.error = null;
    } catch (e) { st.error = String(e); st.errorAt = Date.now(); mv.save(); }
    return st;
  };
  mv.lote = async (items, concurrency = 5) => {
    mv.running = true; const queue = items.slice(); const workers = [];
    for (let w = 0; w < concurrency; w++) workers.push((async () => { while (queue.length && mv.running) { await mv.processar(queue.shift()); await mv.sleep(500); } })());
    await Promise.all(workers); mv.running = false; return 'lote fim';
  };
  // Geração texto → 3D (Modelo HD, H3.1, 55 créditos). Devolve {task_id, project_id}.
  mv.gerar = async (prompt, tPose = false) => {
    const j = await mv.api('operation/text_to_model', { face_limit: 2000000, quad: false, visibility: 'shareable', model_version: 'v3.1-20260211', generate_parts: false, smart_poly: false, texture: true, delight: true, pbr: true, texture_alignment: 'original_image', texture_quality: 'detailed', geometry_quality: 'detailed', gen_image_model_version: 'flux.1_dev', prompt, sketch_to_render: false, t_pose: tPose });
    if (j.code !== 0) throw new Error('gerar ' + JSON.stringify(j).slice(0, 200));
    return j.data;
  };
  // Rig humanoide (Mixamo, 20 créditos) e animações prontas do Studio (até 5 por chamada).
  // A exportação com animações ainda é feita pela interface (Exportar → Número de
  // Animações → Selecionar tudo): a chamada direta respondeu erro 1000/1004 em 26/09.
  mv.PRESETS_NPC = ['preset:biped:idle', 'preset:biped:walk', 'preset:biped:run', 'preset:biped:greet_01', 'preset:biped:agree', 'preset:biped:look_around', 'preset:biped:wave_goodbye_02'];
  mv.rig = async (pid) => {
    const c = await mv.api('operation/pre_rig_check', { model_version: 'v3.0-20260909', project_id: pid });
    if (c.code !== 0 || !c.data.riggable) throw new Error('não rigável ' + JSON.stringify(c).slice(0, 160));
    const j = await mv.api('operation/rigging_model', { model_version: 'v3.0-20260909', project_id: pid, rig_type: c.data.rig_type || 'biped', spec: 'mixamo' });
    if (j.code !== 0) throw new Error('rig ' + JSON.stringify(j).slice(0, 160));
    return j.data.operation_id;
  };
  mv.retarget = async (pid, animations) => {
    const j = await mv.api('operation/retarget_model', { animations, model_version: 'default', project_id: pid, rig_type: 'biped' });
    if (j.code !== 0) throw new Error('retarget ' + JSON.stringify(j).slice(0, 160));
    return j.data.operation_id;
  };
  mv.resumo = () => Object.fromEntries(Object.entries(mv.state).map(([k, v]) => [k, (v.downloaded ? 'OK' : v.exportDone ? 'exp-ok' : v.exportId ? 'exportando' : v.remeshDone ? 'remesh-ok' : v.remeshId ? 'remesh...' : '-') + (v.error ? ' ERR:' + v.error.slice(0, 80) : '')]));
  console.log('__mv pronto: __mv.lote(PLANO, 6) / __mv.resumo()');
})();
