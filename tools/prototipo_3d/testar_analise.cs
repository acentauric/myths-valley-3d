// A ANÁLISE DO testar.ps1, em C#: o grafo de dependências, os fechos e as
// impressões digitais. O PowerShell 5.1 levava mais de um minuto para montar os
// 216 fechos (um laço de função por aresta); aqui leva poucos segundos.
//
// O runner compila este arquivo uma vez e guarda a DLL em .godot/testar3d,
// com o hash da fonte no nome. C# 5 de propósito: é o que o Add-Type do
// Windows PowerShell 5.1 compila.
//
// A IMPRESSÃO SEMÂNTICA (v2) ignora o que não muda o que o jogo faz:
//   .gd    sem comentário, sem linha em branco e sem espaço no fim da linha
//          (o recuo fica: em GDScript ele é sintaxe); o '#' dentro de string fica.
//   .json  sem espaço fora das strings. A ORDEM DAS CHAVES FICA: o Dictionary
//          do Godot itera na ordem de inserção, e reordenar muda o jogo.
//   .md e docs/  fora da impressão. Nada do jogo lê documentação.
// Um portão que lê código-fonte como texto (FileAccess no .gd, `source_code`)
// é TEXTUAL: para o que ele lê vale o conteúdo cru, porque um comentário pode
// ser justamente o que ele procura ou falsifica (ver EscopoTextual).

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;

namespace Testar3D
{
	public static class Texto
	{
		public static readonly UTF8Encoding SemBom = new UTF8Encoding(false);

		public static string Hash(string texto)
		{
			using (SHA1 sha = SHA1.Create())
			{
				byte[] h = sha.ComputeHash(SemBom.GetBytes(texto));
				StringBuilder sb = new StringBuilder(h.Length * 2);
				foreach (byte b in h) sb.Append(b.ToString("x2"));
				return sb.ToString();
			}
		}

