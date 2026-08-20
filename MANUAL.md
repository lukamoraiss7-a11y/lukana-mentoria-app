# Manual de operação — App Mentoria APM

Tudo que você precisa fazer para abrir uma turma, na ordem.
Endereço: **mentoria-app-self.vercel.app**

---

## Antes da primeira turma — três coisas, nesta ordem

### 1. Rodar o SQL — ✅ **FEITO em 05/08/2026**

Já executado em produção e conferido: as três tabelas com RLS ligado, as três funções
fora do alcance dos alunos, e `lukamoraiss7@gmail.com` como admin. **Não precisa rodar
de novo** — o passo abaixo fica como referência para reinstalar ou conferir.

Sem isso o app de ferramentas bloqueia todo mundo — de propósito, porque liberar
quando o banco falha vira porta aberta silenciosa.

1. Abra o painel do Supabase → projeto `frqoxmerrfucprtgvghm`
2. Menu lateral → **SQL Editor** → **New query**
3. Abra o arquivo `supabase-setup.sql` do repositório, copie **tudo**, cole e clique em **Run**

Pode rodar de novo quantas vezes quiser: o script não duplica nada.

**Confira** se deu certo, no mesmo SQL Editor:

```sql
select tablename, rowsecurity from pg_tables
 where tablename in ('dados','acesso','conteudo');
```

As três linhas precisam vir com `rowsecurity = true`. Se vier `false` em alguma, os
dados de um aluno ficam visíveis para os outros — pare e me chame.

### 1-B. Rodar os dois SQL novos — ✅ **FEITO em 08/08/2026**

Rodados em produção em 08/08/2026 e conferidos. **Não precisa rodar de novo** — ficam
como referência para reinstalar.

| Arquivo | O que passou a funcionar |
|---|---|
| `senha-de-acesso.sql` | O campo **Senha de acesso** no painel, e a coluna "sem senha" na lista. |
| `ementa-por-fase.sql` | A lista do que já está publicado dentro da fase fechada, e os números de material da vitrine. **Substitui o `contagem-por-fase.sql`** — as duas funções estão nele. |

Conferência de 08/08: as quatro funções (`admin_definir_senha`, `admin_listar_acessos`,
`ementa_por_fase`, `contagem_por_fase`) existem, todas `security definer`, todas
executáveis por aluno logado e **nenhuma** por visitante anônimo. A trava de admin de
`admin_definir_senha` foi testada e recusa até chamada com poder de `postgres`.

### 1-C. Rodar o `progresso.sql` — ⬜ **PENDENTE**

Um arquivo só, uma vez: `mentoria-app/progresso.sql`. Painel do Supabase → SQL Editor →
New query → colar → Run.

Cria a tabela `public.progresso` (uma linha por aluno) com RLS: cada um lê e escreve
só a própria linha.

**O app não quebra sem ela.** Sem a tabela, o andamento — quais aulas o aluno já abriu,
quais itens do checklist ele já marcou — fica guardado no navegador dele e nada mais.
O que a tabela resolve é o mesmo problema que a senha resolveu em 08/08: o acesso passou
a ser da conta, e o progresso precisa seguir a conta também. Sem ela, quem abre a aula no
computador da fábrica e depois entra pelo celular vê a barra voltar a zero.

Quando a tabela entra, o que já estava no navegador **soma** com o que está no servidor —
não substitui. Ninguém perde o que já leu.

### 2. Configurar o SMTP (uma vez, 10 minutos) — **deixou de ser bloqueio**

O serviço de e-mail embutido do Supabase entrega **2 mensagens por hora no projeto
inteiro**. Isso era fatal enquanto o único jeito de entrar era o link no e-mail: uma
turma de 20 pessoas levaria 10 horas para entrar, sem ver erro nenhum.

**Com o login por senha (08/08/2026) isso saiu do caminho crítico** — você define a
senha no painel e manda por WhatsApp, sem e-mail nenhum na jogada. O SMTP continua
valendo a pena para o aluno recuperar acesso sozinho pelo link, mas já não trava a
abertura da turma.

