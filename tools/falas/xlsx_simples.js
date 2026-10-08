"use strict";
// UMA PLANILHA .xlsx SEM DEPENDÊNCIA (08/10/2026), para o documento das falas
// (tools/falas/gerar_documento_das_falas.js). O .xlsx é um zip de XMLs: este módulo
// escreve o zip (deflate do próprio node) e os XMLs mínimos que o Excel, o LibreOffice e
// o Google Planilhas abrem — várias abas, largura de coluna, linha congelada, filtro,
// texto quebrado, cores por célula e lista de escolha (validação).
//
// Uso:
//   const { escreverXlsx } = require("./xlsx_simples.js");
//   const buf = escreverXlsx([{ nome, colunas: [{ titulo, largura, quebra }], linhas: [[...]],
//     estiloDaCelula(iLinha, iColuna, valor), estiloDoCabecalho(iColuna), congelarLinhas,
//     filtro, listas: [{ coluna, valores }] }], { titulo, autor });

const zlib = require("zlib");

// --- o zip -------------------------------------------------------------------------------

const TABELA_CRC = (() => {
  const t = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c >>> 0;
  }
  return t;
})();

function crc32(buf) {
  let c = 0xffffffff;
  for (let i = 0; i < buf.length; i++) c = TABELA_CRC[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}

function zipar(arquivos, quando) {
  const hora = ((quando.getHours() << 11) | (quando.getMinutes() << 5) | Math.floor(quando.getSeconds() / 2)) & 0xffff;
  const data = (((quando.getFullYear() - 1980) << 9) | ((quando.getMonth() + 1) << 5) | quando.getDate()) & 0xffff;
  const partes = [];
  const central = [];
  let deslocamento = 0;
  for (const a of arquivos) {
    const nome = Buffer.from(a.nome, "utf8");
    const dados = Buffer.isBuffer(a.dados) ? a.dados : Buffer.from(a.dados, "utf8");
    const crc = crc32(dados);
    const comprimido = zlib.deflateRawSync(dados, { level: 9 });
    const local = Buffer.alloc(30);
    local.writeUInt32LE(0x04034b50, 0);
    local.writeUInt16LE(20, 4);
    local.writeUInt16LE(0x0800, 6);
    local.writeUInt16LE(8, 8);
    local.writeUInt16LE(hora, 10);
    local.writeUInt16LE(data, 12);
    local.writeUInt32LE(crc, 14);
    local.writeUInt32LE(comprimido.length, 18);
    local.writeUInt32LE(dados.length, 22);
    local.writeUInt16LE(nome.length, 26);
    local.writeUInt16LE(0, 28);
    partes.push(local, nome, comprimido);
    const c = Buffer.alloc(46);
    c.writeUInt32LE(0x02014b50, 0);
    c.writeUInt16LE(20, 4);
    c.writeUInt16LE(20, 6);
    c.writeUInt16LE(0x0800, 8);
    c.writeUInt16LE(8, 10);
    c.writeUInt16LE(hora, 12);
    c.writeUInt16LE(data, 14);
    c.writeUInt32LE(crc, 16);
    c.writeUInt32LE(comprimido.length, 20);
    c.writeUInt32LE(dados.length, 24);
    c.writeUInt16LE(nome.length, 28);
    c.writeUInt16LE(0, 30);
    c.writeUInt16LE(0, 32);
    c.writeUInt16LE(0, 34);
    c.writeUInt16LE(0, 36);
    c.writeUInt32LE(0, 38);
    c.writeUInt32LE(deslocamento, 42);
    central.push(c, nome);
    deslocamento += local.length + nome.length + comprimido.length;
  }
  const tamanhoCentral = central.reduce((soma, b) => soma + b.length, 0);
  const fim = Buffer.alloc(22);
  fim.writeUInt32LE(0x06054b50, 0);
  fim.writeUInt16LE(0, 4);
  fim.writeUInt16LE(0, 6);
  fim.writeUInt16LE(arquivos.length, 8);
  fim.writeUInt16LE(arquivos.length, 10);
  fim.writeUInt32LE(tamanhoCentral, 12);
  fim.writeUInt32LE(deslocamento, 16);
  fim.writeUInt16LE(0, 20);
  return Buffer.concat([...partes, ...central, fim]);
}

// --- o XML -------------------------------------------------------------------------------

function xml(valor) {
  return String(valor)
    .replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F￾￿]/g, "")
    .replace(/[\uD800-\uDBFF](?![\uDC00-\uDFFF])|(?<![\uD800-\uDBFF])[\uDC00-\uDFFF]/g, "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function letraDaColuna(i) {
  let s = "";
  let n = i + 1;
  while (n > 0) {
    const r = (n - 1) % 26;
    s = String.fromCharCode(65 + r) + s;
    n = Math.floor((n - 1) / 26);
  }
  return s;
}

