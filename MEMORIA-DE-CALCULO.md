# Memória de cálculo — módulos de dinheiro do App Ferramentas APM

> Todas as fórmulas dos módulos financeiros, com premissa, unidade e onde cada uma é usada.
> Serve para dois fins: **defender número em aula** (o mentorado vai perguntar de onde saiu) e **manter o app** sem reabrir a discussão a cada mudança.
>
> Arquivo-fonte: `mentoria-app/ferramentas.html`. Última revisão: 11/08/2026.

---

## Convenções

| Símbolo | Significado |
|---|---|
| `fatM` | faturamento bruto médio mensal |
| `i` | alíquota de imposto sobre venda |
| `cv` | soma dos custos variáveis mensais |
| `cf` | soma dos custos fixos mensais |
| `mc` | margem de contribuição em R$ |
| `mcp` | margem de contribuição em % **do faturamento bruto** |
| `cfp` | custo fixo em % do faturamento bruto |

**Regra transversal:** todo percentual de margem, imposto e comissão é **percentual do preço**, nunca do custo. Por isso eles entram sempre no divisor, nunca somados.

---

# 1. Diagnóstico Financeiro — `calcFin()`

A base de tudo. Nove dos onze módulos de dinheiro leem daqui.

```
fatM = média dos 3 meses lançados
imp  = fatM × i
rl   = fatM − imp                       receita líquida
mc   = rl − cv                          margem de contribuição
mcp  = mc ÷ fatM                        % sobre faturamento BRUTO
mcRl = mc ÷ rl                          % sobre receita LÍQUIDA
ll   = mc − cf                          lucro líquido
llp  = ll ÷ fatM
cfp  = cf ÷ fatM
pe   = cf ÷ mcRl ÷ (1 − i)              ponto de equilíbrio, em faturamento BRUTO
```

**A sutileza que mais gera erro:** existem duas margens de contribuição percentuais no sistema — sobre bruto (`mcp`) e sobre líquida (`mcRl`). O ponto de equilíbrio usa a **líquida** e depois reverte pelo imposto para devolver faturamento bruto. Usar `mcp` direto na fórmula do PE devolve um alvo menor que o necessário.

**Faixas de referência (marcenaria sob medida):**

| Indicador | Saudável | Amarelo | Vermelho |
|---|---|---|---|
| `mcp` | 35% a 55% | 30% a 35% | < 30% |
| `cfp` | 15% a 20% | 20% a 25% | > 25% |
| `llp` | 15% a 25% | 8% a 15% | < 8% |

**Premissa crítica:** a folha de produção está em `cf`, não em `cv`. Se for classificada como variável, o `pe` despenca artificialmente e todo o resto do app mente junto. É o erro nº 1 do setor e está documentado no módulo 2 da Fase 1.

---

# 2. Centro de Custo — `calcCC()`

Rateio de estrutura por **capacidade**, não por obra média.

```
pool = custo fixo mensal + (opcional) mão de obra direta
cap  = base × frentes × ocupação            base = dias úteis ou 30 corridos
cdf  = pool ÷ cap                           custo por dia-frente
rateio da obra = cdf × dias que ela ocupou
```

**Por que o denominador é capacidade e não ocupação realizada:** se o divisor fosse a ocupação do mês passado, um mês fraco elevaria o rateio, o preço subiria, a venda cairia, a ocupação cairia mais e o rateio subiria de novo. Espiral. O denominador é uma decisão de capacidade, não um espelho do passado.

**Trava contra dupla contagem:** `moCap` liga a mão de obra dentro do pool. Quando está ligada, `moUnit()` devolve **0** — a MO não pode entrar no preço duas vezes, uma na camada de transformação e outra no rateio.

---

# 3. Precificação — `calcPreco()`

```
m2r     = m² frontal × fator de consumo
bruto   = m2r × custo do m² de chapa
perda   = bruto × % de perda
matReal = bruto + perda
mo      = m2r × custo-hora unitário × fator de complexidade
cfix    = rateio de estrutura (de calcCC, ou valor fixo)
total   = matReal + mo + cfix

carga   = imposto + comissão + margem
preço   = total ÷ (1 − carga)                    ← DIVISÃO, nunca multiplicação
markup  = preço ÷ total
```