1. Crie conta no **resend.com** (grátis, 3.000 e-mails/mês — sobra para 20 alunos)
2. No Resend: **Domains** → **Add Domain** → `lukana.com.br`. Ele mostra 3 registros
   de DNS (SPF, DKIM, e um de retorno). Cole no painel onde o domínio está registrado
   e espere ficar **Verified** — costuma levar de 10 minutos a algumas horas.
   *Sem domínio verificado o Resend só entrega para o e-mail da sua própria conta*,
   o que serve para testar e não serve para turma.
3. No Resend: **API Keys** → **Create API Key** → copie a chave (`re_...`)
4. No Supabase: **Authentication** → **Emails** → **SMTP Settings** → ligue **Enable Custom SMTP**
   - Host: `smtp.resend.com`
   - Porta: `465`
   - Usuário: `resend`
   - Senha: a chave que você copiou
   - Sender email: `nao-responda@lukana.com.br`
   - Sender name: `Mentoria APM`
5. Salve. **Só agora** vá em **Authentication → Rate Limits** e suba "emails per hour"
   para 100.

> A ordem do passo 5 não é frescura: o Supabase **recusa** mudar esse limite enquanto
> não houver SMTP próprio, com a mensagem `Custom SMTP required to configure
> RATE_LIMIT_EMAIL_SENT`. Testado pela API em 10/08/2026. Enquanto o serviço embutido
> estiver no lugar, são 2 e-mails por hora **no projeto inteiro** e não há como
> aumentar — nem pelo painel, nem por API.

**Não abra turma sem isso.** É a falha que estraga o primeiro dia.

### 2-B. Se VOCÊ ficar sem acesso — atalho que não passa por e-mail

Aconteceu em 10/08/2026: sem a senha do admin, o "Send password recovery" do painel
bateu em `email rate limit exceeded` e não havia como entrar. O caminho abaixo gera o
mesmo link do e-mail, **sem enviar e-mail nenhum**, então o limite não se aplica.

Precisa de um token pessoal (Supabase → Account → **Access Tokens** → Generate).
**Revogue assim que terminar** — ele abre a conta inteira, não só este projeto.

```bash
SBT='sbp_...'                       # token pessoal, revogar depois
REF='frqoxmerrfucprtgvghm'
SR=$(curl -s -H "Authorization: Bearer $SBT" \
  "https://api.supabase.com/v1/projects/$REF/api-keys?reveal=true" \
  | python3 -c "import sys,json;print(next(k['api_key'] for k in json.load(sys.stdin) if k['name']=='service_role'))")

curl -s -X POST "https://$REF.supabase.co/auth/v1/admin/generate_link" \
  -H "apikey: $SR" -H "Authorization: Bearer $SR" -H "Content-Type: application/json" \
  -d '{"type":"recovery","email":"lukamoraiss7@gmail.com",
       "options":{"redirect_to":"https://mentoria-app-self.vercel.app"}}' \
  | python3 -c "import sys,json;print(json.load(sys.stdin)['action_link'])"
```

O link é de **uso único, válido por 1 hora**, e enquanto vale abre a conta sem senha —
não repasse. Clicar nele cai na área de membros com "Definir senha" já aberta.

Serve para qualquer conta, não só a sua: trocando o e-mail, resolve o aluno travado
sem gastar a cota de envio.

**Depois de entrar, defina uma senha e não fique sem.** O buraco não foi o Supabase —
foi depender de e-mail para entrar na própria casa.

### 3. Tornar sua conta administradora — ✅ **FEITO em 05/08/2026**

`lukamoraiss7@gmail.com` já é admin e já tem as ferramentas. Para tornar outra conta
admin no futuro:

```sql
select public.tornar_admin('outro@email.com');
```

---

## O dia a dia

### Criar a conta de um aluno

Supabase → **Authentication** → **Users** → **Add user** → **Create new user**

- Preencha e-mail e uma senha qualquer
- Marque **Auto Confirm User**
- **Não** use "Send invite" — isso dispara e-mail e queima cota

Criar conta só deixa **entrar**. Sem liberar fase, ele vê a trilha inteira bloqueada.
O passo seguinte é obrigatório.

### Definir a senha dele — é isto que faz o acesso ser da conta, não do computador

Menu lateral → **Admin** → aba **Acessos** → bloco **Senha de acesso**.

