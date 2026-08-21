-- ═══════════════════════════════════════════════════════════════
-- ACOMPANHAMENTO DO ALUNO — quando entrou e o que abriu
--
-- Cole este arquivo inteiro no SQL Editor do Supabase e rode uma vez.
-- Painel → SQL Editor → New query → colar → Run.
--
-- Pode rodar de novo quantas vezes quiser: cria/substitui funções e
-- acrescenta uma coluna. Não apaga conta, não apaga andamento, não
-- mexe em fase nem em senha.
--
-- Pré-requisitos já rodados: `supabase-setup.sql`, `fases-por-aluno.sql`,
-- `acesso-pelo-painel.sql`, `senha-de-acesso.sql` e `progresso.sql`.
-- ═══════════════════════════════════════════════════════════════

-- POR QUE ISTO EXISTE
--
-- O andamento do aluno já era gravado desde 20/08/2026 (`public.progresso`),
-- mas o RLS daquela tabela prende cada linha ao próprio dono: as três
-- políticas são `auth.uid() = user_id`. Isso é o desenho certo — nenhum
-- aluno lê o andamento do outro — e tem um efeito colateral que só aparece
-- do lado de cá: o ADMIN também não lê. O dado existia e não chegava a
-- ninguém.
--
-- Não se resolve afrouxando a política. Uma política `or admin` na
-- `progresso` abriria a tabela para leitura direta pela chave publicável, e
-- bastaria a flag `admin` vazar uma vez para o andamento de toda a turma
-- sair junto. Resolve-se como o resto do painel já resolve: função
-- `security definer` que confere quem chamou ANTES de qualquer coisa, e
-- devolve só o que o admin precisa ver.

-- ───────────────────────────────────────────────────────────────
-- ÚLTIMO ACESSO: por que `last_sign_in_at` sozinho mente
--
-- `auth.users.last_sign_in_at` marca o LOGIN, não o uso. O Supabase renova
-- o token sozinho enquanto o aluno não sai, então quem entrou uma vez em
-- agosto e usa o app toda semana continua aparecendo com "último acesso em
-- agosto". Para um mentor que quer saber quem sumiu, esse número é pior do
-- que número nenhum: ele acusa abandono onde não há.
--
-- Por isso a coluna abaixo. O app grava a data cada vez que a área de
-- membros abre — uma linha por aluno, um UPDATE por visita, sem tabela de
-- evento e sem histórico. Não é analytics; é o "visto por último" do
-- WhatsApp, e é o que responde à pergunta que o Luka faz.
--
-- Enquanto o app novo não estiver no ar a coluna fica nula e a função cai
-- de volta no login e na data da última aula aberta. Nada quebra no meio.
-- ───────────────────────────────────────────────────────────────
alter table public.progresso
  add column if not exists visto_em timestamptz;


-- ═══════════════════════════════════════════════════════════════
-- A LISTA — uma linha por conta, para a aba Alunos do painel
--
--   select * from public.admin_acompanhamento();
--
-- `aberturas` conta TUDO que o aluno abriu — aula e material de apoio.
-- Separar os dois exige a mesma regra do front (`type html` + `path` +
-- nome `f<fase>-<numero>`), e ela mora na função de detalhe, onde há o
-- registro do `conteudo` para conferir. Aqui o número é volume de uso.
-- ═══════════════════════════════════════════════════════════════
create or replace function public.admin_acompanhamento()
returns table (
  email           text,
  fases           int[],
  ferramentas     boolean,
  admin           boolean,
  tem_senha       boolean,
  criado_em       timestamptz,
  ultimo_login    timestamptz,
  visto_em        timestamptz,
  ultima_abertura timestamptz,
  ultimo_acesso   timestamptz,
  aberturas       int
)
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  -- A trava. Não é a aba escondida no front que protege isto.
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
           (u.encrypted_password is not null and u.encrypted_password <> ''),
           u.created_at,
           u.last_sign_in_at,
           p.visto_em,
           ag.ultima,
           -- GREATEST ignora nulo no Postgres, então conta vazia devolve
           -- nulo e o painel escreve "nunca entrou" em vez de 1970.
           greatest(u.last_sign_in_at, p.visto_em, ag.ultima),
           coalesce(ag.n,0)::int
      from auth.users u
      left join public.acesso    a on a.user_id = u.id
      left join public.progresso p on p.user_id = u.id
      left join lateral (
        select count(*)::int as n,
               -- Só milissegundo de verdade vira data. O merge do app grava
               -- `1` quando o registro veio sem carimbo (`Number(x)||1`), e
               -- to_timestamp(0.001) devolveria 01/01/1970 — data plausível
               -- o bastante para o painel exibir e ninguém desconfiar.
               max(case when e.value ~ '^[0-9]{12,}$'
                        then to_timestamp((e.value)::numeric / 1000) end) as ultima
          from jsonb_each_text(coalesce(p.payload -> 'aulas', '{}'::jsonb)) e
      ) ag on true
     order by u.email;
