#!/usr/bin/env node
"use strict";
// O DOCUMENTO DAS FALAS (08/10/2026): "um documento estruturando todas as falas dos
// personagens, tanto as de diálogo quando cruza com o personagem como as de missões, com as
// colunas que julgar necessárias para etiquetá-las. O objetivo é tê-las estruturadas para
// validar e como referência para a geração de áudio."
//
//     node tools/falas/gerar_documento_das_falas.js            # refaz docs/falas/FALAS.xlsx e .csv
//     node tools/falas/gerar_documento_das_falas.js --despejo saida.txt   # e um texto corrido, na ordem
//     node tools/falas/gerar_documento_das_falas.js --marcar-revisadas    # dá as falas de hoje por revisadas
//
// Lê as falas de onde o jogo as lê (nada é copiado à mão):
//   data/npcs_3d.json            saudações e conversas dos 23 falantes (o Pedro e os 22 moradores)
//   data/missoes_*.json          anúncio de cada passo, resposta do E, arremate, aviso de fila trancada,
//                                e os blocos de cena da fazenda (cap. 6) e do revoar (cap. 7)
//   data/dialogos/pedro.json     a travessia (narração da abertura); o resto é do 2D e não toca
//   data/dialogos/aldeoes.json   do 2D: no 3D só o gosto de presente é lido — as falas não tocam
//   data/marcos_fe.json          a narração da visita aos marcos (a missão da fé)
//   data/casa.json               a narração do desmaio
//   data/documentos.json         os papéis que o jogador lê (sem voz)
//   scripts/prototipo_3d/lapides.gd   as broncas do Damião (no código, com voz)
//
// Quem diz cada bloco de cena, e quando cada fila abre, está no código (fazenda_vale.gd,
// revoar_vale.gd, prototype.gd): as tabelas CENAS e FILAS abaixo os transcrevem. Mudou o
// código, mude a tabela.
//
// A ANÁLISE (coerência com a história e com a mecânica, problema, correção, prioridade,
// observação, status) mora em docs/falas/analise_das_falas.json, por ID de fala, e este
// script a junta. O ID é estável enquanto a fala não muda de lugar no arquivo; o "hash" do
// texto diz quando a fala mudou depois da revisão ("revisar: o texto mudou").

const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const { escreverXlsx, Estilos } = require("./xlsx_simples.js");

const RAIZ = path.resolve(__dirname, "..", "..");
const PASTA = path.join(RAIZ, "docs", "falas");
const ARQ_ANALISE = path.join(PASTA, "analise_das_falas.json");
const ARGS = process.argv.slice(2);
const MARCAR = ARGS.includes("--marcar-revisadas");
const I_DESPEJO = ARGS.indexOf("--despejo");
const DESPEJO = I_DESPEJO >= 0 ? ARGS[I_DESPEJO + 1] : "";

const ler = (rel) => JSON.parse(fs.readFileSync(path.join(RAIZ, rel), "utf8"));
const lerTexto = (rel) => fs.readFileSync(path.join(RAIZ, rel), "utf8");
const existe = (rel) => fs.existsSync(path.join(RAIZ, rel));
const s = (v) => (v === undefined || v === null ? "" : String(v));
const semAcento = (t) => s(t).normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase();
const hash = (t) => crypto.createHash("sha1").update(s(t).trim(), "utf8").digest("hex").slice(0, 10);

// --- o que o jogo sabe ------------------------------------------------------------------

const NOMES_DOS_ITENS = (() => {
  const t = lerTexto("scripts/compartilhado/catalogo.gd");
  const re = /"([a-z_0-9]+)":\s*\{\s*\n?\s*"nome":\s*"([^"]+)"/g;
  const m = {};
  let x;
  while ((x = re.exec(t))) m[x[1]] = x[2];
  return m;
})();
const nomeDoItem = (id) => NOMES_DOS_ITENS[id] || id;

const RECEITAS = (() => {
  const t = lerTexto("scripts/compartilhado/oficina.gd");
  const re = /\n\t"([a-z_0-9]+)":\s*\{\n([\s\S]*?)\n\t\}/g;
  const r = {};
  let x;
  while ((x = re.exec(t))) {
    const custo = {};
    const c = /"custo":\s*\{([^}]*)\}/.exec(x[2]);
    if (c) for (const par of c[1].matchAll(/"([a-z_0-9]+)":\s*(\d+)/g)) custo[par[1]] = Number(par[2]);
    const rende = /"rende":\s*(\d+)/.exec(x[2]);
    r[x[1]] = { custo, rende: rende ? Number(rende[1]) : 1 };
  }
  return r;
})();

const OBRAS = (() => {
  const r = {};
  const andar = (o) => {
    if (!o || typeof o !== "object") return;
    for (const [k, v] of Object.entries(o)) {
      if (v && typeof v === "object" && !Array.isArray(v) && v.custo && typeof v.custo === "object") r[k] = v.custo;
      andar(v);
    }
  };
  andar(ler("data/construcoes/obras.json"));
  return r;
})();