**A conta que prova a divisão:**

```
Custo 100, margem-alvo 30%
Multiplicando:  100 × 1,30 = 130  →  margem real = 30/130 = 23,1%   ✗
Dividindo:      100 ÷ 0,70 = 142,86 →  margem real = 42,86/142,86 = 30%  ✓
```

Sete pontos de margem em toda venda. Numa empresa de R$ 3,6 M/ano, R$ 252 mil.

---

# 4. Simulador — `calcSim()`

Três etapas deliberadamente separadas: **custo → margens → resultado**. O preço só aparece na etapa 2, para impedir que a base de custo seja calculada de trás para frente a partir do preço praticado.

```
ETAPA 1 — capacidade e custo, sem nenhuma referência a preço
capFab  = pessoas de fábrica  × m²/pessoa na fábrica
capMon  = pessoas de montagem × m²/pessoa na montagem
capEnt  = MENOR(capFab, capMon)            ← a entrega é a menor das duas
folha   = pessoas × custo por pessoa       quase-fixa: não cai em mês fraco
estrutura = folha + fixos + variáveis de estrutura
estrutM2  = estrutura ÷ capEnt
custoM2   = estrutM2 + material por m²     PISO ABSOLUTO, sem imposto nem lucro

ETAPA 2 — margens
varM2 = material + preço×imposto + preço×comissão
mcM2  = preço − varM2
peM2  = estrutura ÷ mcM2                   m² para empatar
metaM2 = (estrutura + lucro desejado) ÷ mcM2
precoMin = custoM2 ÷ (1 − imposto − comissão)

ETAPA 3 — resultado no volume
lucro = volume × mcM2 − estrutura
```

**Premissa forte e proposital:** a folha entra como custo **fixo**. Marceneiro é salário mensal — não cai porque o mês foi fraco. Tratá-la como variável produziria um ponto de equilíbrio fictício.

**Meta de lucro zero devolve exatamente o ponto de equilíbrio.** São a mesma conta.

---

# 5. Pró-labore — `calcPro()`

Três âncoras, e a decisão entre elas.

```
PISO     = proBruto(custo de vida + reserva − outras rendas)
           inversão numérica do líquido para o bruto, por busca binária
           sobre proLiquido(), que aplica INSS (teto) e IRRF (faixas)

MERCADO  = Σ (salário de mercado da função × horas dedicadas ÷ jornada base)
REPOSIÇÃO = MERCADO × fator de encargo        o que custaria CONTRATAR

TETO     = mc − custo fixo SEM a linha do pró-labore − (fatM × margem mínima)
```

**Por que o custo fixo do teto exclui a linha do pró-labore:** senão o valor antigo entraria na conta do valor novo, e o resultado seria circular.

**Por que `MERCADO` usa salário e `REPOSIÇÃO` usa custo:** são perguntas diferentes. Salário de mercado calibra o pró-labore (remuneração contra remuneração). Custo de reposição mede o **subsídio** que o dono dá à empresa. Trocar um pelo outro é o erro clássico.

**A trava `ancorado`:** sem as funções do bloco de mercado preenchidas, `justo = 0` e o cálculo cairia no salário mínimo com todo o resto virando dividendo — que é exatamente o desenho que a Receita autua como pró-labore disfarçado. Sem âncora, tudo volta a ser pró-labore.

**Regra de separação:** pró-labore é custo fixo e entra no preço. Distribuição de lucro sai **depois** do resultado e **não** pode entrar no preço — lançá-la como custo inflaria o m² e esconderia que a empresa não gerou o lucro que está sendo retirado.

---

# 6. Resultado Mensal (DRE 12 meses) — `calcDre()` ⭐ novo

Por mês:

```
imp = fat × i        rl = fat − imp
mc  = rl − cv        ll = mc − cf
mcp = mc ÷ fat       llp = ll ÷ fat
pe  = cf ÷ (mc ÷ rl) ÷ (1 − i)
```

Agregados sobre os meses com faturamento > 0:

```
tendência = regressão linear simples de llp contra o índice do mês
            slope = (n·Σxy − Σx·Σy) ÷ (n·Σx² − (Σx)²)
            unidade: pontos de margem por mês

sazonalidade: índice do mês = faturamento do mês ÷ faturamento médio
```

