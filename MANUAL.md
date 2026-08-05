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

### 2. Configurar o SMTP (uma vez, 10 minutos) — **este é o bloqueio real**

O serviço de e-mail embutido do Supabase entrega **2 mensagens por hora no projeto
inteiro**. Como o login é por link no e-mail, uma turma de 20 pessoas levaria 10 horas
para entrar — e ninguém vê mensagem de erro, só uma caixa de entrada vazia.

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

Criar conta dá acesso **só às aulas**. É o nível 1.

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

## Os dois níveis, resumidos

| Nível | O que abre | Como se libera |
|---|---|---|
| **1 — Aulas** | Área de membros: trilha, 6 fases, materiais | Basta criar a conta |
| **2 — Ferramentas** | App de 10 módulos | `liberar_ferramentas(...)` na mão |

Um aluno sem o nível 2 que abrir o app de ferramentas vê "Seu plano não inclui as
ferramentas" e um botão de sair.

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

**Aluno não recebe o link** → quase sempre é o SMTP (passo 2). Se já estiver configurado,
peça para olhar em promoções e spam, e confirme que ele abre o e-mail na mesma máquina.

**O aluno entra nas ferramentas sem ter pago** → confira com `select * from public.acesso;`
se a linha dele está com `ferramentas = true` indevidamente.

**Publiquei e o aluno não vê** → peça para ele recarregar a página. O conteúdo é lido
na entrada.