const TECLAS = (() => {
  const t = lerTexto("scripts/prototipo_3d/atalhos.gd");
  const m = {};
  for (const x of t.matchAll(/"([a-z_]+)":\s*\{"rotulo":\s*"([^"]+)",\s*"padrao":\s*KEY_([A-Z0-9]+)\}/g)) m[x[3]] = x[2];
  Object.assign(m, { SHIFT: "Correr", ESPACO: "Pular", TAB: "Trocar de aba", ESC: "Fechar / pausa", WASD: "Andar", SETAS: "Andar", "1-0": "Barra de mão" });
  return m;
})();

// --- quem fala ----------------------------------------------------------------------------

const NPCS = ler("data/npcs_3d.json");
const FALANTES = {};
function falante(id, nome, voz, oficio) {
  FALANTES[id] = { id, nome, voz: voz || null, oficio: oficio || "" };
}
falante("pedro", NPCS.guia.nome, NPCS.guia.voz, "pescador, o guia da chegada");
for (const m of NPCS.moradores) falante(m.id, m.nome, m.voz, m.oficio || "");
falante("narrador", "Narrador (voz do mundo)", null, "a narração do enredo");
falante("voce", "(sem nome: o que o jogador vê e sente)", null, "narração em segunda pessoa");
falante("documento", "(papel lido)", null, "documento");
// AS VOZES DA FÉ não são moradores: o marco maior de cada fé fala a fila dela
// (prototype._pendurar_as_filas_da_fe; Fe.FES[fe].marcos[0] → MarcosDaFe.NOMES_DOS_MARCOS).
falante("fe_catolica", "Voz do Cruzeiro", null, "a fé católica");
falante("fe_candomble", "Voz do Terreiro", null, "o candomblé");
falante("fe_caboclo", "Voz da Gameleira", null, "a fé do caboclo");
for (const [arq, chaves] of [["fazenda", ["anfitria", "moca"]], ["revoar", ["velha", "moca", "ancia"]]]) {
  const j = ler(`data/missoes_${arq}.json`);
  for (const k of chaves) falante(`${arq}_${k}`, s((j[k] || {}).nome) || k, null, `personagem da cena (${arq})`);
}
const nomeDe = (id) => (FALANTES[id] ? FALANTES[id].nome : id);
const textoDaVoz = (voz) => (voz ? `${s(voz.nome)} · ${s(voz.id)}${voz.modelo ? " · " + voz.modelo : ""}` : "");

// --- a linha do tempo ----------------------------------------------------------------------

const FASES = {
  abertura: [0, "0 · Abertura"],
  chegada: [1, "1 · A chegada (o tutorial)"],
  arraial: [2, "2 · Depois da chegada: o arraial"],
  fe: [3, "3 · A fé"],
  fazenda: [4, "4 · Capítulo 6 — O convite"],
  revoar: [5, "5 · Capítulo 7 — O revoar das asas negras"],
  favores: [6, "6 · Favores dos moradores"],
  sempre: [7, "7 · A qualquer hora"],
  dois_d: [8, "8 · Herdadas do 2D (não tocam no 3D)"],
};

// Quando cada fila abre: prototype.gd (_pendurar_cadeia, depois_de, comecar) e
// data/favores_dos_moradores.json. A ordem é a da história, não a dos arquivos.
const FILAS = {
  guia: ["chegada", 10, "Partida nova: no píer, ao descer do saveiro. A aproximação do Pedro a abre."],
  roca: ["chegada", 20, "Na chegada, depois do passo 'roca' (a primeira leira). E no Cosme."],
  ponte: ["arraial", 10, "Acabada a chegada e dita a despedida. Abre sozinha com o Pedro por perto."],
  filo: ["arraial", 20, "Depois da chegada. E na Dona Filó."],
  zefa: ["arraial", 21, "Depois da chegada. E na Dona Zefa."],
  candinha: ["arraial", 22, "Depois da chegada. E na Dona Candinha."],
  saveiro: ["arraial", 23, "Depois da chegada. E no Seu Benedito."],
  armas: ["arraial", 24, "Depois da chegada. E no Pedro."],
  oficio: ["arraial", 25, "Depois da chegada. E no Pedro."],
  coveiro: ["arraial", 26, "Depois da chegada e do machado do avô (passo 'buscar_machado' da ponte). E no Damião."],
  tonho: ["arraial", 27, "Depois da chegada e do machado do avô (passo 'buscar_machado' da ponte). E no Tonho."],
  lombada: ["arraial", 28, "Depois da lenha da ponte (passo 'ponte_lenha'). E no Pedro."],
  carroca: ["arraial", 29, "Depois da piaçava do saveiro e do machado do avô. E no Seu Benedito."],
  chapada: ["arraial", 30, "Depois da chegada e da primeira colheita da roça. E no Pedro."],
  quintal: ["arraial", 31, "Abre sozinha na sexta colheita (o segundo tutorial)."],
  arraial: ["arraial", 32, "Depois da ponte de pé. E no Pedro."],
  metas: ["arraial", 33, "Abre sozinha ao abater os caititus da meta; fecha no E no Pedro."],
  metas_onca: ["arraial", 34, "Abre sozinha ao abater a onça da meta; fecha levando o couro à Dona Zefa."],
  fe: ["fe", 10, "Depois do mirante. E no Pedro."],
  fe_catolica: ["fe", 20, "Ao entrar na fé católica; só anda enquanto ela é a fé do jogador."],
  fe_candomble: ["fe", 21, "Ao entrar no candomblé; só anda enquanto ele é a fé do jogador."],
  fe_caboclo: ["fe", 22, "Ao entrar na fé do caboclo; só anda enquanto ela é a fé do jogador."],
  capoeira: ["fe", 30, "No candomblé, com a mesa da folha cumprida. E no Cosme."],
  fazenda: ["fazenda", 10, "No dia do convite: a manhã depois da fé escolhida, com a ponte de pé."],
  revoar: ["revoar", 10, "Quando a porta estreita da fazenda se fecha atrás do Pedro."],
};
const MARCOS = ler("data/marcos_fe.json");
const GRAUS = { 1: "Conhecido de vista", 2: "Gente boa", 3: "Amigo", 4: "Compadre" };
const FAVORES = ler("data/favores_dos_moradores.json").filas || [];

// Quem diz cada bloco de cena e quando (fazenda_vale.gd, revoar_vale.gd), pelo passo que a cena fecha.
// [bloco, quem, momento: "antes" do passo | "ao fechar" o passo, nota]
const CENAS = {
  fazenda: {
    fazenda_ida: [["chamado", "pedro", "antes", "no dia do convite, com o jogador perto: o Pedro chama para a fazenda"],
      ["ida_fim", "pedro", "ao fechar", "no portão"], ["narracao", "narrador", "ao fechar", "o portão se abre"]],
    fazenda_chegada: [["chegada_fim", "pedro", "ao fechar", "no pátio, os avós dele"]],
    fazenda_chamado: [["silencio", "narrador", "ao fechar", ""], ["chamado_aos_corajosos", "fazenda_anfitria", "ao fechar", ""],
      ["de_pe", "narrador", "ao fechar", ""], ["pedro_vai", "pedro", "ao fechar", ""]],
    fazenda_porta_estreita: [["subida", "narrador", "ao fechar", ""], ["desafio", "fazenda_moca", "ao fechar", ""],
      ["cerco", "narrador", "ao fechar", ""], ["so_um", "fazenda_anfitria", "ao fechar", ""],
      ["porta", "narrador", "ao fechar", ""], ["pedro_fica", "pedro", "ao fechar", ""]],
  },
  revoar: {
    revoar_quarto: [["quarto", "narrador", "ao fechar", ""], ["trocas", "revoar_velha", "ao fechar", "três trocas; cada uma é oferta e pergunta"],
      ["aceite", "narrador", "ao fechar", "a cada troca aceita, até a segunda"], ["chao", "narrador", "ao fechar", "na terceira troca aceita"],
      ["recusa", "narrador", "ao fechar", "na primeira recusa"], ["miragens", "narrador", "ao fechar", ""]],
    revoar_mao: [["fuga", "narrador", "ao fechar", ""], ["perdao", "revoar_moca", "ao fechar", ""], ["revoar", "narrador", "ao fechar", ""]],
    revoar_abrigo: [["noite", "narrador", "ao fechar", ""], ["relato", "revoar_ancia", "ao fechar", ""],
      ["senhor", "narrador", "ao fechar", ""], ["pedro_torre", "pedro", "ao fechar", ""]],
    revoar_chamado: [["chamado", "narrador", "ao fechar", ""], ["pedro_embate", "pedro", "ao fechar", ""]],
    revoar_embate: [["pedra", "narrador", "ao fechar", ""]],
    revoar_libertacao: [["pedido", "revoar_ancia", "antes", "o E na anciã, depois da fera"], ["pergunta_escudo", "revoar_ancia", "antes", "a escolha do capítulo"],
      ["amanhecer", "narrador", "ao fechar", "se deixou o escudo"], ["amanhecer_levado", "narrador", "ao fechar", "se levou o escudo"]],
  },
};

// --- as linhas -----------------------------------------------------------------------------

const linhas = [];
function nova(r) {
  const fase = FASES[r.fase] || FASES.sempre;
  linhas.push(Object.assign({
    id: "", fase: fase[1], _faseN: fase[0], _chave: [], quando: "", personagem_id: "", tipo: "", gatilho: "",
    missao: "", passo: "", resumo: "", meta: "", recompensa: "", lugar: "", cena: "",
    pt: "", en: "", es: "", zh: "", audio: "", tts: "", em_uso: "sim", fonte: "", voz_especial: "", _carga: null, _carga_textos: [],
  }, r, { fase: fase[1], _faseN: fase[0] }));
}

function campo(o, k) {
  return { pt: s(o[k]), en: s(o[k + "_en"]), es: s(o[k + "_es"]), zh: s(o[k + "_zh"]) };
}

function lista(carga) {
  return Object.entries(carga || {}).map(([k, v]) => `${nomeDoItem(k).toLowerCase()} ×${v}`).join(", ");
}

function cargaDaMeta(m) {
  if (m.itens) return Object.assign({}, m.itens);
  if (m.item) return { [m.item]: Number(m.quantos || 1) };
  // O PASSO QUE JUNTA O MATERIAL DE UMA OBRA (`da_obra`): a conta é o custo dela.
  if (m.da_obra && OBRAS[m.da_obra]) return Object.assign({}, OBRAS[m.da_obra]);
  return {};
}

// A conta de lenha do passo que aceita o que já virou tábua e corda (CadeiaDeMissoes._tem_para_a_meta).
function contaComEquivalencia(m) {
  const carga = cargaDaMeta(m);
  if (!m.equivale || !m.item) return carga;
  let total = 0;
  for (const [peca, quantas] of Object.entries(m.equivale)) {
    const r = RECEITAS[peca];
    if (!r) continue;
    total += Math.ceil(Number(quantas) / Math.max(1, r.rende)) * Number(r.custo[m.item] || 0);
  }
  return { [m.item]: total };
}

function eventosDaMeta(m) {
  return m.eventos ? m.eventos.join(", ") : s(m.evento);
}

function descreverMeta(p) {
  const m = p.meta || {};
  const t = s(m.tipo);
  const carga = cargaDaMeta(m);
  switch (t) {
    case "": return "visita: chegar ao lugar";
    case "juntar": {
      const conta = contaComEquivalencia(m);
      return `juntar: ${lista(carga) || lista(conta)}${m.equivale ? ` — vale o que já virou ${lista(m.equivale)} (conta ${lista(conta)})` : ""}${m.da_obra ? ` (o material da obra '${s(m.da_obra)}')` : ""}`;
    }
    case "levar": return `levar a ${nomeDe(m.a_quem)}: ${lista(carga)}`;
    case "falar": return `falar com ${nomeDe(m.a_quem)} (E)`;
    case "derrubar": return `derrubar: ${s(m.alvo)} ×${m.quantos || 1}`;
    case "obra": return `obra '${s(m.obra)}' em ${s(m.construcao)} (custo ${lista(OBRAS[m.obra]) || "?"})`;
    case "evento": return `evento: ${eventosDaMeta(m)}`;
    case "contar": return `contar: ${s(m.evento)} ×${m.quantos || 1}`;
    case "visitar": return `visitar: ${(m.lugares || []).join(", ")}${m.horas ? ` (das ${m.horas[0]}h às ${m.horas[1]}h)` : ""}`;
    case "oferendar": return `oferendar em ${s(m.lugar || p.lugar)}: ${lista(carga)}`;
    default: return `${t}: ${JSON.stringify(m).slice(0, 80)}`;
  }
}

function descreverRecompensa(r) {
  if (!r) return "";
  return Object.entries(r).map(([k, v]) => k === "reis" ? `${v} réis` : k === "xp" ? `${v} XP` : `${nomeDoItem(k).toLowerCase()} ×${v}`).join(", ");
}

// A carga que o texto do passo tem de bater: o que a meta pede, e o custo da obra.
function cargaParaConferir(p) {
  const m = p.meta || {};
  if (m.tipo === "obra") return Object.assign({}, OBRAS[m.obra] || {});
  if (m.tipo === "derrubar") return { [s(m.alvo)]: Number(m.quantos || 1) };
  if (["juntar", "levar", "oferendar"].includes(m.tipo)) return contaComEquivalencia(m);
  if (m.tipo === "contar") return { [s(m.evento)]: Number(m.quantos || 1) };
  return null;
}

// 1. A ABERTURA.
const P2D = ler("data/dialogos/pedro.json");
(P2D.travessia || []).forEach((t, i) => nova({
  id: `abertura.travessia.${i + 1}`, fase: "abertura", _chave: [0, 0, 0, i],
  quando: "Partida nova, antes do vale: a tela da travessia.", personagem_id: "narrador", tipo: "Narração da abertura",
  gatilho: "A tela da travessia, uma legenda por trecho de voz", pt: t, en: s((P2D.travessia_en || [])[i]), es: s((P2D.travessia_es || [])[i]),
  audio: `res://assets/audio/narracao/travessia/trecho_${String(i + 1).padStart(2, "0")}.mp3`,
  voz_especial: "BDM · Nelson Silvestre · eleven_v3 (tools/elevenlabs/gerar-travessia.ps1)",
  fonte: `data/dialogos/pedro.json › travessia[${i}]`,
}));

// 2. O PRIMEIRO ENCONTRO COM O PEDRO.
(NPCS.guia.falas || []).forEach((f, i) => nova(Object.assign({
  id: `npc.pedro.falas.${i + 1}`, fase: "chegada", _chave: [5, 0, 0, i],
  quando: "Só no primeiro encontro, no píer, antes de a chegada começar.", personagem_id: "pedro", tipo: "Saudação do primeiro encontro",
  gatilho: "Chegar perto do Pedro no píer (balão curto; a fala inteira no aviso)", audio: s(f.audio), tts: s(f.tts),
  fonte: `data/npcs_3d.json › guia.falas[${i}]`,
}, campo(f, "texto"))));

// 3. AS FILAS DE MISSÃO.
const ARQUIVOS_DAS_FILAS = fs.readdirSync(path.join(RAIZ, "data")).filter((f) => /^missoes_.*\.json$/.test(f)).sort();
const RESUMO_DAS_FILAS = [];
for (const arquivo of ARQUIVOS_DAS_FILAS) {
  const chave = arquivo.replace(/^missoes_/, "").replace(/\.json$/, "");
  const j = ler(`data/${arquivo}`);
  let [fase, ordem, quando] = FILAS[chave] || [];
  if (!fase) {
    const favor = FAVORES.find((f) => s(f.arquivo).endsWith(arquivo));
    if (favor) {
      fase = "favores";
      ordem = 10 + FAVORES.indexOf(favor);
      const antes = favor.depois ? FAVORES.find((f) => f.chave === favor.depois) : null;
      const nomeDoAntes = antes ? s(ler(s(antes.arquivo).replace("res://", "")).nome) : "";
      quando = `Depois da chegada, com afinidade ${GRAUS[favor.grau] || favor.grau} (grau ${favor.grau}) com ${nomeDe(favor.dono)}${antes ? `, e depois de "${nomeDoAntes}"` : ""}. E em ${nomeDe(favor.dono)}.`;
    } else {
      fase = "sempre";
      ordem = 99;
      quando = "(a fila não está na tabela FILAS do gerador: conferir em prototype.gd)";
    }
  }
  const dono = s(j.dono);
  const nomeDaMissao = s(j.nome);
  const fN = FASES[fase][0];
  const total = (j.passos || []).length;
  RESUMO_DAS_FILAS.push({ chave, arquivo, fase: FASES[fase][1], _ordem: [fN, ordem], nome: nomeDaMissao, dono, principal: !!j.principal, passos: total, quando });
  const base = { fase, quando, missao: nomeDaMissao };
  if (j.trancada) nova(Object.assign({}, base, campo(j, "trancada"), {
    id: `missao.${chave}.trancada`, _chave: [ordem, -1, 0, 0], personagem_id: dono, tipo: "Aviso de fila trancada",
    gatilho: "E no dono enquanto a fila espera o que ela pede", fonte: `data/${arquivo} › trancada`,
  }));
  (j.passos || []).forEach((p, k) => {
    const meta = p.meta || {};
    const comum = Object.assign({}, base, {
      passo: `${k + 1}/${total} · ${s(p.id)}`, resumo: s(p.resumo), meta: descreverMeta(p),
      recompensa: descreverRecompensa(p.recompensa), lugar: s(p.lugar), cena: s(p.cena), _carga: cargaParaConferir(p),
    });
    const blocos = ((CENAS[chave] || {})[p.id] || []);
    blocos.filter((b) => b[2] === "antes").forEach((b, ib) => blocoDeCena(j, arquivo, chave, comum, b, [ordem, k, -1, ib]));
    if (p.texto) nova(Object.assign({}, comum, campo(p, "texto"), {
      id: `missao.${chave}.${p.id}.anuncio`, _chave: [ordem, k, 0, 0], personagem_id: dono, tipo: "Anúncio do passo",
      gatilho: "Ao anunciar o passo (na vez dele, na fila de falas); o E no dono o repete", audio: s(p.audio), tts: s(p.tts),
      fonte: `data/${arquivo} › passos[${k}] ${p.id} › texto`, _carga_textos: ["pt", "resumo"],
    }));
    if (meta.resposta) {
      const quem = s(meta.a_quem) || dono;
      nova(Object.assign({}, comum, campo(meta, "resposta"), {
        id: `missao.${chave}.${p.id}.resposta`, _chave: [ordem, k, 1, 0], personagem_id: quem, tipo: "Resposta do passo (E)",
        gatilho: meta.tipo === "levar" ? `E em ${nomeDe(quem)} com a carga na mochila` : meta.tipo === "oferendar" ? `E no lugar da oferenda, com a oferta na mochila` : `E em ${nomeDe(quem)}`,
        fonte: `data/${arquivo} › passos[${k}] ${p.id} › meta.resposta`, _carga_textos: ["pt"],
      }));
    }
    blocos.filter((b) => b[2] !== "antes").forEach((b, ib) => blocoDeCena(j, arquivo, chave, comum, b, [ordem, k, 2, ib]));
    extrasDoPasso(chave, j, arquivo, p, k, comum, [ordem, k]);
  });
  if (j.arremate && j.arremate.texto) {
    const narra = j.arremate.narra !== false;
    nova(Object.assign({}, base, campo(j.arremate, "texto"), {
      id: `missao.${chave}.arremate`, _chave: [ordem, 999, 0, 0], personagem_id: dono,
      tipo: narra ? "Arremate da missão" : "Nota de fim (não falada)",
      gatilho: narra ? "Fechado o último passo, o dono diz (na vez dele)" : "Fica no objetivo do HUD ao fim; a última resposta é a fala",
      audio: s(j.arremate.audio), tts: s(j.arremate.tts), em_uso: narra ? "sim" : "sim (texto do HUD, sem voz)",
      fonte: `data/${arquivo} › arremate`,
    }));
  }
}

function blocoDeCena(j, arquivo, chave, comum, bloco, ordem) {
  const [nomeDoBloco, quem, momento, nota] = bloco;
  const quando = `${comum.quando} Cena ${momento === "antes" ? "durante" : "ao fechar"} o passo${nota ? ` (${nota})` : ""}.`;
  const tipoDeQuem = quem === "narrador" ? "Narração de cena (texto, sem voz)" : "Fala de cena";
  const dado = j[nomeDoBloco];
  if (nomeDoBloco === "trocas") {
    (dado || []).forEach((t, i) => {
      nova(Object.assign({}, comum, campo(t, "oferta"), { id: `missao.${chave}.cena.trocas.${i + 1}.oferta`, _chave: ordem.concat([i * 2]), quando,
        personagem_id: quem, tipo: "Fala de cena", gatilho: "Caixa de fala da cena, com o vale parado", fonte: `data/${arquivo} › trocas[${i}].oferta` }));
      nova(Object.assign({}, comum, campo(t, "pergunta"), { id: `missao.${chave}.cena.trocas.${i + 1}.pergunta`, _chave: ordem.concat([i * 2 + 1]), quando,
        personagem_id: quem, tipo: "Pergunta de cena (escolha do jogador)", gatilho: "Caixa de pergunta (Sim / Não)", fonte: `data/${arquivo} › trocas[${i}].pergunta` }));
    });
    return;
  }
  if (dado && !Array.isArray(dado) && typeof dado === "object") {
    nova(Object.assign({}, comum, campo(dado, "texto"), { id: `missao.${chave}.cena.${nomeDoBloco}`, _chave: ordem.concat([0]), quando,
      personagem_id: quem, tipo: "Pergunta de cena (escolha do jogador)", gatilho: "Caixa de pergunta (Sim / Não)", fonte: `data/${arquivo} › ${nomeDoBloco}` }));
    return;
  }
  (dado || []).forEach((f, i) => nova(Object.assign({}, comum, campo(f, "texto"), {
    id: `missao.${chave}.cena.${nomeDoBloco}.${i + 1}`, _chave: ordem.concat([i]), quando, personagem_id: quem, tipo: tipoDeQuem,
    gatilho: quem === "narrador" ? "A narração do vale (o escuro sobe, uma frase de cada vez)" : "Caixa de fala da cena, com o vale parado",
    audio: s(f.audio), tts: s(f.tts), fonte: `data/${arquivo} › ${nomeDoBloco}[${i}]`,
  })));
}

function extrasDoPasso(chave, j, arquivo, p, k, comum, ordem) {
  // O CORPO, explicado pelo Pedro na condução da chegada, a primeira vez que o vigor baixa.
  if (chave === "guia" && p.id === "correr") {
    (j.corpo || []).forEach((c, i) => nova(Object.assign({}, comum, campo(c, "texto"), {
      id: `missao.guia.corpo.${i + 1}`, _chave: ordem.concat([5, i]), personagem_id: "pedro", tipo: "Explicação do corpo",
      quando: `${comum.quando} Na condução com o Pedro, a primeira vez que o vigor fica baixo${c.quando ? ` (${c.quando === "cansado" ? "se já cansou na caminhada" : "se não cansou"})` : ""}.`,
      gatilho: "Caixa de fala, uma vez por partida (vai no save)", audio: s(c.audio), tts: s(c.tts), fonte: `data/${arquivo} › corpo[${i}]`,
      passo: "", resumo: "", meta: "", recompensa: "", _carga: null,
    })));
  }
  // O ANOITECER: no tutorial, ao entardecer, uma vez por dia (guia_pedro._verificar_anoitecer).
  if (chave === "guia" && p.id === "mutirao_poco" && NPCS.guia.anoitecer) {
    nova(Object.assign({}, comum, campo(NPCS.guia.anoitecer, "texto"), {
      id: "npc.pedro.anoitecer", _chave: ordem.concat([5, 0]), personagem_id: "pedro", tipo: "Aviso do anoitecer",
      quando: "Durante o tutorial, ao entardecer, uma vez por dia.", gatilho: "Balão e aviso, na vez dele",
      audio: s(NPCS.guia.anoitecer.audio), tts: s(NPCS.guia.anoitecer.tts), fonte: "data/npcs_3d.json › guia.anoitecer",
      passo: "", resumo: "", meta: "", recompensa: "", _carga: null,
    }));
  }
  // O SOCORRO: sem fôlego no meio da lenha da ponte, a mungunzá da avó (prototype._conferir_o_socorro).
  if (chave === "ponte" && p.id === "ponte_lenha") {
    (j.socorro || []).forEach((f, i) => nova(Object.assign({}, comum, campo(f, "texto"), {
      id: `missao.ponte.socorro.${i + 1}`, _chave: ordem.concat([5, i]), personagem_id: "pedro", tipo: "Socorro (sem fôlego)",
      quando: `${comum.quando} Sem fôlego e sem comida no meio da lenha ou das tábuas da ponte, uma vez.`,
      gatilho: "Caixa de fala; seis cuias de mungunzá na mochila", audio: s(f.audio), tts: s(f.tts), fonte: `data/${arquivo} › socorro[${i}]`,
      _carga: null,
    })));
  }
  // A VISITA AOS MARCOS, narrada quando a fila da fé registra a chegada a cada um.
  if (chave === "fe" && (p.meta || {}).tipo === "visitar") {
    for (const marco of (p.meta.lugares || [])) {
      const v = (MARCOS.visita || {})[marco];
      if (!v) continue;
      (v.linhas || []).forEach((t, i) => nova(Object.assign({}, comum, {
        id: `fe.visita.${marco}.${i + 1}`, _chave: ordem.concat([5, (p.meta.lugares.indexOf(marco)) * 10 + i]), personagem_id: "voce",
        tipo: "Narração da visita (sem voz)", quando: `${comum.quando} Ao chegar ao marco '${marco}' neste passo.`,
        gatilho: "Caixa de fala sem nome", pt: t, en: s((v.linhas_en || [])[i]), es: s((v.linhas_es || [])[i]), zh: "",
        fonte: `data/marcos_fe.json › visita.${marco}.linhas[${i}]`, _carga: null,
      })));
    }
  }
}

// 4. A QUALQUER HORA: as conversas, as saudações, a bronca do Damião, o desmaio, os papéis.
(NPCS.guia.falas_depois || []).forEach((f, i) => nova(Object.assign({
  id: `npc.pedro.falas_depois.${i + 1}`, fase: "sempre", _chave: [0, 0, 0, i],
  quando: "Desde que a chegada começou: no E sem passo a repetir; depois do tutorial, é a conversa dele.",
  personagem_id: "pedro", tipo: "Conversa (E)", gatilho: "E no Pedro (alterna a cada conversa)", audio: s(f.audio), tts: s(f.tts),
  fonte: `data/npcs_3d.json › guia.falas_depois[${i}]`,
}, campo(f, "texto"))));
NPCS.moradores.forEach((m, im) => {
  const temSaudacoes = (m.saudacoes || []).length > 0;
  const grupos = [
    ["saudacoes", "Saudação (aproximação)", "Desde o primeiro encontro, a qualquer hora.", "Chegar perto (o balão inteiro; a fala no aviso)"],
    ["saudacoes_noite", "Saudação da noite", "À noite (das 18h48 à meia-noite), somada às de sempre.", "Chegar perto, de noite"],
    ["falas", temSaudacoes ? "Conversa (E)" : "Conversa (E) e cumprimento", "Desde o primeiro encontro, a qualquer hora.",
      temSaudacoes ? "E no morador (alterna a cada conversa)" : "E no morador; e, sem saudações próprias, também ao chegar perto (balão curto)"],
    ["falas_noite", "Conversa da noite (E)", "À noite (das 18h48 à meia-noite), somada às de sempre.", "E no morador, de noite"],
  ];
  grupos.forEach(([chave, tipo, quando, gatilho], ig) => (m[chave] || []).forEach((f, i) => nova(Object.assign({
    id: `npc.${m.id}.${chave}.${i + 1}`, fase: "sempre", _chave: [1 + im, ig, 0, i], quando, personagem_id: m.id, tipo, gatilho,
    audio: s(f.audio), tts: s(f.tts), fonte: `data/npcs_3d.json › moradores[${im}] ${m.id} › ${chave}[${i}]`,
  }, campo(f, "texto")))));
});
(() => {
  const t = lerTexto("scripts/prototipo_3d/lapides.gd");
  const re = /\["([^"]+)",\s*"(res:\/\/assets\/audio\/vozes\/damiao_bronca_\d+\.mp3)"\]/g;
  let x;
  let i = 0;
  while ((x = re.exec(t))) {
    i += 1;
    nova({ id: `lapides.bronca.${i}`, fase: "sempre", _chave: [90, 0, 0, i], quando: "Quando o jogador sobe num túmulo com o Damião por perto (1 → 2 → 3; a 3 se repete).",
      personagem_id: "damiao", tipo: "Bronca (subir no túmulo)", gatilho: "Balão, aviso e voz; na terceira ele derruba o jogador da laje",
      pt: x[1], audio: x[2], em_uso: "sim (só em português: o texto está no código)", fonte: `scripts/prototipo_3d/lapides.gd › BRONCAS[${i - 1}]` });
  }
})();
(ler("data/casa.json").desmaio || []).forEach((f, i) => nova(Object.assign({
  id: `casa.desmaio.${i + 1}`, fase: "sempre", _chave: [91, 0, 0, i], quando: "Ao acordar depois de apagar sem fôlego (o desmaio).",
  personagem_id: "voce", tipo: "Narração do desmaio (sem voz)", gatilho: "Caixa de fala sem nome", fonte: `data/casa.json › desmaio[${i}]`,
}, campo(f, "texto"))));
(() => {
  const d = ler("data/documentos.json");
  for (const [id, papel] of Object.entries(d)) {
    if (!papel || typeof papel !== "object" || !Array.isArray(papel.linhas)) continue;
    papel.linhas.forEach((t, i) => nova({
      id: `documento.${id}.${i + 1}`, fase: "sempre", _chave: [92, 0, 0, i], quando: `Ao ler o papel (${s(papel.nome)}) na mochila.`,
      personagem_id: "documento", tipo: "Leitura de documento (sem voz)", gatilho: "Caixa de fala com o nome do papel",
      pt: t, en: s((papel.linhas_en || [])[i]), es: s((papel.linhas_es || [])[i]), em_uso: "sim (texto lido, sem voz)",
      missao: s(papel.nome), fonte: `data/documentos.json › ${id}.linhas[${i}]`,
    }));
  }
})();