**Por que regressão e não "melhorou/piorou":** responde "está melhorando?" sem discussão de percepção. Slope de +0,026 ponto/mês = +0,31 ponto em 12 meses se nada mudar.

**Leitura obrigatória em percentual.** Faturamento crescente dilui o custo fixo automaticamente e faz o lucro absoluto subir enquanto a margem cai. O valor em reais esconde deterioração operacional por meses.

---

# 7. Margem por Obra — `calcObra()` / `obrasResumo()` ⭐ novo

O único módulo que olha para trás. É ele que calibra todos os outros.

## Por obra

```
imp   = preço × alíquota
com   = preço × comissão
dir   = Σ das 5 linhas orçáveis realizadas
falha = retrabalho + assistência          ← sem coluna de orçado, de propósito
real  = dir + falha

mcOrc  = preço − imp − com − custo orçado
mcReal = preço − imp − com − real

EROSÃO = (mcOrc − mcReal) ÷ preço          em pontos percentuais de preço
```

**Por que contribuição e não margem líquida:** custo fixo não pertence a obra nenhuma — existe com a fábrica parada. Ratear sem critério de consumo faz obra grande parecer ruim e obra pequena parecer boa, dependendo do critério inventado.

**Rateio opcional, e só com lastro:** `rateio = cdf × dias-frente` (de `calcCC`). Sem o Centro de Custo ligado, o módulo **não inventa rateio**.

**Por que retrabalho e assistência não têm orçado:** ninguém orça retrabalho. Todo real ali é 100% de estouro, e a soma é o custo da falta de processo em dinheiro.

## Consolidado

```
pR = Σ mcReal ÷ Σ preço          ponderada por receita, NUNCA média simples
pO = Σ mcOrc  ÷ Σ preço
dp = desvio padrão das margens realizadas

COBERTURA DA ESTRUTURA = pR ÷ cfp
```

**A correção de escala que a cobertura exige:** as obras lançadas nunca somam exatamente um mês de faturamento. Comparar a contribuição delas em R$ contra o custo fixo mensal em R$ compara **períodos diferentes** e acusa prejuízo onde não há. A comparação certa é livre de escala: margem realizada da carteira contra o peso do custo fixo no faturamento. Acima de 1, as obras pagam a estrutura.

```
MARGEM MÍNIMA = cfp + lucro alvo
```

**Não é a margem de Precificação.** Lá o percentual é lucro líquido, aplicado depois de material, MO e rateio de fixo. Aqui a conta é de contribuição, e o piso correto é o custo fixo como % do faturamento mais o lucro desejado. Trocar um pelo outro compara coisas diferentes.

## Padrão de erro

Por linha de custo, sobre todas as obras:

```
desvio total = Σ realizado − Σ orçado
frequência   = nº de obras em que estourou ÷ nº de obras
```

**A frequência importa mais que o valor.** Linha que estoura em mais de 60% das obras não é imprevisto — é premissa errada, e se corrige mudando a planilha, não cobrando do cliente.

## Corte por porte

Obras ordenadas por m², divididas na mediana. Margem ponderada de cada metade. Diferença acima de 5 pontos indica que obra pequena está sendo subsidiada: deslocamento, setup, medição e atendimento não caem na proporção do tamanho.

---

# 8. Fluxo de Caixa e Capital de Giro — `calcCx()` ⭐ novo

Duas perguntas separadas de propósito.

## Curto prazo — projeção de 13 semanas

```
saldo acumulado(k) = saldo inicial + Σ(entradas − saídas) até a semana k
semana de ruptura  = primeira com saldo acumulado < 0
```

**Regra:** só entra o que tem data. Venda provável não entra — se entrar desejo, a projeção vira ficção e o dono para de confiar nela, o que é pior que não ter.

## Estrutural — capital de giro

```
CICLO FINANCEIRO = PMR + PME − PMP                      dias
desembolso diário = (cv + cf) ÷ 30
NCG = ciclo × desembolso diário                         capital preso
SALDO DE TESOURARIA = caixa − NCG
custo anual do ciclo = NCG × taxa mensal × 12
DIAS DE CAIXA = caixa ÷ desembolso diário
```

