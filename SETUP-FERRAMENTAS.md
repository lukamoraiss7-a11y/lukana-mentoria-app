# Ferramentas APM — o que falta para vender

**Publicado:** https://mentoria-app-self.vercel.app/ferramentas.html

O app está no ar e funcionando, mas em **modo local**: sem login, dados só no navegador. Serve para demonstrar numa call. Não serve para vender — hoje qualquer pessoa com o link usa de graça, e o mentorado perde tudo se trocar de navegador.

Falta um passo, e ele depende de contas suas.

---

## Passo único: ligar as contas de membro (~15 min)

### 1. Criar o projeto

Em [supabase.com](https://supabase.com), crie um projeto no plano gratuito. Região: **South America (São Paulo)**.

### 2. Criar a tabela

Painel do Supabase → **SQL Editor** → **New query** → cole o conteúdo de [`supabase-setup.sql`](supabase-setup.sql) → **Run**.

### 3. Pegar as duas chaves

**Project Settings → API**:

| Campo no painel | Vai no app como |
|---|---|
| *Project URL* — `https://xxxxx.supabase.co` | `url` |
| *anon public* — string longa `eyJ...` | `anon` |

A chave `anon` é **pública por natureza** — ela fica visível no HTML e é assim que tem que ser. A segurança vem do RLS que você criou no passo 2, que só deixa cada pessoa ler a própria linha.

**Nunca use a `service_role`.** Essa ignora o RLS e dá acesso aos dados de todos os membros. Se ela vazar, o estrago é total.

### 4. Preencher no app — sem Terminal

Abra direto no GitHub:

**https://github.com/lukamoraiss7-a11y/lukana-mentoria-app/edit/main/ferramentas.html**

Logo no começo do `<script>` está o bloco abaixo. Preencha as aspas:

```js
const CFG={
  url : 'https://xxxxx.supabase.co',
  anon: 'eyJhbGciOi...'
};
```

Role até o fim da página → **Commit changes**. A Vercel republica sozinha em ~1 minuto. Não precisa de token, nem de git, nem de Terminal.

### 5. Apontar o endereço de retorno

**Authentication → URL Configuration** → em *Site URL*, ponha:

```
https://mentoria-app-self.vercel.app/ferramentas.html
```

Sem isso, o link do e-mail leva a lugar nenhum.

### 6. Fechar a porta

Por padrão qualquer e-mail cria conta sozinho — o oposto do que você quer.

**Authentication → Providers → Email** → desligue **Allow new users to sign up**.

A partir daí só entra quem você cadastrar em **Authentication → Users → Add user**, conforme os mentorados pagarem.

---

## O limite que aparece na primeira turma

O e-mail de login sai pelo servidor gratuito do Supabase, limitado a **3 ou 4 mensagens por hora**. Cinco mentorados entrando aos poucos, passa liso. Trinta pessoas numa abertura de turma, a maioria não recebe o link e você ouve que o sistema não funciona.

Correção: SMTP próprio em **Authentication → Emails → SMTP Settings**. O [Resend](https://resend.com) tem 3.000 e-mails/mês grátis e leva uns 10 minutos para plugar.

Não é para hoje. É para **antes** de abrir turma.

---

## Como os dados ficam

Uma linha por membro, com o estado inteiro do app num JSON — sem tabela por módulo, então módulo novo não exige migração.

O navegador mantém uma cópia local. Se a internet cair no meio de um lançamento, nada se perde: o rodapé da barra lateral mostra o estado da sincronização e o envio é refeito quando a conexão volta.

O botão **Dados de exemplo** guarda uma cópia antes de sobrescrever, e o botão **Desfazer exemplo** devolve tudo. Ainda assim, oriente o mentorado a usar **Exportar** antes de qualquer teste — o desfazer é de um nível só.
