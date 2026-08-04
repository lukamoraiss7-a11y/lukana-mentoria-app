# Ferramentas APM — manual de operação

**No ar:** https://mentoria-app-self.vercel.app/ferramentas.html
**Projeto Supabase:** `frqoxmerrfucprtgvghm`

A instalação está feita. Este documento é o que você usa daqui pra frente.

---

## Liberar acesso a quem pagou

O cadastro aberto está **desligado** — ninguém entra sozinho. Para cada mentorado novo:

1. Abra https://supabase.com/dashboard/project/frqoxmerrfucprtgvghm/auth/users
2. **Add user** → **Send invitation** → e-mail da pessoa

Ela recebe um convite, clica e cai dentro do app já logada. Não precisa criar senha.

Se aparecer só **Create new user**: ponha o e-mail, invente qualquer senha (ela nunca vai usar — entra por link) e marque **Auto Confirm User**.

## Tirar acesso de quem saiu

Mesma tela, três pontinhos ao lado do usuário → **Delete user**. Os dados dele vão junto (a tabela tem `on delete cascade`).

Se quiser preservar o histórico, use **Ban user** em vez de apagar.

---

## Antes de abrir turma: resolver o e-mail

O plano gratuito do Supabase entrega **3 a 4 e-mails de login por hora**. Com mentorados entrando aos poucos, passa. Com trinta pessoas entrando no mesmo dia, a maioria não recebe o link — e vai concluir que a ferramenta está quebrada, não que o e-mail está na fila.

**Correção:** SMTP próprio em Authentication → Emails → SMTP Settings. O [Resend](https://resend.com) tem 3.000 e-mails/mês grátis e leva uns 10 minutos.

Faça isso **antes** da primeira turma, não durante.

---

## Como os dados funcionam

Uma linha por membro na tabela `dados`, com o estado inteiro do app num JSON. Sem tabela por módulo — módulo novo não exige migração.

O navegador guarda uma cópia local. Se a internet cair no meio de um lançamento, nada se perde: o rodapé da barra lateral mostra o estado da sincronização e o envio é refeito quando a conexão volta.

**Cada conta é um mundo isolado.** O mentorado A não alcança nada do B — a política de acesso do banco compara o dono da linha com quem está logado, e o Postgres nega tudo que nenhuma política libere.

Isso também significa que **duas pessoas da mesma empresa não compartilham dados**. Ver a seção final.

## Se um membro disser que perdeu dados

1. Peça um print do rodapé da barra lateral. Se disser **"Dados salvos só neste navegador"** em vez de **"Sincronizado"**, ele não está logado — está usando o app como visitante.
2. Se disser **"Falha ao sincronizar"**, é rede ou queda do Supabase. Os dados estão no navegador dele; volta sozinho quando a conexão normalizar.
3. O botão **Dados de exemplo** apaga o que foi lançado. Existe **Desfazer exemplo** ao lado, mas é de um nível só. Oriente a usar **Exportar** antes de qualquer teste.

---

## Mexer no código

O push por Terminal **voltou a funcionar em 04/08/2026** — o token está no keychain do iMac e expira por volta de novembro/2026. Quando voltar o erro `could not read Username`, é ele: gere outro em github.com → Settings → Developer settings → Tokens classic, escopo `repo`, e use no primeiro push.

Alternativa sem Terminal, pelo editor web:
https://github.com/lukamoraiss7-a11y/lukana-mentoria-app/edit/main/ferramentas.html

A Vercel republica sozinha a cada commit em `main`.

**Nunca coloque a chave `sb_secret_` no código.** Ela ignora a trava de segurança e daria acesso aos dados de todos os membros. A que está lá (`sb_publishable_`) é pública por natureza e não tem problema.

---

## Limitação conhecida: um app, uma pessoa

Cada conta tem seu próprio conjunto de dados. Isso está **certo** para vender a marceneiros individuais.

Está **errado** para uso interno na Lukana: KPI, Kanban e PCP são dados da empresa, não da pessoa. Do jeito que está, Luka lançaria os ambientes na conta dele e Matheus não veria nada na dele — cada um alimentando uma base paralela, que é exatamente o problema que a ferramenta existe para matar.

Dimensionamento da mudança em `memory/projects/app-ferramentas-apm.md`. Resumo: banco e políticas são meio dia, mas o modelo de JSON único não sobrevive a duas pessoas editando ao mesmo tempo — sobrescrita silenciosa. Fazer certo significa reescrever a camada de persistência.