**Tesouraria negativa significa que alguém financia a operação.** Três possibilidades: banco (você sabe, paga juros), fornecedor (atraso, cobrado no preço) ou o próximo cliente (adiantamento pagando obra antiga). A terceira quebra no primeiro mês de venda fraca — e até o dia anterior o caixa estava positivo.

**Faixa de dias de caixa:**

| Dias | Situação | Efeito no comportamento |
|---|---|---|
| < 15 | Crítico | Aceita qualquer obra, em qualquer preço |
| 15–30 | Apertado | Decide com medo, desconta para antecipar |
| 30–45 | Aceitável | Consegue recusar obra ruim |
| 45–90 | Confortável | Negocia preço sem pressa |

**A conexão que quase ninguém faz:** caixa curto destrói margem por comportamento, não por conta financeira. É o maior inimigo do preço.

**Ordem de ataque das alavancas:** prazo de fornecedor (quase de graça) → ciclo de produção (zero, mas é projeto) → prazo de recebimento (custa venda). A ordem inversa é a mais praticada.

---

# 9. Meta de Lucro e Desconto — `calcMeta()` ⭐ novo

## Do lucro para trás

```
alvo    = valor em R$, ou fatM × % desejado
fatNec  = (cf + alvo) ÷ mcp
gap     = fatNec − fatM
m2Nec   = fatNec ÷ preço médio por m²
obrasNec = fatNec ÷ ticket médio

CABE?  = capacidade de entrega (de calcSim) − m2Nec
```

**Meta que não cabe na capacidade não é meta — é desejo.** E não se resolve por esforço comercial: só por preço ou por gente.

## As quatro alavancas

Cada uma resolve o **mesmo** lucro alvo com as outras três congeladas. É o que torna a comparação honesta.

```
1. PREÇO     p = (alvo + cv + cf) ÷ (fatM × (1 − i)) − 1
2. VOLUME    q = (alvo + cf) ÷ mc − 1
3. CUSTO VAR r = 1 − (fatM × (1 − i) − cf − alvo) ÷ cv
4. CUSTO FIXO X = cf − (mc − alvo)                    em R$
```

**Por que preço é sempre a alavanca mais barata:** o aumento vai inteiro para a margem, menos o imposto. Não traz material, hora nem prazo junto. No cenário de exemplo, 5,4% de preço = 15,4% de volume — quase três para um.

## Desconto

Seja `m` a margem de contribuição e `d` o desconto. Com preço `P` e custo variável unitário `V`:

```
MC  = P − V           m = MC ÷ P
P'  = P(1 − d)
MC' = P(1 − d) − V = P(1 − d) − P(1 − m) = P(m − d)

MARGEM DEPOIS  = MC' ÷ P' = (m − d) ÷ (1 − d)
VOLUME EXTRA   = MC ÷ MC' − 1 = d ÷ (m − d)
DESCONTO QUE ZERA A MARGEM: d = m
```

**A última linha é a frase de aula:** o desconto máximo teórico é **exatamente igual** à margem de contribuição. Nesse ponto a obra não contribui com nada para a estrutura.

**A curva é exponencial, não linear** — é por isso que a intuição erra sempre para o mesmo lado. Com `m` = 42%:

| d | Margem depois | Volume extra |
|---|---|---|
| 3% | 40,2% | +7,7% |
| 5% | 38,9% | +13,5% |
| 8% | 37,0% | +23,5% |
| 10% | 35,6% | +31,3% |
| 15% | 31,8% | +55,6% |
| 20% | 27,5% | +90,9% |
| 42% | 0% | impossível |

---

# 10. Integridade do modelo

## Regras que não podem ser quebradas

1. **Folha de produção em `cf`, nunca em `cv`.** Quebra `pe`, `precoMin` e toda simulação.
2. **Margem, imposto e comissão no divisor.** Nunca somados ao custo.
3. **Rateio por capacidade, nunca por ocupação realizada.** Evita a espiral preço↑ → venda↓ → ocupação↓ → preço↑.
4. **Nada contado duas vezes.** Encarregado e PCP entram no custo-hora **ou** no rateio de fixo. `moCap` existe para isso.
5. **Margem ponderada por receita**, nunca média simples das margens.
6. **Comparações percentuais quando as escalas de período diferem.** Ver a cobertura da estrutura no módulo 7.
7. **Pró-labore lançado.** Sem ele, o preço é calculado como se o dono trabalhasse de graça.

