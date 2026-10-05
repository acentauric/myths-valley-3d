# Capas dos cordéis

Uma xilogravura por folheto, mostrada no folheto aberto (`scripts/ui/folheto.gd`) e
no folheto pendurado no barbante do vale (`achados_vale.gd`), pela
`scripts/prototipo_3d/capa_de_cordel.gd`.

Geradas em 03/10/2026 com o OpenAI `gpt-image-2` (1024x1536, qualidade média,
custo estimado de US$ 0,041 cada — US$ 0,41 as dez) pelo
`tools/openai/gerar-capas-cordeis.ps1`, que lê a chave pela `Get-Chave` sem
imprimi-la. O estilo e a cena de cada uma moram em `tools/openai/capas_cordeis.json`:
um bloco de madeira entalhado, tinta preta em papel de jornal envelhecido, e
nenhuma letra na imagem — o título, o autor e o preço o jogo imprime. As dez foram
conferidas uma a uma (estilo, cena do verso, nenhuma letra) e promovidas pelo
`tools/openai/promover_capas.gd` para JPG de 768x1152, qualidade 88; os PNG
originais ficam em `.assets-raw/cordeis/` (fora do Git). Importadas sem perda e
com mipmaps (o folheto pendurado é pequeno de longe).

| Arquivo | Cordel | Cena |
| --- | --- | --- |
| `peso_falso.jpg` | O Peso Falso | a balança que pende sozinha, o peso oco aberto e as moedas |
| `cachorro_do_enterro.jpg` | O Cachorro que Foi ao Enterro | o cachorro deitado na cova, a comida intocada |
| `vendeu_a_chuva.jpg` | O Homem que Vendeu a Chuva | a chuva engarrafada e a boiada do coronel |
| `missa_dos_afogados.jpg` | A Missa dos Afogados | a capela de noite, os afogados nos bancos |
| `moca_da_agua.jpg` | A Moça que Morava na Água | a moça de cabelo comprido na curva funda do rio |
| `cabra_da_fazenda.jpg` | O Cabra que Foi à Fazenda | o portão de ferro, a casa de luar e a dança sem fim |
| `porfia_do_caboclo.jpg` | Peleja do Caboclo com o Vento Sul | o caboclo de punho erguido, o vento e a igreja de pé |
| `santo_do_pau_oco.jpg` | O Santo do Pau Oco | o santo aberto, cheio de ouro, e o fiscal do rei |
| `boi_do_reconcavo.jpg` | O Boi que Falou no Engenho | o boi de carro falando ao coronel no engenho |
| `moleque_do_pier.jpg` | O Moleque que Pescou a Lua | o moleque no píer puxando a lua, a mãe ralhando |

Os termos da OpenAI atribuem ao usuário a propriedade do que ele gera; conferir as
condições vigentes antes de publicar.