// 5. HERDADAS DO 2D: escritas, mas o 3D não as diz.
(() => {
  const a = ler("data/dialogos/aldeoes.json");
  let ia = 0;
  for (const [id, v] of Object.entries(a)) {
    if (!v || typeof v !== "object") continue;
    ia += 1;
    const reacoes = { gostou: "Reação a presente que gosta", nao_gostou: "Reação a presente que não aceita", agradeceu: "Agradece um presente", ja_ganhou: "Já ganhou presente hoje" };
    for (const [k, tipo] of Object.entries(reacoes)) (v[k] || []).forEach((t, i) => nova({
      id: `2d.aldeoes.${id}.${k}.${i + 1}`, fase: "dois_d", _chave: [ia, 0, Object.keys(reacoes).indexOf(k), i], personagem_id: id,
      tipo: `${tipo} (2D)`, quando: "Não toca: no 3D o presente só lê o gosto (gosta / desgosta).", gatilho: "—", pt: t,
      em_uso: "não (herdada do 2D)", fonte: `data/dialogos/aldeoes.json › ${id}.${k}[${i}]`,
    }));
    (v.assuntos || []).forEach((as, ia2) => (as.fala || []).forEach((t, i) => nova({
      id: `2d.aldeoes.${id}.assunto.${s(as.id)}.${i + 1}`, fase: "dois_d", _chave: [ia, 1, ia2, i], personagem_id: id,
      tipo: `Assunto de conversa (2D: ${s(as.id)})`, quando: `Não toca: o 3D não mostra os assuntos (no 2D, 'quando': ${s(as.quando)}).`,
      gatilho: "—", pt: t, em_uso: "não (herdada do 2D)", fonte: `data/dialogos/aldeoes.json › ${id}.assuntos[${ia2}] ${s(as.id)}.fala[${i}]`,
    })));
  }
  const fora = new Set(["observacao", "personagem", "nome_padrao", "travessia", "travessia_en", "travessia_es"]);
  const pular = new Set(["titulo", "objetivo", "observacao", "_sobre", "_sobre_o_vilarejo"]);
  let n = 0;
  const andar = (o, caminho) => {
    if (typeof o === "string") {
      n += 1;
      nova({ id: `2d.pedro.${caminho.replace(/\[(\d+)\]/g, ".$1").replace(/^\./, "")}`, fase: "dois_d", _chave: [99, 0, 0, n], personagem_id: "pedro",
        tipo: "Fala do 2D (Pedro)", quando: "Não toca: no 3D a chegada é a de missoes_guia.json.", gatilho: "—", pt: o,
        em_uso: "não (herdada do 2D)", fonte: `data/dialogos/pedro.json › ${caminho.replace(/^\./, "")}` });
      return;
    }
    if (Array.isArray(o)) { o.forEach((x, i) => andar(x, `${caminho}[${i}]`)); return; }
    if (o && typeof o === "object") for (const [k, v] of Object.entries(o)) if (!pular.has(k)) andar(v, `${caminho}.${k}`);
  };
  for (const [k, v] of Object.entries(P2D)) if (!fora.has(k)) andar(v, `.${k}`);
})();

