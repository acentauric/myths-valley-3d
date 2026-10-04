// Gera os PNGs dos cursores escolhíveis no AJUSTAR a partir de desenhos.js.
//
//     node tools/prototipo_3d/cursor/gerar_cursores.js [pasta] [lado]
//
// Padrão: assets/prototipo_3d/identidade/cursores/, 40 px (o lado do cursor do jogo).
// O SVG usa sombra e halo (filtros) que o importador de SVG do Godot não desenha, por
// isso a rasterização é feita pelo Chromium do Playwright (`npm i playwright` em
// qualquer pasta e NODE_PATH apontando para o node_modules dela).
// Os pontos quentes impressos no fim precisam bater com Tela.CURSORES.

const fs = require("fs");
const path = require("path");
const { chromium } = require("playwright");
const Cursores = require("./desenhos.js");

const raiz = path.resolve(__dirname, "../../..");
const pasta = path.resolve(process.argv[2] || path.join(raiz, "assets/prototipo_3d/identidade/cursores"));
const lado = Number(process.argv[3] || 40);

(async () => {
  fs.mkdirSync(pasta, { recursive: true });
  const navegador = await chromium.launch();
  const pagina = await navegador.newPage();
  for (const id of Cursores.IDS) {
    for (const estado of ["seta", "mao"]) {
      const base64 = await pagina.evaluate(async ([svg, lado]) => {
        const img = new Image();
        img.src = "data:image/svg+xml;charset=utf-8," + encodeURIComponent(svg);
        await img.decode();
        const canvas = document.createElement("canvas");
        canvas.width = canvas.height = lado;
        canvas.getContext("2d").drawImage(img, 0, 0, lado, lado);
        return canvas.toDataURL("image/png").split(",")[1];
      }, [Cursores.svg(id, estado, lado), lado]);
      const nome = `${id}_${estado}.png`;
      fs.writeFileSync(path.join(pasta, nome), Buffer.from(base64, "base64"));
      console.log(`${nome}: ${lado}x${lado}, ponto quente ${Cursores.quente(estado, lado).join(",")}`);
    }
  }
  await navegador.close();
})();
