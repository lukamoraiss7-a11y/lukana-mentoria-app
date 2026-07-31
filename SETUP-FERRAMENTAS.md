# Ferramentas APM — o que falta para vender

O app está pronto e funcionando. Faltam três coisas que dependem de contas suas — eu não consigo criar conta nem autenticar no seu nome.

Enquanto você não fizer o passo 2, o app funciona **em modo local**: sem login, salvando só no navegador. É o modo em que você validou. Serve para demonstração, não para venda.

---

## 1. Publicar (2 min) — destrava o link

O commit já está feito na branch `main`. O push falhou por falta de permissão do token guardado no Mac.

```bash
cd "/Users/institutogianini/Documents/Claude - Workspace/mentoria-app" && git push origin main
```

Se pedir senha: use um **Personal Access Token** do GitHub com escopo `repo`, não a senha da conta (github.com → Settings → Developer settings → Personal access tokens).

Se recusar de novo, apague a credencial velha e tente outra vez:

```bash
printf "protocol=https\nhost=github.com\n\n" | git credential-osxkeychain erase
```

A Vercel publica sozinha depois do push. O app fica em `/ferramentas.html`.

---

## 2. Ligar as contas de membro (15 min) — destrava a venda

Sem isto, duas coisas quebram o modelo: **qualquer um com o link usa de graça**, e **o membro perde tudo se trocar de navegador**.

**2.1** Crie um projeto em [supabase.com](https://supabase.com) — plano gratuito. Escolha a região `South America (São Paulo)`.

**2.2** Rode o SQL: painel do Supabase → **SQL Editor** → **New query** → cole o conteúdo de [`supabase-setup.sql`](supabase-setup.sql) → **Run**.

**2.3** Pegue as duas chaves em **Project Settings → API**:
- *Project URL* → algo como `https://abcdefgh.supabase.co`
- *anon public* → uma string longa começando em `eyJ...`

**2.4** Abra `ferramentas.html`, ache o bloco `const CFG` (logo no começo do `<script>`) e preencha:

```js
const CFG={
  url : 'https://abcdefgh.supabase.co',
  anon: 'eyJhbGciOi...'
};
```

A chave `anon` é pública por design — ela vai no HTML e qualquer um consegue ler. A segurança vem do RLS que você criou no passo 2.2, que só deixa cada pessoa ler a própria linha. **Nunca** coloque aqui a chave `service_role`: essa ignora o RLS e dá acesso a tudo.

**2.5** Em **Authentication → URL Configuration**, ponha em *Site URL*:
`https://mentoria-app-self.vercel.app/ferramentas.html`

**2.6** Em **Authentication → Providers → Email**, deixe ligado. Desligue *Confirm email* só se quiser entrada imediata.

**2.7** Faça commit e push de novo. Pronto — a partir daí o app exige login.

### Controlar quem entra

Por padrão, qualquer e-mail consegue criar conta. Para vender, você quer o contrário: em **Authentication → Providers → Email**, desligue **Allow new users to sign up**. Aí só entra quem você cadastrar na mão em **Authentication → Users → Add user**, à medida que os mentorados pagarem.

---

## 3. O limite que sobra (decidir depois)

O e-mail de login sai pelo servidor gratuito do Supabase, que **limita a 3 ou 4 mensagens por hora**. Para 5 ou 10 mentorados entrando aos poucos, passa. No dia em que você abrir uma turma e 30 pessoas tentarem entrar juntas, a maioria não recebe o link e você vai ouvir que "o sistema não funciona".

A correção é plugar um serviço de e-mail próprio (Resend tem plano gratuito de 3.000/mês) em **Authentication → Emails → SMTP Settings**. Não é urgente hoje. É urgente antes da primeira turma.

---

## Como os dados ficam organizados

Uma linha por membro, com o estado inteiro do app num JSON. O navegador continua guardando uma cópia local: se a internet cair no meio de um lançamento, nada se perde — o rodapé da barra lateral mostra o estado da sincronização, e o envio é refeito quando a conexão volta.
