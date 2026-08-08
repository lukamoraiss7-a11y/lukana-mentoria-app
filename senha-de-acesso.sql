-- ═══════════════════════════════════════════════════════════════
-- SENHA DE ACESSO — o aluno entra de qualquer computador
--
-- Cole este arquivo inteiro no SQL Editor do Supabase e rode uma vez.
-- Painel → SQL Editor → New query → colar → Run.
--
-- Pode rodar de novo quantas vezes quiser: cria/substitui funções.
-- Não apaga conta, não apaga senha de ninguém, não mexe em fase.
--
-- Pré-requisitos já rodados: `supabase-setup.sql`, `fases-por-aluno.sql`
-- e `acesso-pelo-painel.sql`.
-- ═══════════════════════════════════════════════════════════════

-- POR QUE ISTO EXISTE
--
-- A área de membros só tinha link mágico por e-mail. Isso significa que
-- o acesso não é da CONTA, é do NAVEGADOR: o aluno entrou no computador
-- da fábrica, foi para casa, e precisa de outro e-mail. Somando o SMTP
-- padrão do Supabase (2 e-mails por hora no projeto inteiro), o aluno
-- fica na porta e o Luka vira porteiro manual — que é exatamente o
-- problema relatado.
--
-- Com senha, cadastrar já é liberar: o aluno entra de qualquer máquina,
-- quantas vezes quiser, sem passar por e-mail nenhum. O link mágico
-- continua existindo como plano B (esqueceu a senha).
--
-- Onde a senha é definida: painel Admin → aba Acessos. O Luka digita (ou
-- gera) e manda para o aluno pelo WhatsApp, junto com o link do app.

-- O `crypt`/`gen_salt` vive na extensão pgcrypto. No Supabase ela já vem
-- instalada no schema `extensions`; a linha abaixo é no-op nesse caso e
-- só serve para projeto novo que ainda não a tenha.
create extension if not exists pgcrypto with schema extensions;


-- ───────────────────────────────────────────────────────────────
-- DEFINIR A SENHA DE UM ALUNO (só admin)
--
-- Escreve direto em `auth.users.encrypted_password` com bcrypt custo 10,
-- que é o formato que o GoTrue (o servidor de login do Supabase) usa e
-- valida. É o mesmo efeito de trocar a senha pela tela, sem depender de
-- e-mail nenhum.
--
-- `security definer` porque `auth.users` não é acessível ao aluno. A
-- trava não é o GRANT — é o `if not exists ... admin` da primeira linha
-- do corpo: um aluno que descubra o nome da função e a chame pelo
-- console do navegador recebe exceção, não a senha de outra pessoa.
--
-- A função NUNCA lê nem devolve senha. Só escreve.
-- ───────────────────────────────────────────────────────────────
create or replace function public.admin_definir_senha(
  p_email text,
  p_senha text
)
returns text
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
declare
  v_id uuid;
begin
  if not exists (select 1 from public.acesso a
                  where a.user_id = auth.uid() and a.admin) then
    raise exception 'acao permitida apenas para administradores';
  end if;

  -- 8 é acima do mínimo do GoTrue (6) de propósito: senha que o Luka
  -- manda por WhatsApp e o aluno nunca troca merece folga.
  if p_senha is null or length(btrim(p_senha)) < 8 then
    raise exception 'a senha precisa de no minimo 8 caracteres';
  end if;

  select id into v_id from auth.users where lower(email) = lower(trim(p_email));
  if v_id is null then
    return 'nao encontrei conta com o e-mail ' || p_email ||
           ' — crie primeiro em Authentication > Users';
  end if;

  update auth.users
     set encrypted_password = extensions.crypt(btrim(p_senha),
                                               extensions.gen_salt('bf', 10)),
         -- Conta criada sem confirmar e-mail não faz login por senha.
         -- `coalesce` para não reescrever a data de quem já confirmou.
         email_confirmed_at = coalesce(email_confirmed_at, now()),
         updated_at         = now()
   where id = v_id;

  return 'senha definida para ' || p_email || ' — ele ja pode entrar de qualquer computador';
end $$;


-- ───────────────────────────────────────────────────────────────
-- QUEM TEM O QUÊ — agora com a coluna `tem_senha`
--
-- Substitui a versão de `acesso-pelo-painel.sql`. Precisa de `drop`
-- antes porque mudar o tipo de retorno não é `create or replace`.
-- O corpo é o mesmo, mais uma coluna: sem ela o Luka não tem como saber
-- de quem ainda depende de link por e-mail.
--
-- `tem_senha` é booleano derivado. O hash não sai daqui.
-- ───────────────────────────────────────────────────────────────
drop function if exists public.admin_listar_acessos();

create or replace function public.admin_listar_acessos()
returns table (email text, fases int[], ferramentas boolean, admin boolean, tem_senha boolean)
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if not exists (select 1 from public.acesso a
                  where a.user_id = auth.uid() and a.admin) then
    raise exception 'acao permitida apenas para administradores';
  end if;

  return query
    select u.email::text,
           coalesce((select array_agg((f::int + 1) order by f::int)
                       from unnest(a.fases) f), '{}'::int[]),
           coalesce(a.ferramentas,false),
           coalesce(a.admin,false),
           (u.encrypted_password is not null and u.encrypted_password <> '')
      from auth.users u
      left join public.acesso a on a.user_id = u.id
     order by u.email;
end $$;


-- `anon` (visitante sem login) nunca. `authenticated` pode chamar — e
-- leva exceção se não for admin.
revoke all on function public.admin_definir_senha(text, text) from public, anon;
revoke all on function public.admin_listar_acessos()          from public, anon;
grant execute on function public.admin_definir_senha(text, text) to authenticated;
grant execute on function public.admin_listar_acessos()          to authenticated;


-- ═══════════════════════════════════════════════════════════════
-- CONFERÊNCIA — rode depois e olhe o resultado.
-- ═══════════════════════════════════════════════════════════════
-- 1. Quem já entra por senha e quem ainda depende de e-mail:
--    select email, tem_senha, fases, ferramentas from public.admin_listar_acessos();
--
-- 2. As duas precisam vir com aluno_executa = true — a proteção está
--    dentro do corpo, não no GRANT:
--    select p.proname, has_function_privilege('authenticated', p.oid, 'execute') as aluno_executa
--      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
--     where n.nspname='public' and p.proname in ('admin_definir_senha','admin_listar_acessos');
--
-- 3. Definir a senha de alguém sem passar pelo painel (o painel faz isto):
--    select public.admin_definir_senha('aluno@email.com','umaSenhaBoa123');
--
-- ═══════════════════════════════════════════════════════════════
-- VOLTAR ATRÁS
-- ═══════════════════════════════════════════════════════════════
-- A tela de login continua oferecendo o link por e-mail, então derrubar
-- a função não tranca ninguém para fora — só volta a depender de e-mail.
--   drop function if exists public.admin_definir_senha(text,text);
-- Para a lista voltar ao formato antigo (sem `tem_senha`), rode de novo
-- o `acesso-pelo-painel.sql` — o front tolera as duas versões.
-- ═══════════════════════════════════════════════════════════════