const NS = 'xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"';
const CABECA = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n';

// --- os estilos --------------------------------------------------------------------------

class Estilos {
  constructor() {
    this.fontes = ['<font><sz val="10"/><name val="Calibri"/><family val="2"/></font>'];
    this.fundos = ['<fill><patternFill patternType="none"/></fill>', '<fill><patternFill patternType="gray125"/></fill>'];
    this.bordas = [
      "<border><left/><right/><top/><bottom/><diagonal/></border>",
      '<border><left style="thin"><color rgb="FFD9D9D9"/></left><right style="thin"><color rgb="FFD9D9D9"/></right><top style="thin"><color rgb="FFD9D9D9"/></top><bottom style="thin"><color rgb="FFD9D9D9"/></bottom><diagonal/></border>',
    ];
    this.xfs = ['<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'];
    this._cache = new Map();
  }

  _indice(lista, item) {
    const i = lista.indexOf(item);
    if (i >= 0) return i;
    lista.push(item);
    return lista.length - 1;
  }

  // op: { negrito, italico, cor: "RRGGBB", fundo: "RRGGBB", quebra, horizontal, vertical, tamanho }
  estilo(op = {}) {
    const chave = JSON.stringify(op);
    if (this._cache.has(chave)) return this._cache.get(chave);
    const fonte = `<font>${op.negrito ? "<b/>" : ""}${op.italico ? "<i/>" : ""}<sz val="${op.tamanho || 10}"/>${op.cor ? `<color rgb="FF${op.cor}"/>` : ""}<name val="Calibri"/><family val="2"/></font>`;
    const idFonte = this._indice(this.fontes, fonte);
    const idFundo = op.fundo ? this._indice(this.fundos, `<fill><patternFill patternType="solid"><fgColor rgb="FF${op.fundo}"/><bgColor indexed="64"/></patternFill></fill>`) : 0;
    const alinhamento = `<alignment vertical="${op.vertical || "top"}"${op.horizontal ? ` horizontal="${op.horizontal}"` : ""}${op.quebra ? ' wrapText="1"' : ""}/>`;
    this.xfs.push(`<xf numFmtId="0" fontId="${idFonte}" fillId="${idFundo}" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1">${alinhamento}</xf>`);
    const id = this.xfs.length - 1;
    this._cache.set(chave, id);
    return id;
  }

  xml() {
    return CABECA +
      `<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">` +
      `<fonts count="${this.fontes.length}">${this.fontes.join("")}</fonts>` +
      `<fills count="${this.fundos.length}">${this.fundos.join("")}</fills>` +
      `<borders count="${this.bordas.length}">${this.bordas.join("")}</borders>` +
      `<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>` +
      `<cellXfs count="${this.xfs.length}">${this.xfs.join("")}</cellXfs>` +
      `<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>` +
      `</styleSheet>`;
  }
}

// --- uma aba -----------------------------------------------------------------------------