// --- a ordem e as colunas que se calculam -------------------------------------------------------

function comparar(a, b) {
  if (a._faseN !== b._faseN) return a._faseN - b._faseN;
  const x = a._chave;
  const y = b._chave;
  for (let i = 0; i < Math.max(x.length, y.length); i++) {
    const p = x[i] === undefined ? -Infinity : x[i];
    const q = y[i] === undefined ? -Infinity : y[i];
    if (p !== q) return p < q ? -1 : 1;
  }
  return 0;
}
linhas.sort(comparar);
linhas.forEach((l, i) => { l.ordem = i + 1; });

const AUDIOS_DE_VOZ = fs.readdirSync(path.join(RAIZ, "assets/audio/vozes")).filter((f) => f.endsWith(".mp3")).map((f) => f.replace(/\.mp3$/, ""));
const AUDIOS_USADOS = new Set();
function arquivoDoAudio(chave) {
  if (!chave) return "";
  if (chave.startsWith("res://")) return chave.slice(6);
  return `assets/audio/vozes/${chave}.mp3`;
}

const NUMEROS = {
  dois: 2, duas: 2, tres: 3, quatro: 4, cinco: 5, seis: 6, sete: 7, oito: 8, nove: 9, dez: 10, onze: 11, doze: 12, treze: 13,
  catorze: 14, quatorze: 14, quinze: 15, dezesseis: 16, dezessete: 17, dezoito: 18, dezenove: 19, vinte: 20, trinta: 30,
  quarenta: 40, cinquenta: 50, sessenta: 60, setenta: 70, oitenta: 80, noventa: 90, cem: 100,
};
const DEZENAS = new Set(["vinte", "trinta", "quarenta", "cinquenta", "sessenta", "setenta", "oitenta", "noventa"]);
const SINONIMOS = {
  lenha: ["lenha", "lenhas", "acha", "achas", "pau", "paus", "galho", "galhos"], tabua: ["tabua", "tabuas"], corda: ["corda", "cordas"],
  pedra: ["pedra", "pedras"], cana: ["cana", "canas"], piacava: ["piacava", "piacavas", "feixe", "feixes"], peixe: ["peixe", "peixes"],
  farinha: ["farinha", "cuia", "cuias"], mandioca: ["mandioca", "mandiocas", "raiz", "raizes"], milho: ["milho", "espiga", "espigas"],
  ovo: ["ovo", "ovos"], cha_de_folha: ["cha", "chas"], beiju: ["beiju", "beijus"], cocada: ["cocada", "cocadas"], garapa: ["garapa", "garapas", "copo", "copos"],
  pirao: ["pirao", "piroes"], ostra: ["ostra", "ostras"], banana: ["banana", "bananas", "cacho", "cachos"], manga: ["manga", "mangas"],
  caju: ["caju", "cajus"], lampiao: ["lampiao", "lampioes"], couro_de_onca: ["couro", "couros"], carne_de_caca: ["carne", "carnes", "pedaco", "pedacos"],
  robalo: ["robalo", "robalos"], traira: ["traira", "trairas"], erva_da_serra: ["maco", "macos", "erva", "ervas"],
  madeira_de_coqueiro: ["madeira", "madeiras"], leite: ["leite"], semente_milho: ["grao", "graos"], semente_mandioca: ["maniva", "manivas"],
  rebolo_cana: ["rebolo", "rebolos"], muda_bananeira: ["muda", "mudas"], muda_mangueira: ["muda", "mudas"], muda_cajueiro: ["muda", "mudas"],
  toalha_de_renda: ["toalha", "toalhas"], mungunza: ["cuia", "cuias", "mungunza"], peixe_assado: ["peixe", "peixes"],
  capim: ["capim", "pe", "pes", "touceira", "touceiras"], "derrubou:caititu": ["caititu", "caititus"], esquivou: ["esquiva", "esquivas", "vez", "vezes", "ginga", "gingas"],
};
function quantidadesNoTexto(texto) {
  const tok = semAcento(texto).replace(/[^a-z0-9]+/g, " ").trim().split(/\s+/).filter(Boolean);
  const achadas = [];
  for (let i = 0; i < tok.length; i++) {
    let n = null;
    let fim = i;
    if (/^\d+$/.test(tok[i])) n = Number(tok[i]);
    else if (NUMEROS[tok[i]] !== undefined) {
      n = NUMEROS[tok[i]];
      if (DEZENAS.has(tok[i]) && tok[i + 1] === "e" && NUMEROS[tok[i + 2]] !== undefined && NUMEROS[tok[i + 2]] < 10) { n += NUMEROS[tok[i + 2]]; fim = i + 2; }
    }
    if (n === null) continue;
    for (let k = fim + 1; k <= fim + 3 && k < tok.length; k++) {
      const item = Object.keys(SINONIMOS).find((id) => SINONIMOS[id].includes(tok[k]));
      if (item) { achadas.push({ item, n }); break; }
    }
    i = fim;
  }
  return achadas;
}