1. O e-mail é o mesmo do campo de cima
2. **Gerar** (ou digite uma, mínimo 8 caracteres)
3. **Definir senha**
4. **Mandar no WhatsApp** — abre a conversa com o endereço, o e-mail e a senha
   prontos. Você escolhe o contato e aperta enviar.

Com senha o mentorado entra **de qualquer computador, quantas vezes quiser**. Sem
senha ele depende de um link por e-mail que vale uma vez e só no navegador em que
abriu a caixa de entrada — foi o que fazia você virar porteiro manual.

Na lista "Quem tem o quê", quem ainda não tem senha aparece marcado em vermelho como
**sem senha (só entra por link)**.

O aluno pode trocar a senha depois: barra lateral → **Definir senha**.

> A senha só é gravada, nunca lida. Nem o painel nem o banco devolvem a senha de
> ninguém — perdeu, você gera outra.

### Liberar as fases que o aluno comprou — **pelo painel**

Menu lateral → **Admin** → aba **Acessos**.

1. Digite o e-mail do mentorado (a conta já precisa existir no Supabase)
2. Marque as fases que ele comprou — em qualquer combinação: só a 1; 1, 3 e 5; só a 4
3. Marque **App Ferramentas APM** se ele comprou o app
4. **Salvar acesso**

Embaixo, "Quem tem o quê" lista todas as contas com o que cada uma tem. O botão
**Editar** carrega a pessoa no formulário — mude o que precisa e salve de novo.

**O que estiver desmarcado é retirado.** O formulário é o retrato final do acesso da
pessoa, não um acréscimo. Vendeu a Fase 2 para quem já tinha a 1? Deixe a 1 marcada
também.

O app é vendido à parte e combina com qualquer coisa: só o app sem fase nenhuma, ou app
mais as fases que você quiser.

**Pelo SQL Editor também funciona**, se preferir ou se o painel estiver fora do ar:

```sql
select public.liberar_fases('aluno@email.com', '{1,3}');
select public.bloquear_fases('aluno@email.com');
select * from public.listar_acessos();
```

O aluno continua vendo na trilha as fases que não comprou — legíveis e douradas, com o
selo **Liberar**. Clicando, ele vê o que a fase cobre, os entregáveis **e a lista do
que já está publicado lá dentro**, título por título, cada um com cadeado e o aviso
"não abre no seu plano". É de propósito: ler "Planilha de Precificação por m²" trancada
vende a fase; a descrição, o link e o arquivo continuam presos no banco.

O mesmo vale para o app de ferramentas: quem não comprou **entra em modo demonstração**
— vê os 10 módulos funcionando com números de exemplo, e todo campo está travado. Nada
que ele digite é salvo, nem no navegador nem no servidor.

Material que você cadastrar como **Geral** aparece para todo aluno, tenha ele qualquer
fase. Use isso para recado e documento que vale para a turma inteira.

Você (admin) vê todas as fases sempre, mesmo com a lista vazia.

### Incluir ou tirar um arquivo de uma fase

Entre com a sua conta, menu lateral → **Admin** → aba **Materiais**. Os 23 arquivos
das fases estão listados lá, cada um com a fase a que pertence e um **✕** para remover.

Para incluir: preencha nome, URL, descrição, escolha o tipo e a fase, e clique em
Adicionar Material. Ele aparece na hora para todo aluno que tenha aquela fase.

**Hoje o campo é URL, não upload.** Para uma ferramenta nova você precisa de um
endereço que já exista — um link do Drive, por exemplo. Upload direto pelo painel entra
junto com o bucket privado (ver a seção seguinte).

Se escolher **Geral (todas as fases)**, o arquivo aparece para qualquer aluno,
independente do que ele comprou.

### Publicar uma fase inteira de uma vez

> **O nome do arquivo decide se aquilo é aula.** A barra de andamento do aluno conta
> só os módulos escritos: arquivo `f<fase>-<numero>-titulo.html` que subiu para o
> bucket (`f1-00-…`, `f4-13-…`). Todo o resto — planilha, PDF, contrato, checklist de
> campo, fluxograma — entra como **material de apoio** e não mexe na barra. É de
> propósito: contrato baixado não é aula estudada, e sem essa separação a Operação
> marcaria progresso porque alguém abriu o contrato de CLT. Consequência prática: aula
> publicada com outro padrão de nome aparece na fase, abre normal, mas não conta.
> O `publicar-fase.py` já nomeia certo — é mais um motivo para publicar por ele.