## Teste de dupla contagem

```
Σ (custo-hora × horas orçadas de todas as obras do mês) + Σ rateio de fixo aplicado
                          ≤  custo total real do mês
```

Se ultrapassar, alguma coisa está sendo contada duas vezes — e é a origem mais comum da queixa "a mão de obra está inchada no orçamento".

## Chaves do banco (localStorage)

`carregar()` faz `Object.assign(vazio(), d)`, que é **raso**. Toda chave nova precisa ser de **primeiro nível**: chave aninhada dentro de uma existente (`fin`, `prec`, `pro`) seria engolida pelo objeto salvo do aluno e voltaria `undefined`.

| Chave | Módulo | Formato |
|---|---|---|
| `fin` | Diagnóstico Financeiro | `{fat[3], imposto, cv[8], cf[9]}` |
| `prec` | Precificação | `{mats[], mo, perda, conv, margem, comissao, cfix, hist[]}` |
| `cc` | Centro de Custo | `{on, fonte, base, diasUteis, frentes, ocup, dias, moCap}` |
| `pro` | Pró-labore | `{vida[10], func[], hSemana, encargos, ...}` |
| `sim` | Simulador | `{atual{}, simulado{}}` |
| `obras` ⭐ | Margem por Obra | `[{nome, cliente, m2, preco, dias, orc[5], real[7]}]` |
| `cx` ⭐ | Fluxo de Caixa | `{saldo, taxa, pmr, pme, pmp, sem[13]{e,s}}` |
| `meta` ⭐ | Meta de Lucro | `{modo, lucro, pct, precoM2, ticket}` |
| `dre12` ⭐ | Resultado Mensal | `{ini, imposto, m[12]{fat,cv,cf}}` |

`carregar()` normaliza o tamanho de `cx.sem` (13) e `dre12.m` (12) porque um arquivo importado truncado passaria pelo `Object.assign` e quebraria o render na primeira linha faltante.

---

# 11. Onde cada fórmula é ensinada

| Módulo do app | Fase 1 | Método |
|---|---|---|
| Diagnóstico Financeiro | M3 e M5 | REGRA DO RESTO · DRE DE UMA PÁGINA |
| Resultado Mensal ⭐ | M5 | DRE DE UMA PÁGINA |
| Margem por Obra ⭐ | M9 | ESPELHO |
| Fluxo de Caixa ⭐ | M10 | TORNEIRA |
| Meta de Lucro ⭐ | M8 e M13 | PORTEIRA |
| Precificação | M6 | CINCO CAMADAS |
| Simulador | M7 | M² DO GARGALO |
| Pró-labore | M13 | DOIS BOLSOS |
| Centro de Custo | M6 (camada 3) | CINCO CAMADAS |

⭐ = criado em 11/08/2026.

---

## Limites conhecidos do modelo

Vale declarar, porque mentorado esperto pergunta:

1. **A NCG usa o proxy clássico** `ciclo × desembolso diário`. É a aproximação didática padrão; a definição contábil rigorosa é ativo circulante operacional menos passivo circulante operacional. Para decidir prazo com fornecedor, o proxy basta.
2. **O Diagnóstico Financeiro usa 3 meses.** Não captura sazonalidade — é para isso que existe o Resultado Mensal de 12 meses.
3. **A tendência do DRE é regressão linear simples.** Com 3 ou 4 meses lançados ela é frágil. A partir de 8 meses, confiável.
4. **A alíquota de imposto é única e linear.** O Simples é progressivo por faixa; para preço, a alíquota efetiva média do ano é a aproximação correta — e é o que a Fase 1 M12 ensina a pedir ao contador.
5. **O rateio por dia-frente pressupõe frentes homogêneas.** Se uma frente é muito mais cara que outra (equipe grande × equipe pequena), o rateio distorce. A alternativa é rateio por m² de gargalo.