function teclasCitadas(texto) {
  const t = s(texto);
  const achadas = new Set();
  for (const x of t.matchAll(/[\[(]\s*([A-Z0-9]|Shift|Tab|Esc|Espaço)\s*[\])]/g)) achadas.add(x[1].toUpperCase().replace("ESPAÇO", "ESPACO"));
  for (const x of t.matchAll(/\b(?:o|no|pelo|do|aperte|aperta|apertar|aperte o|toque|toca|toca o|toque o|segure|segura|tecla|com o|e o)\s+([A-Z])(?=[\s,.;:!?)]|$)/g)) achadas.add(x[1]);
  if (/\bShift\b/.test(t)) achadas.add("SHIFT");
  if (/\bTab\b/.test(t)) achadas.add("TAB");
  if (/\bEsc\b/.test(t)) achadas.add("ESC");
  if (/barra de espa[çc]o|\bEspa[çc]o\b/.test(t)) achadas.add("ESPACO");
  if (/\bWASD\b|W, A, S e D/.test(t)) achadas.add("WASD");
  if (/\bsetas\b/.test(t)) achadas.add("SETAS");
  return [...achadas];
}

const HORAS = /\b(bom dia|boa tarde|boa noite|de manh[ãa]zinha|hoje cedo|nesta manh[ãa]|esta manh[ãa]|essa manh[ãa]|de madrugada|esta noite|hoje de noite|hoje [àa] noite|ao meio-dia)\b/i;
const RECEM = /(chegou o da capital|chegou, home|acabou de chegar|rec[ée]m-chegad|o moço da capital|moço novo|gente nova|é você o|sobrinho do finado|seja bem-vind|bem-vindo ao arraial|primeira vez que)/i;