Quando os HTMLs de uma fase ficam prontos em `mentoria-conteudo/publicar/`, existem
dois caminhos. **Os dois gravam na mesma pasta do bucket:** o número da fase **menos 1**
(Fase 1 → `0/`, Fase 4 → `3/`). Errar isso publica na pasta errada e o RLS bloqueia
justamente o aluno que comprou — falha silenciosa, só aparece quando ele reclama.

**Caminho 1 — pelo painel (2 minutos, sem chave nenhuma)**

1. Entre com a sua conta → **Admin** → aba **Materiais**
2. Em *Subir arquivo*, clique no campo e selecione **todos** os `f2-*.html` de uma vez
3. Escolha a fase no seletor. Deixe nome e descrição **em branco** — com vários
   arquivos, cada um pega o próprio nome do `<title>` do HTML
4. Clique em Subir. Ele mostra "Subindo 3 de 16…" e no fim "16 materiais publicados"

> ⚠️ **Só clique uma vez.** `publicar()` é `insert` puro, sem upsert, e a lista não
> deduplica. Clicar de novo cria 16 cards duplicados — foi exatamente assim que a
> a antiga Fase 5 ficou com 34 registros para 18 nomes em 07/08/2026. Se a barra travar,
> confira a aba Materiais **antes** de tentar de novo.

**Caminho 2 — pelo script (idempotente, pode rodar de novo sem medo)**

`publicar-fase.py` faz o mesmo, mas lê o que já existe antes de gravar e pula o que
já está lá. É o caminho para republicar sem risco de duplicar.

```bash
export SUPABASE_SERVICE_KEY='eyJ...'     # Project Settings → API → service_role
python3 publicar-fase.py 2 --dry-run     # confere sem gravar nada
python3 publicar-fase.py 2               # publica
```

A chave `service_role` ignora o RLS por definição — **rotacione depois de usar**, no
mesmo lugar de onde você a copiou.

**Depois de publicar, confira a contagem** na aba Materiais. Se o número não for o
esperado, houve duplicação: apague os excedentes pelo ✕ antes de qualquer outra coisa.

### O que ainda não está trancado nos arquivos

A lista respeita a fase comprada: quem não tem a Fase 3 não recebe o PCP do banco, nem
vê o card. Mas o arquivo em si continua acessível por URL direta — quem tiver o link de
`/files/pcp_simplificado_pro.xlsx` baixa sem estar logado.

Fechar isso é mover os arquivos para um bucket privado do Supabase Storage, com pasta
por fase e link assinado que expira. É a mesma mudança que traz o upload pelo painel.

### Liberar as ferramentas para quem pagou o upsell

SQL Editor:

```sql
select public.liberar_ferramentas('aluno@email.com', 'Nome do Aluno');
```

Para tirar o acesso:

```sql
select public.bloquear_ferramentas('aluno@email.com');
```

Para ver quem tem o quê:

```sql
select * from public.acesso;
```

Você não precisa procurar código nenhum de usuário — é pelo e-mail.

### Publicar aula, material, link ou recado

Entre na área de membros com a sua conta de admin. Aparece **Admin** no menu lateral.

Cada aba publica um tipo:

| Aba | Serve para | Onde aparece para o aluno |
|---|---|---|
| Materiais | Arquivo ou planilha | Na aba Materiais e dentro da fase |
| Vídeos | Aula gravada (Vimeo, YouTube) | Dentro da fase escolhida |
| Links | Comunidade, formulário, ferramenta | Dentro da fase escolhida |
| Comentários | Recado seu para a turma | Dentro da fase, como "Notas do Instrutor" |

O que você publica **vai para todos os alunos na hora**. Antes de 05/08/2026 isso não
era verdade: ficava salvo só no seu navegador e nenhum aluno via.

---

## Os níveis, resumidos