// A altura da linha, em pontos, pelo texto mais comprido das colunas que quebram.
function alturaDaLinha(colunas, linha) {
  let linhas = 1;
  colunas.forEach((col, i) => {
    if (!col.quebra) return;
    const texto = linha[i] === undefined || linha[i] === null ? "" : String(linha[i]);
    if (!texto) return;
    const porLinha = Math.max(8, Math.floor((col.largura || 12) * 1.15));
    let n = 0;
    for (const paragrafo of texto.split("\n")) n += Math.max(1, Math.ceil(paragrafo.length / porLinha));
    linhas = Math.max(linhas, n);
  });
  return Math.min(409, Math.max(15, linhas * 13 + 3));
}

function abaXml(aba, estilos) {
  const colunas = aba.colunas;
  const ultimaColuna = letraDaColuna(colunas.length - 1);
  const totalDeLinhas = aba.linhas.length + 1;
  const partes = [];
  partes.push(CABECA + `<worksheet ${NS}>`);
  partes.push(`<dimension ref="A1:${ultimaColuna}${totalDeLinhas}"/>`);
  const congelar = aba.congelarLinhas === undefined ? 1 : aba.congelarLinhas;
  if (congelar > 0) {
    partes.push(`<sheetViews><sheetView workbookViewId="0" zoomScale="${aba.zoom || 90}" zoomScaleNormal="${aba.zoom || 90}"><pane ySplit="${congelar}" topLeftCell="A${congelar + 1}" activePane="bottomLeft" state="frozen"/><selection pane="bottomLeft" activeCell="A${congelar + 1}" sqref="A${congelar + 1}"/></sheetView></sheetViews>`);
  } else {
    partes.push(`<sheetViews><sheetView workbookViewId="0" zoomScale="${aba.zoom || 90}" zoomScaleNormal="${aba.zoom || 90}"/></sheetViews>`);
  }
  partes.push('<sheetFormatPr defaultRowHeight="15"/>');
  partes.push("<cols>" + colunas.map((c, i) => `<col min="${i + 1}" max="${i + 1}" width="${c.largura || 12}" customWidth="1"/>`).join("") + "</cols>");
  partes.push("<sheetData>");
  // O cabeçalho.
  const altCab = aba.alturaDoCabecalho || 30;
  partes.push(`<row r="1" ht="${altCab}" customHeight="1">` + colunas.map((c, i) => {
    const s = aba.estiloDoCabecalho ? aba.estiloDoCabecalho(i) : 0;
    return `<c r="${letraDaColuna(i)}1" s="${s}" t="inlineStr"><is><t xml:space="preserve">${xml(c.titulo)}</t></is></c>`;
  }).join("") + "</row>");
  aba.linhas.forEach((linha, iLinha) => {
    const r = iLinha + 2;
    const ht = aba.semAltura ? 0 : alturaDaLinha(colunas, linha);
    partes.push(ht ? `<row r="${r}" ht="${ht}" customHeight="1">` : `<row r="${r}">`);
    colunas.forEach((c, iCol) => {
      const valor = linha[iCol];
      const s = aba.estiloDaCelula ? aba.estiloDaCelula(iLinha, iCol, valor, linha) : 0;
      const ref = `${letraDaColuna(iCol)}${r}`;
      if (valor === undefined || valor === null || valor === "") {
        partes.push(`<c r="${ref}" s="${s}"/>`);
      } else if (typeof valor === "number" && isFinite(valor)) {
        partes.push(`<c r="${ref}" s="${s}"><v>${valor}</v></c>`);
      } else {
        partes.push(`<c r="${ref}" s="${s}" t="inlineStr"><is><t xml:space="preserve">${xml(String(valor).slice(0, 32000))}</t></is></c>`);
      }
    });
    partes.push("</row>");
  });
  partes.push("</sheetData>");
  if (aba.filtro !== false && aba.linhas.length > 0) partes.push(`<autoFilter ref="A1:${ultimaColuna}${totalDeLinhas}"/>`);
  const listas = aba.listas || [];
  if (listas.length > 0 && aba.linhas.length > 0) {
    partes.push(`<dataValidations count="${listas.length}">` + listas.map((l) => {
      const letra = letraDaColuna(l.coluna);
      return `<dataValidation type="list" allowBlank="1" showInputMessage="1" showErrorMessage="1" sqref="${letra}2:${letra}${totalDeLinhas}"><formula1>${xml('"' + l.valores.join(",") + '"')}</formula1></dataValidation>`;
    }).join("") + "</dataValidations>");
  }
  partes.push('<pageMargins left="0.4" right="0.4" top="0.5" bottom="0.5" header="0.3" footer="0.3"/>');
  partes.push("</worksheet>");
  return partes.join("");
}