const ANALISE = fs.existsSync(ARQ_ANALISE) ? JSON.parse(fs.readFileSync(ARQ_ANALISE, "utf8")) : { falas: {}, revisadas: {}, personagens: {}, missoes: {} };
ANALISE.falas = ANALISE.falas || {};
ANALISE.revisadas = ANALISE.revisadas || {};

const PORTEXTO = new Map();
for (const l of linhas) {
  if (!l.pt.trim()) continue;
  const k = semAcento(l.pt).replace(/\s+/g, " ").trim();
  if (!PORTEXTO.has(k)) PORTEXTO.set(k, []);
  PORTEXTO.get(k).push(l.id);
}

for (const l of linhas) {
  const f = FALANTES[l.personagem_id];
  l.personagem = f ? f.nome : l.personagem_id;
  l.letras = l.pt.length;
  l.duracao = l.pt ? Math.max(1.5, Math.round((l.pt.length / 14) * 10) / 10) : "";
  const emUso = !l.em_uso.startsWith("não");
  const falada = emUso && !/sem voz|não falada|^Narração de cena/.test(l.tipo) && !/sem voz/.test(l.em_uso);
  l.voz = l.voz_especial || (f && f.voz ? textoDaVoz(f.voz) : (falada ? "(sem voz definida)" : "—"));
  l.audio_arq = arquivoDoAudio(l.audio);
  if (l.audio_arq.startsWith("assets/audio/vozes/")) AUDIOS_USADOS.add(path.basename(l.audio_arq, ".mp3"));
  l.audio_existe = l.audio_arq ? (existe(l.audio_arq) ? "sim" : "não") : (falada ? "sem áudio" : "—");
  const alertas = [];
  // O TTS e o texto.
  if (l.tts) {
    const a = semAcento(l.tts.replace(/\[[^\]]*\]/g, " ")).replace(/[^a-z0-9]+/g, " ").trim();
    const b = semAcento(l.pt).replace(/[^a-z0-9]+/g, " ").trim();
    if (a === b) l.tts_confere = "sim";
    else {
      const pa = a.split(" ");
      const pb = b.split(" ");
      let i = 0;
      while (i < pa.length && pa[i] === pb[i]) i++;
      l.tts_confere = `não: a partir de "${pb.slice(i, i + 4).join(" ")}" (TTS: "${pa.slice(i, i + 4).join(" ")}")`;
      if (l.audio_existe === "sim") alertas.push("o áudio gravado pode não bater com o texto de hoje (o TTS difere do texto)");
    }
  } else l.tts_confere = l.audio_arq ? "(sem texto de TTS guardado)" : "—";
  if (l.audio_existe === "não") alertas.push("áudio declarado e não gravado");
  if (falada && l.voz === "(sem voz definida)" && l.personagem_id !== "narrador") alertas.push("quem fala não tem voz definida (npcs_3d.json)");
  // As traduções.
  if (emUso && l.pt && !l.fonte.startsWith("scripts/")) {
    const faltam = [];
    if (!l.en) faltam.push("en");
    if (!l.es) faltam.push("es");
    const iguais = [];
    if (l.en && l.pt.length > 15 && l.en === l.pt) iguais.push("en");
    if (l.es && l.pt.length > 15 && l.es === l.pt) iguais.push("es");
    l.traducoes = faltam.length ? `falta ${faltam.join(" e ")}` : iguais.length ? `${iguais.join(" e ")} igual ao português` : "completas";
    if (faltam.length || iguais.length) alertas.push(`tradução: ${l.traducoes}`);
  } else l.traducoes = l.fonte.startsWith("scripts/") ? "só português (no código)" : emUso ? "—" : "só português (2D)";
  // As teclas.
  const teclas = teclasCitadas(l.pt);
  l.teclas = teclas.map((t) => `${t} (${TECLAS[t] || "fora da tabela de atalhos"})`).join(", ");
  for (const t of teclas) if (!TECLAS[t] && emUso) alertas.push(`cita a tecla ${t}, que não está na tabela de atalhos`);
  // As quantidades contra a meta.
  if (l._carga && emUso) {
    for (const campoDoTexto of (l._carga_textos.length ? l._carga_textos : ["pt"])) {
      for (const { item, n } of quantidadesNoTexto(l[campoDoTexto])) {
        if (l._carga[item] !== undefined && Number(l._carga[item]) !== n) alertas.push(`${campoDoTexto === "resumo" ? "o objetivo do HUD" : "o texto"} fala em ${n} ${item}, e a mecânica pede ${l._carga[item]}`);
      }
    }
  }
  // A hora do dia e o recém-chegado nas falas que tocam o jogo todo.
  if (emUso && /^(Saudação|Conversa)/.test(l.tipo)) {
    const hora = HORAS.exec(l.pt);
    if (hora && !/noite/.test(l.tipo)) alertas.push(`cita a hora do dia ("${hora[1]}"), e a fala toca a qualquer hora`);
    if (hora && /noite/.test(l.tipo) && /bom dia|boa tarde|manh/i.test(hora[1])) alertas.push(`fala da noite que diz "${hora[1]}"`);
    if (RECEM.test(l.pt) && l.tipo !== "Saudação do primeiro encontro") alertas.push("fala de quem acabou de chegar, e ela toca o jogo todo");
    if (/^Saudação/.test(l.tipo) && l.tipo !== "Saudação do primeiro encontro" && l.pt.length > 60) alertas.push(`saudação de ${l.pt.length} letras (o balão inteiro é até 60)`);
    if (/^Conversa/.test(l.tipo) && l.pt.length > 160) alertas.push(`conversa de ${l.pt.length} letras (o teto das conversas é 140)`);
  }
  if (/\{[a-z_]+\}|%[sd]/.test(l.pt)) alertas.push("tem marcador que o jogo troca ({…} ou %s): áudio fixo não serve");
  const iguais = (PORTEXTO.get(semAcento(l.pt).replace(/\s+/g, " ").trim()) || []).filter((x) => x !== l.id);
  // DO 2D: o texto igual a uma fala herdada diz de onde ela veio (não é problema); igual a outra
  // fala que toca é repetição.
  const do2d = iguais.filter((x) => x.startsWith("2d."));
  l.origem = s(l.em_uso).startsWith("não") ? "2D" : do2d.length ? `igual ao 2D (${do2d[0]})` : "3D";
  const repetidas = iguais.filter((x) => !x.startsWith("2d."));
  if (emUso && repetidas.length) alertas.push(`texto igual ao de ${repetidas.slice(0, 2).join(", ")}`);
  // A análise.
  l._hash = hash(l.pt);
  const a = ANALISE.falas[l.id] || {};
  // O ALERTA JÁ REVISTO (falso positivo, ou visto e aceito): fica na coluna, marcado, e sai da aba
  // dos alertas.
  l._alerta_revisto = !!(a.alerta_revisto && alertas.length);
  l.alertas = l._alerta_revisto ? `(revisto: ${a.alerta_revisto}) ${alertas.join(" | ")}` : alertas.join(" | ");
  const revisada = ANALISE.revisadas[l.id];
  const situacao = revisada === l._hash ? (emUso ? "ok" : "não toca") : revisada ? "revisar (o texto mudou)" : "não revisada";
  l.historia = a.historia || situacao;
  l.mecanica = a.mecanica || situacao;
  l.problema = s(a.problema);
  l.correcao = s(a.correcao);
  l.prioridade = s(a.prioridade);
  l.observacao = s(a.observacao);
  l.status = s(a.status) || (a.problema ? "corrigir" : "pendente");
}

// A análise que aponta para fala que não existe (o ID mudou, ou foi digitado errado).
const IDS = new Set(linhas.map((l) => l.id));
const orfasDaAnalise = Object.keys(ANALISE.falas).filter((id) => !IDS.has(id));
if (orfasDaAnalise.length) console.warn(`a análise cita ${orfasDaAnalise.length} ID(s) que não existem: ${orfasDaAnalise.join(", ")}`);

if (MARCAR) {
  for (const l of linhas) ANALISE.revisadas[l.id] = l._hash;
  fs.writeFileSync(ARQ_ANALISE, JSON.stringify(ANALISE, null, 2) + "\n", "utf8");
  console.log(`marcadas como revisadas: ${linhas.length} falas`);
}

// --- as saídas -------------------------------------------------------------------------