| Nível | O que abre | Como se libera |
|---|---|---|
| **1 — Entrar** | A área de membros, a trilha e o que for cadastrado como Geral | Criar a conta **e definir a senha** |
| **2 — Fases** | As aulas, materiais e notas das fases compradas | Painel → Acessos (ou `liberar_fases(email,'{1,3}')`) |
| **3 — Ferramentas** | App de 10 módulos, editável | Painel → Acessos, caixa do App |

Um aluno sem o nível 3 que abrir o app de ferramentas **entra em modo demonstração**:
vê os 10 módulos com números de exemplo e não consegue digitar em campo nenhum. Uma
fase fora do nível 2 aparece na trilha em dourado, com o selo **Liberar**, e abre a
tela de venda com a lista do que está publicado lá dentro.

**Criar a conta não libera aula nenhuma.** Desde 06/08/2026 é preciso rodar
`liberar_fases` também — se esquecer, o aluno entra e não vê aula, e vai achar que
quebrou.

---

## O que ainda está aberto, e você precisa saber

**Os arquivos são públicos por URL.** O login protege a navegação, não o arquivo. Quem
receber o link direto de uma planilha ou de um documento baixa sem ser aluno. Vale para
os 12 documentos e para as 9 planilhas, desde sempre.

Duas saídas, quando você quiser decidir:
- **Aceitar** — você vende a mentoria, não o PDF. É o mais comum nesse mercado.
- **Fechar** — mover os arquivos para o Storage privado do Supabase e servi-los com
  link assinado que expira. Exige subir os arquivos no painel e mudar o código.

**Faltam ~21 dos 34 documentos** prometidos no texto das fases. Cinco já estão prontos
no seu computador e só não subiram.

**O `.gitignore` bloqueia PDF e DOCX.** Enquanto estiver assim, arquivo desses tipos
entra no repositório mas nunca chega ao ar: o card aparece e o download dá 404. Foi o
que aconteceu com o FAB — Maquinário. Precisa liberar antes de publicar qualquer PDF.

**Quatro divergências nos contratos** seguem com o advogado: CNPJ em duas versões, CPF
em duas versões, garantia de 6 contra 10 anos, e o contrato de cliente emitido por outra
empresa.

---

## Se der problema

**"Acesso indisponível" no app de ferramentas** → o SQL não foi rodado. Volte ao passo 1.

**Aluno entrou e não vê aula nenhuma** → falta o `liberar_fases` dele. Confira com
`select * from public.listar_acessos();` — se a coluna `fases` estiver vazia, é isso.

**Aluno diz "não consigo entrar" / "pede link de novo em outro computador"** → ele não
tem senha. Painel → Acessos → **Senha de acesso** → Gerar → Definir senha → mandar por
WhatsApp. Resolve de uma vez, para qualquer máquina.

**"E-mail ou senha incorretos"** → ou a senha está errada, ou a conta nunca teve senha
(o Supabase responde igual nos dois casos, de propósito). Gere outra senha no painel.

**O botão Definir senha diz que falta rodar SQL** → falta o `senha-de-acesso.sql`
(passo 1-B).

**Fase fechada não mostra a lista do que tem dentro** → falta o `ementa-por-fase.sql`
(passo 1-B).

**Aluno não recebe o link** → quase sempre é o SMTP (passo 2). Se já estiver configurado,
peça para olhar em promoções e spam, e confirme que ele abre o e-mail na mesma máquina.
Mas o caminho curto é senha, não link.

**`email rate limit exceeded` ao mandar recuperação** → são os 2 e-mails por hora do
serviço embutido, contados no projeto todo (janela móvel: libera ~1h depois do último
envio). Não espere: gere o link direto pela API, sem e-mail — passo **2-B**.

**O link do e-mail cai na tela errada** → era a Site URL apontando para
`ferramentas.html` com a lista de Redirect URLs **vazia**, o que fazia o Supabase
descartar todo `emailRedirectTo` e mandar tudo para o app. Corrigido em 10/08/2026:
Site URL `https://mentoria-app-self.vercel.app`, Redirect URLs
`https://mentoria-app-self.vercel.app/**`. Se voltar a acontecer, é aí que se olha.

**O aluno entra nas ferramentas sem ter pago** → confira com `select * from public.acesso;`
se a linha dele está com `ferramentas = true` indevidamente.

**Publiquei e o aluno não vê** → peça para ele recarregar a página. O conteúdo é lido
na entrada.
