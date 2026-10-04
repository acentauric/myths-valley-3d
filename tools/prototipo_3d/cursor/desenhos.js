// Desenhos dos cursores do jogo, em SVG numa grade de 32 unidades.
//
// Fonte única: o gerador (gerar_cursores.js) rasteriza estes desenhos em PNG para o
// Godot, e a página de estudo e o site usam os mesmos. Regras do estudo de 04/10/2026:
// o clique é sempre a mão com o indicador esticado colado ao polegar (nunca pode
// parecer o dedo do meio), e a seta é limpa, sem enfeite pendurado na cauda.
//
// Funciona como módulo do Node (require) e como script de página (window.CursoresVale).

(function (raiz, fabrica) {
  if (typeof module === "object" && module.exports) module.exports = fabrica();
  else raiz.CursoresVale = fabrica();
})(typeof self !== "undefined" ? self : this, function () {
  const L = "#0c1410";

  const DEFS = `<defs>
  <linearGradient id="ouro" gradientUnits="userSpaceOnUse" x1="0" y1="0" x2="18" y2="32">
    <stop offset="0" stop-color="#fff0ae"/><stop offset=".45" stop-color="#e8c46a"/><stop offset="1" stop-color="#a87632"/>
  </linearGradient>
  <linearGradient id="cobalto" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#3a66c4"/><stop offset="1" stop-color="#142a5c"/>
  </linearGradient>
  <linearGradient id="azulejo" gradientUnits="userSpaceOnUse" x1="0" y1="0" x2="20" y2="32">
    <stop offset="0" stop-color="#ffffff"/><stop offset=".6" stop-color="#eef1f6"/><stop offset="1" stop-color="#c9d5ea"/>
  </linearGradient>
  <linearGradient id="pergaminho" gradientUnits="userSpaceOnUse" x1="0" y1="0" x2="20" y2="32">
    <stop offset="0" stop-color="#fbf1da"/><stop offset=".55" stop-color="#efdcb2"/><stop offset="1" stop-color="#cfb27c"/>
  </linearGradient>
  <radialGradient id="brasa" gradientUnits="userSpaceOnUse" cx="8" cy="6" r="26">
    <stop offset="0" stop-color="#fff1b8"/><stop offset=".35" stop-color="#ffbe55"/><stop offset=".75" stop-color="#e0741f"/><stop offset="1" stop-color="#8a3610"/>
  </radialGradient>
  <filter id="sombra" x="-30%" y="-30%" width="160%" height="160%">
    <feDropShadow dx=".6" dy=".9" stdDeviation=".6" flood-color="#000" flood-opacity=".5"/>
  </filter>
  <filter id="halo" x="-60%" y="-60%" width="220%" height="220%"><feGaussianBlur stdDeviation="1.5"/></filter>
</defs>`;

  // Seta clássica, a silhueta que o jogador já conhece.
  const SETA = "M3 2.5 L3 24 L8.4 19 L12 27.2 L15.4 25.7 L11.9 17.8 L19.2 17.8 Z";
  // Seta agulha: a ponta da rosa dos ventos, sem cauda.
  const AGULHA = "M3 2.5 L19.5 11 L11.6 11.6 L11 19.5 Z";

  // Mão direita vista de costas: indicador esticado colado ao polegar (à esquerda),
  // médio, anelar e mínimo dobrados à direita, cada um mais baixo que o anterior.
  const INDICADOR = `<rect x="11" y="1.6" width="4.4" height="15.6" rx="2.2"/>`;
  const DOBRADOS = [
    `<rect x="15.1" y="10.4" width="4.3" height="8" rx="2.15"/>`,
    `<rect x="19.1" y="11.8" width="4.1" height="7.4" rx="2.05"/>`,
    `<rect x="22.9" y="13.4" width="3.7" height="6.4" rx="1.85"/>`,
  ];
  const POLEGAR = `<path d="M11.6 16.6 L6.8 12.6 C5.6 11.6 3.6 12.9 4.4 14.5 L9.4 23.2 Z"/>`;
  const palma = (punho) => punho
    ? `<rect x="10.6" y="14.2" width="16" height="12" rx="4"/>`
    : `<rect x="10.6" y="14.2" width="16" height="14.6" rx="4.6"/>`;
  const PUNHO = "M10 24.6 L27.2 24.6 L27.6 30.6 L9.6 30.6 Z";
  const RENDA = [10.8, 12.9, 15, 17.1, 19.2, 21.3, 23.4, 25.5].map(x => `<circle cx="${x}" cy="24.6" r="1.05"/>`).join("");

  /* Estilo: pele (preenchimento), borda (contorno externo), vinco (linhas internas),
     brilho (luz na borda esquerda), largura do contorno, halo e detalhes próprios. */
  function seta(e) {
    const forma = e.forma || SETA;
    return `${e.halo ? `<path d="${forma}" fill="${e.halo}" opacity=".6" filter="url(#halo)"/>` : ""}
  <g filter="url(#sombra)">
    <path d="${forma}" fill="${e.borda}" stroke="${e.borda}" stroke-width="${e.largura}" stroke-linejoin="round"/>
    <path d="${forma}" fill="${e.pele}"/>
    ${e.detalheSeta || ""}
    <path d="M4.2 6 L4.2 20.5" stroke="${e.brilho}" stroke-width=".6" stroke-linecap="round" opacity=".7"/>
  </g>`;
  }

  function mao(e) {
    const formas = palma(e.punho) + DOBRADOS.join("") + INDICADOR + POLEGAR;
    const silhueta = formas + (e.punho ? `<path d="${PUNHO}"/>${RENDA}` : "");
    return `${e.halo ? `<g fill="${e.halo}" opacity=".6" filter="url(#halo)">${silhueta}</g>` : ""}
  <g filter="url(#sombra)">
    <g fill="${e.borda}" stroke="${e.borda}" stroke-width="${e.largura}" stroke-linejoin="round">${silhueta}</g>
    <g fill="${e.pele}">${formas}</g>
    <g stroke="${e.vinco}" stroke-width=".55" fill="none" stroke-linecap="round">
      <path d="M15.2 12.6 L15.2 17.4"/><path d="M19.2 13.8 L19.2 18.4"/><path d="M23 15.4 L23 19.2"/>
      ${e.semVincoPolegar ? "" : `<path d="M11.6 17.2 L9.8 21.4"/>`}
    </g>
    <path d="M12.1 4.2 Q13.2 3 14.3 4.2" stroke="${e.brilho}" stroke-width=".55" fill="none" stroke-linecap="round"/>
    <path d="M12 6 L12 14.6" stroke="${e.brilho}" stroke-width=".55" stroke-linecap="round" opacity=".6"/>
    ${e.punho ? `<g fill="#f4e5bd" stroke="${e.borda}" stroke-width=".35">${RENDA}</g>
      <path d="${PUNHO}" fill="url(#cobalto)"/>
      <path d="M9.9 26 L27.3 26 M9.7 29.3 L27.5 29.3" stroke="url(#ouro)" stroke-width=".8"/>
      <path d="M18.6 26.8 L19.7 27.65 L18.6 28.5 L17.5 27.65Z" fill="#f4e5bd"/>` : ""}
    ${e.detalheMao || ""}
  </g>`;
  }

  const ESTILOS = {
    ouro: { pele: "url(#ouro)", borda: L, vinco: "#7a5222", brilho: "#fff6d0", largura: 2.2 },
    azulejo: {
      pele: "url(#azulejo)", borda: "#142a5c", vinco: "#2f56a8", brilho: "#ffffff", largura: 2.3,
      forma: AGULHA, semVincoPolegar: true,
      detalheSeta: `<path d="M3 2.5 L11.6 11.6" stroke="#2f56a8" stroke-width=".7"/>
      <path d="M11.3 8.6 L13.1 11.3 L11.3 14 L9.5 11.3Z" fill="#2f56a8"/>`,
      detalheMao: `<path d="M18.6 21.6 L20.4 23.4 L18.6 25.2 L16.8 23.4Z" fill="#2f56a8"/>`,
    },
    talha: {
      pele: "url(#ouro)", borda: L, vinco: "#7a5222", brilho: "#fff6d0", largura: 2.2, punho: true,
      detalheSeta: `<path d="M5 8.4 L5 19.6 L7.4 17.4 L13.6 16" stroke="url(#cobalto)" stroke-width="1.1" fill="none" stroke-linejoin="round"/>`,
    },
    pergaminho: {
      pele: "url(#pergaminho)", borda: "#3b2412", vinco: "#6b4a2a", brilho: "#fffaf0", largura: 1.9,
      detalheSeta: `<g stroke="#8a6a44" stroke-width=".4" opacity=".7"><path d="M9 21 L10.6 19.4"/><path d="M10 23.4 L11.6 21.8"/><path d="M11 25.6 L12.6 24"/></g>`,
      detalheMao: `<g stroke="#8a6a44" stroke-width=".4" opacity=".7"><path d="M22 24 L24.6 21.4"/><path d="M20 26.6 L24.4 22.2"/><path d="M18 28 L23 23"/></g>`,
    },
    lampiao: { pele: "url(#brasa)", borda: "#2a1206", vinco: "#8a3a10", brilho: "#fff1b8", largura: 2.2, halo: "#ff9a3c" },
  };

  // Ordem igual à do AJUSTAR (Tela.CURSORES); "classico" é o PNG antigo, sem desenho aqui.
  const IDS = ["ouro", "azulejo", "talha", "pergaminho", "lampiao"];
  // Pontos quentes na grade de 32: ponta da seta e ponta do indicador.
  const QUENTE_SETA = [3, 2.5];
  const QUENTE_MAO = [13.2, 1.6];

  function svg(id, estado, lado) {
    const desenho = estado === "mao" ? mao(ESTILOS[id]) : seta(ESTILOS[id]);
    return `<svg xmlns="http://www.w3.org/2000/svg" width="${lado}" height="${lado}" viewBox="0 0 32 32">${DEFS}${desenho}</svg>`;
  }

  function quente(estado, lado) {
    return (estado === "mao" ? QUENTE_MAO : QUENTE_SETA).map(v => Math.min(lado - 1, Math.round(v * lado / 32)));
  }

  return { IDS, svg, quente };
});
