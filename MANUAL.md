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

### 1-B. Rodar os dois SQL novos — ⏳ **PENDENTE (08/08/2026)**

Dois arquivos, um Run cada, no mesmo SQL Editor. Podem rodar em qualquer ordem e
quantas vezes quiser.

| Arquivo | O que passa a funcionar |
|---|---|
| `senha-de-acesso.sql` | O campo **Senha de acesso** no painel. Sem ele, o botão avisa que falta rodar. |
| `ementa-por-fase.sql` | A lista do que já está publicado dentro da fase fechada, e os números de material da vitrine. **Substitui o `contagem-por-fase.sql`** — as duas funções estão nele. |

Enquanto não rodar, o app não quebra: o campo de senha recusa com uma mensagem
dizendo o que falta, e a fase fechada volta a aparecer sem a lista de títulos.

### 2. Configurar o SMTP (uma vez, 10 minutos) — **deixou de ser bloqueio**

O serviço de e-mail embutido do Supabase entrega **2 mensagens por hora no projeto
inteiro**. Isso era fatal enquanto o único jeito de entrar era o link no e-mail: uma
turma de 20 pessoas levaria 10 horas para entrar, sem ver erro nenhum.

**Com o login por senha (08/08/2026) isso saiu do caminho crítico** — você define a
senha no painel e manda por WhatsApp, sem e-mail nenhum na jogada. O SMTP continua
valendo a pena para o aluno recuperar acesso sozinho pelo link, mas já não trava a
abertura da turma.

1. Crie conta no **resend.com** (grátis, 3.000 e-mails/mês — sobra para 20 alunos)
2. No Resend: **API Keys** → **Create API Key** → copie a chave
3. No Supabase: **Authentication** → **Emails** → **SMTP Settings** → ligue **Enable Custom SMTP**
   - Host: `smtp.resend.com`
   - Porta: `465`
   - Usuário: `resend`
   - Senha: a chave que você copiou
   - Sender email: um e-mail do seu domínio
4. Salve. Depois vá em **Authentication → Rate Limits** e suba o limite de e-mails
   por hora para algo como 100.

**Não abra turma sem isso.** É a falha que estraga o primeiro dia.

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

### O que ainda não está trancado nos arquivos

A lista respeita a fase comprada: quem não tem a Fase 4 não recebe o PCP do banco, nem
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

**O aluno entra nas ferramentas sem ter pago** → confira com `select * from public.acesso;`
se a linha dele está com `ferramentas = true` indevidamente.

**Publiquei e o aluno não vê** → peça para ele recarregar a página. O conteúdo é lido
na entrada.