end $$;


-- ═══════════════════════════════════════════════════════════════
-- O DETALHE — o que ESTE aluno abriu, e quando
--
--   select * from public.admin_aulas_do_aluno('aluno@email.com');
--
-- A chave gravada no payload é a mesma `chaveMat` do front:
-- `path` (caminho no bucket) e, para material antigo cadastrado por URL,
-- `file`, `url` ou o nome. O join tem de repetir essa ordem — inverter
-- casaria o registro errado quando os dois campos existem.
--
-- `existe = false` é material que o aluno abriu e que foi despublicado
-- depois. Some da trilha, mas continua no andamento dele: apagar aqui
-- seria reescrever o que ele estudou.
-- ═══════════════════════════════════════════════════════════════
create or replace function public.admin_aulas_do_aluno(p_email text)
returns table (
  chave     text,
  aberto_em timestamptz,
  nome      text,
  tipo      text,
  fase_id   text,
  aula      boolean,
  existe    boolean
)
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_id uuid;
begin
  if not exists (select 1 from public.acesso a
                  where a.user_id = auth.uid() and a.admin) then
    raise exception 'acao permitida apenas para administradores';
  end if;

  select id into v_id from auth.users where lower(email) = lower(trim(p_email));
  if v_id is null then
    raise exception 'nao encontrei conta com o e-mail %', p_email;
  end if;

  return query
    select e.key::text,
           case when e.value ~ '^[0-9]{12,}$'
                then to_timestamp((e.value)::numeric / 1000) end,
           coalesce(c.dados ->> 'name', e.key)::text,
           coalesce(c.dados ->> 'type', '')::text,
           c.fase_id::text,
           -- Mesma regra do `ehAula` do front, e ela precisa continuar
           -- igual dos dois lados: aula é o módulo escrito que o
           -- `publicar-fase.py` sobe (html + path + nome `f<fase>-<nn>`).
           -- Contrato e planilha também são `type html` desde o seed —
           -- sem os três testes juntos, baixar o contrato de CLT contaria
           -- como aula assistida.
           coalesce(c.dados ->> 'type' = 'html'
                    and c.dados ->> 'path' is not null
                    and (c.dados ->> 'path') ~ '(^|/)f[0-9]+-[0-9]{2}', false),
           (c.id is not null)
      from public.progresso p
      cross join lateral jsonb_each_text(coalesce(p.payload -> 'aulas','{}'::jsonb)) e
      left join public.conteudo c
             on coalesce(c.dados ->> 'path',
                         c.dados ->> 'file',
                         c.dados ->> 'url',
                         c.dados ->> 'name') = e.key
     where p.user_id = v_id
     order by c.fase_id nulls last, coalesce(c.dados ->> 'path', e.key);
end $$;


-- `anon` (visitante sem login) nunca. `authenticated` pode chamar — e leva
-- exceção se não for admin. Mesmo desenho de `admin_definir_acesso`.
revoke all on function public.admin_acompanhamento()          from public, anon;
revoke all on function public.admin_aulas_do_aluno(text)      from public, anon;
grant execute on function public.admin_acompanhamento()       to authenticated;
grant execute on function public.admin_aulas_do_aluno(text)   to authenticated;


-- ═══════════════════════════════════════════════════════════════
-- CONFERÊNCIA — rode depois e olhe o resultado.
-- ═══════════════════════════════════════════════════════════════
-- 1. A coluna entrou e o RLS da `progresso` continua ligado:
--    select tablename, rowsecurity from pg_tables where tablename = 'progresso';
--
-- 2. As duas precisam vir com aluno_executa = true — a proteção está
--    dentro do corpo, não no GRANT:
--    select p.proname, has_function_privilege('authenticated', p.oid, 'execute') as aluno_executa
--      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
--     where n.nspname='public' and p.proname in ('admin_acompanhamento','admin_aulas_do_aluno');
--
-- 3. Quem entrou quando:
--    select email, ultimo_acesso, aberturas from public.admin_acompanhamento();
--
-- 4. O que um aluno abriu:
--    select nome, fase_id, aula, aberto_em from public.admin_aulas_do_aluno('aluno@email.com');
--
-- ═══════════════════════════════════════════════════════════════
-- VOLTAR ATRÁS. A aba some do painel e o resto do app fica igual.
-- A coluna `visto_em` pode ficar: sem as funções, ninguém a lê.
-- ═══════════════════════════════════════════════════════════════
-- drop function if exists public.admin_acompanhamento();
-- drop function if exists public.admin_aulas_do_aluno(text);