const COLUNAS = [
  ["id", "ID", 30, "ident", false], ["ordem", "Ordem", 7, "ident", false],
  ["fase", "Fase da história", 20, "tempo", true], ["quando", "Quando abre / quando vale", 36, "tempo", true],
  ["personagem", "Personagem", 18, "quem", true], ["personagem_id", "ID do personagem", 13, "quem", false],
  ["tipo", "Tipo de fala", 22, "quem", true], ["gatilho", "Como toca (gatilho)", 30, "quem", true],
  ["missao", "Missão", 22, "contexto", true], ["passo", "Passo", 20, "contexto", true], ["resumo", "Objetivo no HUD", 30, "contexto", true],
  ["meta", "Mecânica do passo", 32, "contexto", true], ["recompensa", "Recompensa do passo", 20, "contexto", true],
  ["lugar", "Lugar", 14, "contexto", false], ["cena", "Cena", 14, "contexto", false],
  ["pt", "Texto (português)", 60, "texto", true], ["en", "Texto (inglês)", 48, "texto", true], ["es", "Texto (espanhol)", 48, "texto", true],
  ["zh", "Texto (chinês)", 26, "texto", true], ["letras", "Letras (pt)", 8, "texto", false], ["duracao", "Duração estimada (s)", 9, "texto", false],
  ["voz", "Voz (ElevenLabs)", 28, "audio", true], ["audio_arq", "Arquivo de áudio", 30, "audio", true], ["audio_existe", "Áudio gravado?", 10, "audio", false],
  ["tts", "Texto para o TTS (com as marcas de emoção)", 48, "audio", true], ["tts_confere", "O TTS confere com o texto?", 18, "audio", true],
  ["traducoes", "Traduções", 14, "checagem", true], ["origem", "Veio do 2D?", 16, "checagem", true], ["teclas", "Teclas citadas", 18, "checagem", true], ["alertas", "Alertas automáticos", 40, "checagem", true],
  ["historia", "Coerência com a história", 13, "analise", true], ["mecanica", "Coerência com a mecânica", 13, "analise", true],
  ["problema", "Problema encontrado", 46, "analise", true], ["correcao", "Correção sugerida", 46, "analise", true],
  ["prioridade", "Prioridade", 10, "analise", false], ["observacao", "Observações", 40, "analise", true],
  ["status", "Status da validação", 13, "validacao", false], ["em_uso", "Em uso no 3D?", 14, "validacao", true],
  ["fonte", "Onde editar (arquivo › caminho)", 42, "validacao", true],
];
const CORES_DOS_GRUPOS = { ident: "37474F", tempo: "1F4E79", quem: "4A3B6B", contexto: "0B5563", texto: "2E5D2B", audio: "7A4A00", checagem: "5A5A5A", analise: "8B1E1E", validacao: "6B5B00" };
const STATUS = ["pendente", "aprovada", "corrigir", "corrigida", "descartar"];

fs.mkdirSync(PASTA, { recursive: true });
const estilos = new Estilos();
const cabecalho = (grupo) => estilos.estilo({ negrito: true, cor: "FFFFFF", fundo: CORES_DOS_GRUPOS[grupo] || "37474F", quebra: true, vertical: "center" });
const CORES_DA_ANALISE = { ok: "D9EAD3", "atenção": "FFF2CC", problema: "F4CCCC" };
function estiloDaCelula(chaveDaColuna, quebra, valor, linhaObj) {
  const op = { quebra };
  const naoToca = linhaObj && s(linhaObj.em_uso).startsWith("não");
  if (naoToca) Object.assign(op, { italico: true, cor: "7F7F7F" });
  const v = s(valor);
  if (chaveDaColuna === "historia" || chaveDaColuna === "mecanica") op.fundo = CORES_DA_ANALISE[v] || (v ? "EDEDED" : undefined);
  if (chaveDaColuna === "prioridade") { if (v === "alta") Object.assign(op, { negrito: true, cor: "B00020" }); if (v === "média") Object.assign(op, { negrito: true, cor: "B45F06" }); if (v === "baixa") op.cor = "38761D"; }
  if (chaveDaColuna === "audio_existe") op.fundo = v === "sim" ? "D9EAD3" : v === "não" ? "F4CCCC" : v === "sem áudio" ? "FCE5CD" : undefined;
  if (chaveDaColuna === "tts_confere" && v.startsWith("não")) op.fundo = "FCE5CD";
  if (chaveDaColuna === "alertas" && v) op.fundo = "FFF2CC";
  if (chaveDaColuna === "status") op.fundo = v === "aprovada" ? "D9EAD3" : v === "corrigir" ? "F4CCCC" : v === "corrigida" ? "CFE2F3" : undefined;
  Object.keys(op).forEach((k) => op[k] === undefined && delete op[k]);
  return estilos.estilo(op);
}

function aba(nome, colunas, objetos, extra = {}) {
  return Object.assign({
    nome,
    colunas: colunas.map(([, titulo, largura, , quebra]) => ({ titulo, largura, quebra })),
    linhas: objetos.map((o) => colunas.map(([k]) => o[k] === undefined ? "" : o[k])),
    estiloDoCabecalho: (i) => cabecalho(colunas[i][3]),
    estiloDaCelula: (iLinha, iCol, valor) => estiloDaCelula(colunas[iCol][0], colunas[iCol][4], valor, objetos[iLinha]),
  }, extra);
}

const iStatus = COLUNAS.findIndex((c) => c[0] === "status");
const abaFalas = aba("Falas", COLUNAS, linhas, { listas: [{ coluna: iStatus, valores: STATUS }] });

const ORDEM_DA_PRIORIDADE = { alta: 0, "média": 1, baixa: 2 };
const comProblema = linhas.filter((l) => l.problema || ["atenção", "problema"].includes(l.historia) || ["atenção", "problema"].includes(l.mecanica))
  .sort((a, b) => (ORDEM_DA_PRIORIDADE[a.prioridade] ?? 3) - (ORDEM_DA_PRIORIDADE[b.prioridade] ?? 3) || a.ordem - b.ordem);
const COLUNAS_PROBLEMAS = [
  ["prioridade", "Prioridade", 10, "analise", false], ["id", "ID", 28, "ident", false], ["ordem", "Ordem", 7, "ident", false],
  ["fase", "Fase", 18, "tempo", true], ["personagem", "Personagem", 16, "quem", true], ["tipo", "Tipo", 18, "quem", true],
  ["missao", "Missão", 18, "contexto", true], ["passo", "Passo", 16, "contexto", true], ["pt", "Texto (português)", 58, "texto", true],
  ["historia", "História", 11, "analise", true], ["mecanica", "Mecânica", 11, "analise", true],
  ["problema", "Problema encontrado", 52, "analise", true], ["correcao", "Correção sugerida", 52, "analise", true],
  ["alertas", "Alertas automáticos", 30, "checagem", true], ["status", "Status", 12, "validacao", false], ["fonte", "Onde editar", 36, "validacao", true],
];
const abaProblemas = aba("Problemas", COLUNAS_PROBLEMAS, comProblema, { listas: [{ coluna: COLUNAS_PROBLEMAS.findIndex((c) => c[0] === "status"), valores: STATUS }] });

const comAlerta = linhas.filter((l) => l.alertas && !l._alerta_revisto && !s(l.em_uso).startsWith("não"));
const COLUNAS_ALERTAS = [
  ["id", "ID", 28, "ident", false], ["ordem", "Ordem", 7, "ident", false], ["personagem", "Personagem", 16, "quem", true],
  ["tipo", "Tipo", 18, "quem", true], ["missao", "Missão", 18, "contexto", true], ["passo", "Passo", 16, "contexto", true],
  ["pt", "Texto (português)", 58, "texto", true], ["alertas", "Alertas automáticos", 60, "checagem", true], ["fonte", "Onde editar", 36, "validacao", true],
];
const abaAlertas = aba("Alertas automáticos", COLUNAS_ALERTAS, comAlerta);