// --- o livro -----------------------------------------------------------------------------

function escreverXlsx(abas, info = {}) {
  const estilos = info.estilos || new Estilos();
  const quando = info.quando || new Date();
  const arquivos = [];
  const xmlDasAbas = abas.map((aba) => abaXml(aba, estilos));
  arquivos.push({ nome: "[Content_Types].xml", dados: CABECA +
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">' +
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>' +
    '<Default Extension="xml" ContentType="application/xml"/>' +
    '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>' +
    abas.map((_, i) => `<Override PartName="/xl/worksheets/sheet${i + 1}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>`).join("") +
    '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>' +
    '<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>' +
    '<Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>' +
    "</Types>" });
  arquivos.push({ nome: "_rels/.rels", dados: CABECA +
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>' +
    '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>' +
    '<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>' +
    "</Relationships>" });
  const iso = quando.toISOString().replace(/\.\d{3}Z$/, "Z");
  arquivos.push({ nome: "docProps/core.xml", dados: CABECA +
    '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">' +
    `<dc:title>${xml(info.titulo || "")}</dc:title><dc:creator>${xml(info.autor || "")}</dc:creator>` +
    `<dcterms:created xsi:type="dcterms:W3CDTF">${iso}</dcterms:created><dcterms:modified xsi:type="dcterms:W3CDTF">${iso}</dcterms:modified>` +
    "</cp:coreProperties>" });
  arquivos.push({ nome: "docProps/app.xml", dados: CABECA +
    '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">' +
    `<Application>${xml(info.aplicacao || "tools/falas")}</Application></Properties>` });
  const nomes = abas.map((a) => a.nome.replace(/[\[\]:*?\/\\]/g, " ").slice(0, 31));
  const definidos = abas.map((a, i) => (a.filtro !== false && a.linhas.length > 0)
    ? `<definedName name="_xlnm._FilterDatabase" localSheetId="${i}" hidden="1">'${xml(nomes[i].replace(/'/g, "''"))}'!$A$1:$${letraDaColuna(a.colunas.length - 1)}$${a.linhas.length + 1}</definedName>` : "").join("");
  arquivos.push({ nome: "xl/workbook.xml", dados: CABECA +
    `<workbook ${NS}><bookViews><workbookView xWindow="0" yWindow="0" windowWidth="28800" windowHeight="15000" activeTab="0"/></bookViews>` +
    "<sheets>" + nomes.map((n, i) => `<sheet name="${xml(n)}" sheetId="${i + 1}" r:id="rId${i + 1}"/>`).join("") + "</sheets>" +
    (definidos ? `<definedNames>${definidos}</definedNames>` : "") +
    "</workbook>" });
  arquivos.push({ nome: "xl/_rels/workbook.xml.rels", dados: CABECA +
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
    abas.map((_, i) => `<Relationship Id="rId${i + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet${i + 1}.xml"/>`).join("") +
    `<Relationship Id="rId${abas.length + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>` +
    "</Relationships>" });
  xmlDasAbas.forEach((x, i) => arquivos.push({ nome: `xl/worksheets/sheet${i + 1}.xml`, dados: x }));
  arquivos.push({ nome: "xl/styles.xml", dados: estilos.xml() });
  return zipar(arquivos, quando);
}

module.exports = { escreverXlsx, Estilos, letraDaColuna };