		public static string Ler(string caminho)
		{
			if (!File.Exists(caminho)) return "";
			using (FileStream fs = new FileStream(caminho, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
			using (StreamReader r = new StreamReader(fs, SemBom)) return r.ReadToEnd();
		}

		// Linhas lógicas de um GDScript: sem comentário, sem linha em branco, sem
		// espaço no fim. Uma string de várias linhas fica inteira numa linha lógica
		// (com os '\n' dela), intocada: espaço dentro de string é dado.
		public static List<string> LinhasGd(string t)
		{
			List<string> linhas = new List<string>();
			StringBuilder atual = new StringBuilder();
			int i = 0, n = t.Length;
			if (n > 0 && t[0] == '﻿') i = 1;
			while (i < n)
			{
				char c = t[i];
				if (c == '\r') { i++; continue; }
				if (c == '#') { while (i < n && t[i] != '\n') i++; continue; }
				if (c == '\n') { FecharLinha(linhas, atual); i++; continue; }
				if (c == '"' || c == '\'') { i = CopiarString(t, i, atual); continue; }
				atual.Append(c);
				i++;
			}
			FecharLinha(linhas, atual);
			return linhas;
		}

		static void FecharLinha(List<string> linhas, StringBuilder atual)
		{
			int fim = atual.Length;
			while (fim > 0 && (atual[fim - 1] == ' ' || atual[fim - 1] == '\t')) fim--;
			if (fim > 0) linhas.Add(atual.ToString(0, fim));
			atual.Length = 0;
		}

		// Copia a string que abre em t[i] (aspas simples, duplas ou triplas; o
		// prefixo r, & ou ^ já foi copiado como texto comum) e devolve onde ela acaba.
		// A barra invertida pula o caractere seguinte também na string crua: assim o
		// Godot (e o Python) decidem onde uma r"..." termina.
		static int CopiarString(string t, int i, StringBuilder o)
		{
			char q = t[i];
			int n = t.Length;
			bool tripla = i + 2 < n && t[i + 1] == q && t[i + 2] == q;
			int abre = tripla ? 3 : 1;
			o.Append(t, i, abre);
			i += abre;
			while (i < n)
			{
				char c = t[i];
				if (c == '\r') { i++; continue; }
				if (c == '\\' && i + 1 < n)
				{
					o.Append(c);
					i++;
					if (t[i] == '\r') i++;
					if (i < n) { o.Append(t[i]); i++; }
					continue;
				}
				if (c == q)
				{
					if (!tripla) { o.Append(c); return i + 1; }
					if (i + 2 < n && t[i + 1] == q && t[i + 2] == q) { o.Append(q, 3); return i + 3; }
					o.Append(c);
					i++;
					continue;
				}
				// String simples sem fim na linha: o erro é do Godot; aqui só não engole o resto.
				if (c == '\n' && !tripla) return i;
				o.Append(c);
				i++;
			}
			return i;
		}

		public static string NormalizarGd(string t)
		{
			return string.Join("\n", LinhasGd(t).ToArray());
		}

		// JSON sem espaço fora das strings. Não reordena nada (ver o topo).
		public static string NormalizarJson(string t)
		{
			StringBuilder o = new StringBuilder(t.Length);
			int i = 0, n = t.Length;
			if (n > 0 && t[0] == '﻿') i = 1;
			while (i < n)
			{
				char c = t[i];
				if (c == '"')
				{
					o.Append(c);
					i++;
					while (i < n)
					{
						char d = t[i];
						o.Append(d);
						i++;
						if (d == '\\' && i < n) { o.Append(t[i]); i++; continue; }
						if (d == '"') break;
					}
					continue;
				}
				if (c == ' ' || c == '\t' || c == '\r' || c == '\n') { i++; continue; }
				o.Append(c);
				i++;
			}
			return o.ToString();
		}

		// Blobs do git pelo `cat-file --batch`, escrevendo os ids em bytes ASCII
		// (o pipe do PowerShell 5.1 poria um BOM na frente do primeiro).
		public static Dictionary<string, string> LerBlobs(string raiz, ICollection<string> blobs)
		{
			Dictionary<string, string> lidos = new Dictionary<string, string>();
			if (blobs.Count == 0) return lidos;
			ProcessStartInfo psi = new ProcessStartInfo("git", "cat-file --batch");
			psi.WorkingDirectory = raiz;
			psi.UseShellExecute = false;
			psi.RedirectStandardInput = true;
			psi.RedirectStandardOutput = true;
			psi.CreateNoWindow = true;
			Process p = Process.Start(psi);
			List<string> pedidos = new List<string>(blobs);
			Thread escritor = new Thread(delegate ()
			{
				Stream entrada = p.StandardInput.BaseStream;
				foreach (string b in pedidos)
				{
					byte[] linha = Encoding.ASCII.GetBytes(b + "\n");
					entrada.Write(linha, 0, linha.Length);
				}
				entrada.Close();
			});
			escritor.Start();
			Stream saida = p.StandardOutput.BaseStream;
			foreach (string b in pedidos)
			{
				string cabeca = LerLinhaAscii(saida);
				if (cabeca == null) break;
				string[] partes = cabeca.Split(' ');
				if (partes.Length < 3) continue; // "<id> missing"
				int tamanho = int.Parse(partes[2]);
				byte[] corpo = new byte[tamanho];
				int lido = 0;
				while (lido < tamanho)
				{
					int k = saida.Read(corpo, lido, tamanho - lido);
					if (k <= 0) break;
					lido += k;
				}
				saida.ReadByte(); // o '\n' depois do conteúdo
				int inicio = (tamanho >= 3 && corpo[0] == 0xEF && corpo[1] == 0xBB && corpo[2] == 0xBF) ? 3 : 0;
				lidos[partes[0]] = SemBom.GetString(corpo, inicio, tamanho - inicio);
			}
			escritor.Join();
			p.WaitForExit();
			return lidos;
		}

		static string LerLinhaAscii(Stream s)
		{
			StringBuilder sb = new StringBuilder();
			while (true)
			{
				int b = s.ReadByte();
				if (b < 0) return sb.Length > 0 ? sb.ToString() : null;
				if (b == '\n') return sb.ToString();
				sb.Append((char)b);
			}
		}
	}

	// O grafo de quem cada arquivo alcança, igual ao que o runner montava em
	// PowerShell (mesmas expressões, mesmas regras de prefixo), para que as
	// impressões v1 já gravadas no cache continuem casando.
	public class Grafo
	{
		static readonly Regex TEXTUAIS = new Regex(@"\.(gd|tscn|tres|json|gdshader|godot|cfg)$", RegexOptions.IgnoreCase);
		static readonly Regex FORA = new Regex(@"^(addons/godot_mcp/cache/|build/|\.assets-raw/)", RegexOptions.IgnoreCase);
		static readonly Regex RES = new Regex("res://[^\"'\\r\\n\\)\\]\\}<>|*?]*");
		static readonly Regex UID = new Regex("uid://[a-z0-9]+");
		static readonly Regex UID_DO_ARQUIVO = new Regex("^uid://[a-z0-9]+$", RegexOptions.IgnoreCase);
		static readonly Regex UID_DO_IMPORT = new Regex("uid=\"(uid://[a-z0-9]+)\"", RegexOptions.IgnoreCase);
		static readonly Regex UID_DA_CENA = new Regex("^\\[gd_\\w+[^\\]]*uid=\"(uid://[a-z0-9]+)\"", RegexOptions.IgnoreCase);
		static readonly Regex CLASSE = new Regex(@"^class_name\s+([A-Za-z_]\w*)", RegexOptions.IgnoreCase | RegexOptions.Multiline);
		static readonly Regex FORA_DA_IMPRESSAO_V1 = new Regex(@"\.(import|uid)$", RegexOptions.IgnoreCase);
		static readonly Regex FORA_DA_IMPRESSAO = new Regex(@"(\.(import|uid|md)$|^docs/)", RegexOptions.IgnoreCase);

		readonly string raiz;
		public readonly Dictionary<string, string> Atual;
		public readonly Dictionary<string, string> Conteudos = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
		public readonly Dictionary<string, string> PorUid = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
		public readonly Dictionary<string, string> porClasse = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
		readonly List<string> todos;
		readonly Regex regexClasses;
		readonly Dictionary<string, List<string>> cachePrefixo = new Dictionary<string, List<string>>();
		readonly Dictionary<string, HashSet<string>> arestas = new Dictionary<string, HashSet<string>>();

		public Grafo(string raiz, Dictionary<string, string> atual)
		{
			this.raiz = raiz;
			Atual = new Dictionary<string, string>(atual, StringComparer.OrdinalIgnoreCase);
			foreach (string c in Atual.Keys)
			{
				if (c.EndsWith(".uid", StringComparison.OrdinalIgnoreCase))
				{
					string u = Texto.Ler(Path.Combine(raiz, c)).Trim();
					if (UID_DO_ARQUIVO.IsMatch(u)) PorUid[u] = c.Substring(0, c.Length - 4);
				}
				else if (c.EndsWith(".import", StringComparison.OrdinalIgnoreCase))
				{
					Match m = UID_DO_IMPORT.Match(Texto.Ler(Path.Combine(raiz, c)));
					if (m.Success) PorUid[m.Groups[1].Value] = c.Substring(0, c.Length - 7);
				}
			}
			foreach (string c in Atual.Keys)
			{
				if (!TEXTUAIS.IsMatch(c) || FORA.IsMatch(c) || c == "project.godot") continue;
				string texto = Texto.Ler(Path.Combine(raiz, c));
				Conteudos[c] = texto;
				if (c.EndsWith(".tscn", StringComparison.OrdinalIgnoreCase) || c.EndsWith(".tres", StringComparison.OrdinalIgnoreCase))
				{
					Match m = UID_DA_CENA.Match(texto);
					if (m.Success) PorUid[m.Groups[1].Value] = c;
				}
				if (c.EndsWith(".gd", StringComparison.OrdinalIgnoreCase))
				{
					Match m = CLASSE.Match(texto);
					if (m.Success) porClasse[m.Groups[1].Value] = c;
				}
			}
			todos = new List<string>(Atual.Keys);
			todos.Sort(StringComparer.Ordinal);
			if (porClasse.Count > 0)
			{
				List<string> nomes = new List<string>();
				foreach (string k in porClasse.Keys) nomes.Add(Regex.Escape(k));
				regexClasses = new Regex(@"\b(" + string.Join("|", nomes.ToArray()) + @")\b");
			}
		}

		List<string> PorPrefixo(string prefixo)
		{
			List<string> achados;
			if (cachePrefixo.TryGetValue(prefixo, out achados)) return achados;
			achados = new List<string>();
			foreach (string c in todos) if (c.StartsWith(prefixo, StringComparison.Ordinal)) achados.Add(c);
			cachePrefixo[prefixo] = achados;
			return achados;
		}

		// Os arquivos que um texto cita por `res://`: o caminho inteiro, ou, montado
		// em tempo de execução, a pasta (ou o prefixo) inteira.
		void CitadosPorRes(string texto, HashSet<string> saida)
		{
			foreach (Match m in RES.Matches(texto))
			{
				string r = m.Value.Substring(6);
				int corte = r.IndexOfAny(new char[] { '%', '{', ' ', '+' });
				if (corte >= 0) r = r.Substring(0, corte);
				string ultimo = r.Substring(r.LastIndexOf('/') + 1);
				if (ultimo.Contains(".") && corte < 0)
				{
					if (Atual.ContainsKey(r)) saida.Add(r);
				}
				else if (r.Length >= 4)
				{
					foreach (string p in PorPrefixo(r)) saida.Add(p);
				}
			}
		}

		public HashSet<string> Vizinhos(string caminho)
		{
			HashSet<string> saida;
			if (arestas.TryGetValue(caminho, out saida)) return saida;
			saida = new HashSet<string>();
			string texto;
			if (Conteudos.TryGetValue(caminho, out texto))
			{
				CitadosPorRes(texto, saida);
				foreach (Match m in UID.Matches(texto))
				{
					string alvo;
					if (PorUid.TryGetValue(m.Value, out alvo)) saida.Add(alvo);
				}
				if (regexClasses != null && caminho.EndsWith(".gd", StringComparison.OrdinalIgnoreCase))
				{
					foreach (Match m in regexClasses.Matches(texto)) saida.Add(porClasse[m.Value]);
				}
			}
			arestas[caminho] = saida;
			return saida;
		}

		public HashSet<string> Fecho(string[] raizes)
		{
			HashSet<string> visto = new HashSet<string>();
			Queue<string> fila = new Queue<string>();
			foreach (string r in raizes) if (visto.Add(r)) fila.Enqueue(r);
			while (fila.Count > 0)
				foreach (string v in Vizinhos(fila.Dequeue())) if (visto.Add(v)) fila.Enqueue(v);
			return visto;
		}

		public string[] Cadeia(string[] raizes, string alvo)
		{
			Dictionary<string, string> pai = new Dictionary<string, string>();
			Queue<string> fila = new Queue<string>();
			foreach (string r in raizes) if (!pai.ContainsKey(r)) { pai[r] = ""; fila.Enqueue(r); }
			while (fila.Count > 0)
			{
				string c = fila.Dequeue();
				if (c == alvo) break;
				foreach (string v in Vizinhos(c)) if (!pai.ContainsKey(v)) { pai[v] = c; fila.Enqueue(v); }
			}
			if (!pai.ContainsKey(alvo)) return new string[0];
			List<string> passos = new List<string>();
			for (string c = alvo; c != ""; c = pai[c]) passos.Insert(0, c);
			return passos.ToArray();
		}

		// A impressão do runner antigo (conteúdo cru, .md dentro). Só serve para
		// reconhecer os verdes que o cache gravou antes da v2.
		public static string ImpressaoV1(HashSet<string> fecho, Dictionary<string, string> estado)
		{
			List<string> linhas = new List<string>();
			foreach (string c in fecho)
			{
				if (FORA_DA_IMPRESSAO_V1.IsMatch(c)) continue;
				string h;
				if (!estado.TryGetValue(c, out h)) h = "ausente";
				linhas.Add(c + "=" + h);
			}
			linhas.Sort(StringComparer.Ordinal);
			return Texto.Hash(string.Join("\n", linhas.ToArray()));
		}

		public static bool ForaDaImpressao(string caminho)
		{
			return FORA_DA_IMPRESSAO.IsMatch(caminho);
		}

		// O QUE O PORTÃO LÊ COMO TEXTO, e para o qual comentário conta. Olha os
		// arquivos de tests/ do fecho:
		//   - quem mexe em `source_code` de script tirado de um nó (get_script())
		//     pode estar lendo qualquer script: o fecho inteiro vale cru;
		//   - quem mexe em `source_code` de script carregado pelo caminho (as
		//     falsificações com `.replace`), ou lê com get_file_as_string/get_as_text
		//     (sem ser para dar parse de JSON), lê o que o próprio teste cita por
		//     res:// — o caminho, ou a pasta que ele varre —: esses valem crus.
		// Devolve null quando o portão não lê código como texto.
		static readonly Regex LEITURA_CRUA = new Regex(@"get_file_as_string|get_as_text");
		public HashSet<string> EscopoTextual(HashSet<string> fecho)
		{
			HashSet<string> escopo = null;
			foreach (string c in fecho)
			{
				if (!c.StartsWith("tests/", StringComparison.OrdinalIgnoreCase)) continue;
				string texto;
				if (!Conteudos.TryGetValue(c, out texto)) continue;
				bool falsifica = texto.Contains("source_code");
				if (falsifica && texto.Contains("get_script(")) return new HashSet<string>(fecho);
				bool le = falsifica;
				foreach (string linha in texto.Split('\n'))
				{
					if (!LEITURA_CRUA.IsMatch(linha)) continue;
					if (linha.Contains("JSON") || linha.Contains(".json")) continue;
					le = true;
					break;
				}
				if (!le) continue;
				if (escopo == null) escopo = new HashSet<string>();
				CitadosPorRes(texto, escopo);
			}
			return escopo;
		}
	}

	// Hash semântico de cada (arquivo, blob), guardado entre execuções: o
	// normalizado de um blob nunca muda, então cada blob é lido uma vez na vida.
	public class Normas
	{
		readonly string arquivo;
		readonly string raiz;
		readonly Grafo grafo;
		readonly Dictionary<string, string> mapa = new Dictionary<string, string>();
		int novos;

		public Normas(string arquivo, string raiz, Grafo grafo)
		{
			this.arquivo = arquivo;
			this.raiz = raiz;
			this.grafo = grafo;
			if (File.Exists(arquivo))
			{
				foreach (string l in File.ReadAllLines(arquivo))
				{
					string[] p = l.Split(' ');
					if (p.Length == 2) mapa[p[0]] = p[1];
				}
			}
		}

		public static string Tipo(string caminho)
		{
			if (caminho.EndsWith(".gd", StringComparison.OrdinalIgnoreCase)) return "gd";
			if (caminho.EndsWith(".json", StringComparison.OrdinalIgnoreCase)) return "json";
			return null;
		}

		static string Normalizar(string tipo, string texto)
		{
			return tipo == "gd" ? Texto.NormalizarGd(texto) : Texto.NormalizarJson(texto);
		}

		// Garante a norma de cada par (caminho, blob) pedido: o blob de agora vem
		// do disco; o de outra versão, do git, num `cat-file` só.
		public void Preparar(IEnumerable<KeyValuePair<string, string>> pares)
		{
			Dictionary<string, string> doGit = new Dictionary<string, string>();
			foreach (KeyValuePair<string, string> par in pares)
			{
				string tipo = Tipo(par.Key);
				if (tipo == null) continue;
				string chave = tipo + ":" + par.Value;
				if (mapa.ContainsKey(chave)) continue;
				string agora;
				if (grafo.Atual.TryGetValue(par.Key, out agora) && agora == par.Value)
				{
					string texto;
					if (!grafo.Conteudos.TryGetValue(par.Key, out texto)) texto = Texto.Ler(Path.Combine(raiz, par.Key));
					mapa[chave] = Texto.Hash(Normalizar(tipo, texto));
					novos++;
				}
				else doGit[par.Value] = tipo;
			}
			if (doGit.Count == 0) return;
			Dictionary<string, string> lidos = Texto.LerBlobs(raiz, doGit.Keys);
			foreach (KeyValuePair<string, string> l in lidos)
			{
				string tipo = doGit[l.Key];
				mapa[tipo + ":" + l.Key] = Texto.Hash(Normalizar(tipo, l.Value));
				novos++;
			}
		}

		public void PrepararEstado(Dictionary<string, string> estado)
		{
			Preparar(estado);
		}

		public string De(string caminho, string blob)
		{
			string tipo = Tipo(caminho);
			if (tipo == null) return blob;
			string h;
			// Sem norma (blob que o git não achou): o cru, que só erra para mais.
			return mapa.TryGetValue(tipo + ":" + blob, out h) ? h : blob;
		}

		public void Gravar()
		{
			if (novos == 0) return;
			List<string> linhas = new List<string>();
			foreach (KeyValuePair<string, string> kv in mapa) linhas.Add(kv.Key + " " + kv.Value);
			linhas.Sort(StringComparer.Ordinal);
			string temporario = arquivo + "." + Process.GetCurrentProcess().Id + ".tmp";
			try
			{
				File.WriteAllLines(temporario, linhas.ToArray());
				if (File.Exists(arquivo)) File.Delete(arquivo);
				File.Move(temporario, arquivo);
			}
			catch (IOException)
			{
				// Outra rodada gravou ao mesmo tempo: as normas são só cache, perder esta vez não erra nada.
				try { File.Delete(temporario); } catch (IOException) { }
			}
			novos = 0;
		}

		// A impressão v2: o mesmo fecho, com o hash semântico de cada arquivo
		// (ou o cru, para o que o portão lê como texto) e sem documentação.
		public string Impressao(HashSet<string> fecho, Dictionary<string, string> estado, HashSet<string> crus)
		{
			List<string> linhas = new List<string>();
			foreach (string c in fecho)
			{
				if (Grafo.ForaDaImpressao(c)) continue;
				bool cru = crus != null && crus.Contains(c);
				string h;
				if (!estado.TryGetValue(c, out h)) h = "ausente";
				else if (!cru) h = De(c, h);
				linhas.Add(c + (cru ? "=cru:" : "=") + h);
			}
			linhas.Sort(StringComparer.Ordinal);
			return Texto.Hash("v2\n" + string.Join("\n", linhas.ToArray()));
		}

		// Os arquivos do fecho cujo conteúdo (semântico, ou cru se lido como texto) difere entre dois estados.
		public List<string> Mudados(HashSet<string> fecho, Dictionary<string, string> antes, Dictionary<string, string> agora, HashSet<string> crus)
		{
			List<string> saida = new List<string>();
			foreach (string c in fecho)
			{
				if (Grafo.ForaDaImpressao(c)) continue;
				string a, b;
				bool temA = antes.TryGetValue(c, out a), temB = agora.TryGetValue(c, out b);
				if (temA != temB) { saida.Add(c); continue; }
				if (!temA) continue;
				if (crus == null || !crus.Contains(c)) { a = De(c, a); b = De(c, b); }
				if (a != b) saida.Add(c);
			}
			saida.Sort(StringComparer.Ordinal);
			return saida;
		}
	}

	// O QUE O GODOT AINDA NÃO IMPORTOU. Num `--script` o Godot não importa nada:
	// recurso sem cache em .godot/imported e class_name fora do cache de classes
	// reprovam o portão como se fosse defeito do jogo. O runner confere aqui e,
	// havendo pendência, importa uma vez antes da bateria (não uma por portão).
	public static class Importacao
	{
		static readonly Regex DESTINOS = new Regex(@"^dest_files=\[(.*)\]\s*$", RegexOptions.Multiline);
		static readonly Regex CAMINHO = new Regex("\"res://([^\"]+)\"");
		static readonly Regex CLASSE_NO_CACHE = new Regex("\"class\": &\"([^\"]+)\"[^}]*?\"path\": \"res://([^\"]+)\"", RegexOptions.Singleline);

		// O .glb com "extrair texturas" (gltf/embedded_image_handling=1) tem o .scn
		// importado citando as texturas que a importação gravou ao lado dele:
		// <modelo>_<nome da imagem no glTF>.jpg/.png. O md5 do .glb bate, então o
		// Godot não reimporta; se essas texturas não estão no disco (cache copiado
		// de outro checkout, worktree nova, ou o .glb trocado com as texturas
		// velhas versionadas), todo portão que monta o modelo reprova com
		// "Failed loading resource". O .scn é comprimido (zstd) e não dá para ler;
		// os nomes vêm do bloco JSON do .glb, que é texto. Modelo cujo nome não
		// bate mesmo depois de reimportar é aceito (Aceitar), pelo md5 do cache.
		static readonly Regex EXTRAI = new Regex(@"^gltf/embedded_image_handling=1\s*$", RegexOptions.Multiline);
		static readonly Regex IMAGEM = new Regex(@"\.(png|jpe?g|webp)$", RegexOptions.IgnoreCase);
		static readonly Regex NOME = new Regex(@"""name""\s*:\s*""([^""\\]+)""");

		// Os nomes das imagens do glTF (bloco JSON de um .glb), ou null se não der para ler.
		public static List<string> ImagensDoGlb(string caminho)
		{
			try
			{
				using (FileStream fs = new FileStream(caminho, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
				{
					byte[] cabeca = new byte[20];
					if (fs.Read(cabeca, 0, 20) != 20) return null;
					if (cabeca[0] != (byte)'g' || cabeca[1] != (byte)'l' || cabeca[2] != (byte)'T' || cabeca[3] != (byte)'F') return null;
					int tamanho = BitConverter.ToInt32(cabeca, 12);
					if (BitConverter.ToUInt32(cabeca, 16) != 0x4E4F534A || tamanho <= 0 || tamanho > 64 * 1024 * 1024) return null;
					byte[] corpo = new byte[tamanho];
					int lido = 0;
					while (lido < tamanho) { int k = fs.Read(corpo, lido, tamanho - lido); if (k <= 0) return null; lido += k; }
					string json = Encoding.UTF8.GetString(corpo);
					int inicio = json.IndexOf("\"images\"", StringComparison.Ordinal);
					List<string> nomes = new List<string>();
					if (inicio < 0) return nomes;
					int abre = json.IndexOf('[', inicio);
					if (abre < 0) return null;
					int nivel = 0, fim = -1;
					bool emString = false;
					for (int i = abre; i < json.Length; i++)
					{
						char c = json[i];
						if (emString) { if (c == '\\') i++; else if (c == '"') emString = false; continue; }
						if (c == '"') emString = true;
						else if (c == '[') nivel++;
						else if (c == ']') { nivel--; if (nivel == 0) { fim = i; break; } }
					}
					if (fim < 0) return null;
					foreach (Match m in NOME.Matches(json.Substring(abre, fim - abre))) nomes.Add(m.Groups[1].Value);
					return nomes;
				}
			}
			catch (IOException) { return null; }
		}

		static string ChaveDoCache(string raiz, string origem)
		{
			string import = Path.Combine(raiz, origem + ".import");
			Match m = DESTINOS.Match(Texto.Ler(import));
			if (!m.Success) return null;
			foreach (Match d in CAMINHO.Matches(m.Groups[1].Value))
			{
				string completo = Path.Combine(raiz, d.Groups[1].Value);
				if (!File.Exists(completo)) return null;
				string md5 = Regex.Replace(completo, @"(-[0-9a-f]{32})\..*$", "$1.md5");
				return origem + " " + Texto.Ler(md5).Replace("\r", "").Replace("\n", " ").Trim();
			}
			return null;
		}

		static string ArquivoAceitos(string raiz) { return Path.Combine(raiz, ".godot/testar3d/modelos_sem_textura.txt"); }

		public static List<string> CachesQuebrados(string raiz, Grafo grafo)
		{
			List<string> quebrados = new List<string>();
			HashSet<string> aceitos = new HashSet<string>();
			if (File.Exists(ArquivoAceitos(raiz))) foreach (string l in File.ReadAllLines(ArquivoAceitos(raiz))) aceitos.Add(l);
			foreach (string c in grafo.Atual.Keys)
			{
				if (!c.EndsWith(".glb.import", StringComparison.OrdinalIgnoreCase) && !c.EndsWith(".gltf.import", StringComparison.OrdinalIgnoreCase)) continue;
				string origem = c.Substring(0, c.Length - 7);
				string completo = Path.Combine(raiz, origem);
				if (!File.Exists(completo)) continue;
				if (!EXTRAI.IsMatch(Texto.Ler(Path.Combine(raiz, c)))) continue;
				string chave = ChaveDoCache(raiz, origem);
				if (chave == null || aceitos.Contains(chave)) continue; // sem cache: Pendencias já pega
				List<string> imagens = ImagensDoGlb(completo);
				if (imagens == null) continue;
				string pasta = Path.GetDirectoryName(completo);
				string prefixo = Path.GetFileNameWithoutExtension(completo) + "_";
				foreach (string imagem in imagens)
				{
					bool achou = false;
					foreach (string f in Directory.GetFiles(pasta, prefixo + imagem + ".*"))
						if (IMAGEM.IsMatch(f)) { achou = true; break; }
					if (!achou) { quebrados.Add(origem); break; }
				}
			}
			return quebrados;
		}

		// Depois de reimportar: o modelo que segue sem textura extraída não tem imagem.
		public static void Aceitar(string raiz, IEnumerable<string> origens)
		{
			HashSet<string> aceitos = new HashSet<string>();
			if (File.Exists(ArquivoAceitos(raiz))) foreach (string l in File.ReadAllLines(ArquivoAceitos(raiz))) aceitos.Add(l);
			foreach (string origem in origens)
			{
				string chave = ChaveDoCache(raiz, origem);
				if (chave != null) aceitos.Add(chave);
			}
			List<string> linhas = new List<string>(aceitos);
			linhas.Sort(StringComparer.Ordinal);
			try { File.WriteAllLines(ArquivoAceitos(raiz), linhas.ToArray()); } catch (IOException) { }
		}

		public static List<string> Pendencias(string raiz, Grafo grafo)
		{
			List<string> faltando = new List<string>();
			foreach (string c in grafo.Atual.Keys)
			{
				if (!c.EndsWith(".import", StringComparison.OrdinalIgnoreCase)) continue;
				if (!File.Exists(Path.Combine(raiz, c.Substring(0, c.Length - 7)))) continue;
				Match m = DESTINOS.Match(Texto.Ler(Path.Combine(raiz, c)));
				if (!m.Success) continue;
				foreach (Match d in CAMINHO.Matches(m.Groups[1].Value))
				{
					if (!File.Exists(Path.Combine(raiz, d.Groups[1].Value))) { faltando.Add(c.Substring(0, c.Length - 7)); break; }
				}
			}
			faltando.AddRange(CachesQuebrados(raiz, grafo));
			Dictionary<string, string> noCache = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
			string arquivo = Path.Combine(raiz, ".godot/global_script_class_cache.cfg");
			foreach (Match m in CLASSE_NO_CACHE.Matches(Texto.Ler(arquivo))) noCache[m.Groups[1].Value] = m.Groups[2].Value;
			foreach (KeyValuePair<string, string> kv in grafo.porClasse)
			{
				string ali;
				if (!noCache.TryGetValue(kv.Key, out ali) || !string.Equals(ali, kv.Value, StringComparison.OrdinalIgnoreCase))
					faltando.Add("class_name " + kv.Key);
			}
			return faltando;
		}
	}
}