const porPersonagem = new Map();
for (const l of linhas) {
  if (!porPersonagem.has(l.personagem_id)) porPersonagem.set(l.personagem_id, []);
  porPersonagem.get(l.personagem_id).push(l);
}
const personagens = [...porPersonagem.entries()].map(([id, ls]) => {
  const emUso = ls.filter((l) => !s(l.em_uso).startsWith("não"));
  const faladas = emUso.filter((l) => l.audio_existe !== "—");
  const f = FALANTES[id] || {};
  return {
    nome: f.nome || id, id, oficio: f.oficio || "", voz: f.voz ? textoDaVoz(f.voz) : (id === "narrador" ? "BDM · Nelson Silvestre (só a abertura)" : "(sem voz definida)"),
    em_uso: emUso.length, faladas: faladas.length, letras: faladas.reduce((soma, l) => soma + l.letras, 0),
    minutos: Math.round(faladas.reduce((soma, l) => soma + Number(l.duracao || 0), 0) / 6) / 10,
    gravadas: faladas.filter((l) => l.audio_existe === "sim").length, faltando: faladas.filter((l) => l.audio_existe === "não").length,
    sem_audio: faladas.filter((l) => l.audio_existe === "sem áudio").length,
    dois_d: ls.length - emUso.length, problemas: ls.filter((l) => l.problema).length,
    observacao: s(((ANALISE.personagens || {})[id] || {}).observacao),
  };
}).sort((a, b) => b.em_uso - a.em_uso);
const COLUNAS_PERSONAGENS = [
  ["nome", "Personagem", 24, "quem", true], ["id", "ID", 14, "quem", false], ["oficio", "Quem é", 26, "quem", true], ["voz", "Voz (ElevenLabs)", 36, "audio", true],
  ["em_uso", "Falas em uso", 9, "texto", false], ["faladas", "Faladas (pedem voz)", 10, "audio", false], ["letras", "Letras faladas (≈ créditos)", 12, "audio", false],
  ["minutos", "Minutos de voz (estim.)", 10, "audio", false], ["gravadas", "Com áudio gravado", 10, "audio", false],
  ["faltando", "Áudio declarado e faltando", 11, "audio", false], ["sem_audio", "Sem áudio (precisam ser geradas)", 12, "audio", false],
  ["dois_d", "Herdadas do 2D (não tocam)", 11, "validacao", false], ["problemas", "Falas com problema", 10, "analise", false],
  ["observacao", "Observações", 60, "analise", true],
];
const abaPersonagens = aba("Personagens", COLUNAS_PERSONAGENS, personagens);

RESUMO_DAS_FILAS.sort((a, b) => a._ordem[0] - b._ordem[0] || a._ordem[1] - b._ordem[1]);
const missoes = RESUMO_DAS_FILAS.map((m) => {
  const ls = linhas.filter((l) => l.fonte.startsWith(`data/${m.arquivo}`));
  return Object.assign({}, m, {
    dono: nomeDe(m.dono), principal: m.principal ? "enredo" : "secundária", falas: ls.length, letras: ls.reduce((soma, l) => soma + l.letras, 0),
    problemas: ls.filter((l) => l.problema).length, arquivo: `data/${m.arquivo}`, observacao: s(((ANALISE.missoes || {})[m.chave] || {}).observacao),
  });
});
const COLUNAS_MISSOES = [
  ["fase", "Fase", 22, "tempo", true], ["nome", "Missão", 28, "contexto", true], ["dono", "Quem dá", 18, "quem", true],
  ["principal", "Enredo ou secundária", 11, "contexto", false], ["passos", "Passos", 7, "contexto", false], ["quando", "Quando abre", 50, "tempo", true],
  ["falas", "Falas", 7, "texto", false], ["letras", "Letras", 8, "texto", false], ["problemas", "Falas com problema", 9, "analise", false],
  ["observacao", "Observações", 60, "analise", true], ["arquivo", "Arquivo", 34, "validacao", true],
];
const abaMissoes = aba("Missões (linha do tempo)", COLUNAS_MISSOES, missoes);

const orfaos = AUDIOS_DE_VOZ.filter((a) => !AUDIOS_USADOS.has(a)).map((a) => ({ arquivo: `assets/audio/vozes/${a}.mp3`, observacao: "Nenhuma fala do jogo aponta para este arquivo." }));
const abaOrfaos = aba("Áudios sem fala", [["arquivo", "Arquivo", 50, "audio", true], ["observacao", "Observação", 60, "analise", true]], orfaos);

const LEGENDA = [
  ["ID", "Chave estável da fala: de onde ela vem (npc, missao, cena, 2d...) e o lugar dela no arquivo. É por ela que a análise (docs/falas/analise_das_falas.json) se liga à fala."],
  ["Ordem", "A posição na linha do tempo do jogo: abertura, chegada, arraial, fé, capítulos 6 e 7, favores, o que toca a qualquer hora, e o herdado do 2D."],
  ["Fase da história / Quando abre", "Em que ponto da história a fala pode tocar e o que a destrava (do código: prototype.gd e a tabela dos favores)."],
  ["Personagem / Tipo / Como toca", "Quem diz, que tipo de fala é (saudação, conversa, anúncio do passo, resposta do E, arremate, aviso de fila trancada, fala de cena, narração...) e o que a faz tocar."],
  ["Missão / Passo / Objetivo no HUD / Mecânica / Recompensa", "O contexto de mecânica: o passo em curso, o resumo que o HUD mostra, o que o passo pede de fato (itens, quantidades, quem, onde) e o que paga. É com isso que se confere a fala contra a mecânica."],
  ["Textos", "Português, inglês, espanhol e chinês (quando há). Letras e duração estimada (14 letras por segundo) servem ao orçamento de voz."],
  ["Voz / Arquivo / Áudio gravado? / TTS", "A voz do ElevenLabs de quem fala, o arquivo de áudio, se ele existe, o texto que vai ao TTS (com as marcas de emoção) e se ele bate com o texto de hoje. 'sem áudio' = fala que toca sem voz e precisaria ser gerada."],
  ["Alertas automáticos", "O que o gerador acha sozinho: tradução que falta, tecla citada fora da tabela, número no texto que não bate com a mecânica, hora do dia em fala que toca a qualquer hora, fala de recém-chegado que repete o jogo todo, áudio faltando ou desatualizado, marcador que impede áudio fixo, texto repetido."],
  ["Coerência com a história / com a mecânica", "A revisão: ok, atenção, problema; 'não revisada' é fala nova; 'revisar (o texto mudou)' é fala que mudou depois da revisão."],
  ["Problema / Correção / Prioridade / Observações", "O que a revisão encontrou, o que mudar e com que urgência (alta: quebra a história ou ensina errado; média: estranha ao jogador; baixa: polimento)."],
  ["Status da validação", "Para o time: pendente, aprovada, corrigir, corrigida, descartar (lista de escolha)."],
  ["Em uso no 3D?", "sim = toca no jogo; 'sim (texto ..., sem voz)' = aparece, mas sem voz; não = escrita para o 2D e o 3D não diz."],
  ["Onde editar", "O arquivo e o caminho dentro dele. As falas mudam lá — este documento é refeito pelo gerador."],
  ["Como refazer", "node tools/falas/gerar_documento_das_falas.js (refaz FALAS.xlsx e FALAS.csv). A análise fica em docs/falas/analise_das_falas.json."],
  ["O que ficou de fora", "Textos que não são falas: avisos do HUD (recados, dicas), perguntas de sistema (a cama, comer, firmar pacto), os textos dos marcos da fé fora da visita (rito, migrar, trocar), as inscrições das lápides, as cartas achadas e os nomes de itens."],
];
const abaLegenda = aba("Legenda", [["coluna", "Coluna", 34, "ident", true], ["explicacao", "O que é", 110, "ident", true]], LEGENDA.map(([coluna, explicacao]) => ({ coluna, explicacao })), { filtro: false });

const buf = escreverXlsx([abaFalas, abaProblemas, abaAlertas, abaPersonagens, abaMissoes, abaOrfaos, abaLegenda],
  { estilos, titulo: "As falas de Myths' Valley 3D", autor: "tools/falas/gerar_documento_das_falas.js", aplicacao: "Myths' Valley — documento das falas", quando: new Date() });
fs.writeFileSync(path.join(PASTA, "FALAS.xlsx"), buf);

const csv = (v) => { const t = s(v); return /[",\n\r]/.test(t) ? `"${t.replace(/"/g, '""')}"` : t; };
fs.writeFileSync(path.join(PASTA, "FALAS.csv"), "﻿" + [COLUNAS.map((c) => csv(c[1])).join(","), ...linhas.map((l) => COLUNAS.map(([k]) => csv(l[k])).join(","))].join("\n") + "\n", "utf8");

if (DESPEJO) {
  const saida = [];
  for (const l of linhas) {
    if (s(l.em_uso).startsWith("não") && !ARGS.includes("--com-2d")) continue;
    saida.push(`#${l.ordem} [${l.id}] ${l.personagem} · ${l.tipo}${l.missao ? " · " + l.missao : ""}${l.passo ? " · " + l.passo : ""}`);
    if (l.resumo || l.meta) saida.push(`    HUD: ${l.resumo} | MECÂNICA: ${l.meta}${l.recompensa ? " | PAGA: " + l.recompensa : ""}`);
    saida.push(`    » ${l.pt}`);
    if (l.alertas) saida.push(`    ! ${l.alertas}`);
  }
  fs.writeFileSync(DESPEJO, saida.join("\n") + "\n", "utf8");
}

const emUso = linhas.filter((l) => !s(l.em_uso).startsWith("não"));
console.log(`falas: ${linhas.length} (${emUso.length} em uso no 3D, ${linhas.length - emUso.length} herdadas do 2D)`);
console.log(`com alerta automático: ${comAlerta.length}; com problema apontado: ${comProblema.length}; áudios sem fala: ${orfaos.length}`);
console.log(`escrito: docs/falas/FALAS.xlsx e docs/falas/FALAS.csv`);
