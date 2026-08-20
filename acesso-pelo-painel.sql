-- ═══════════════════════════════════════════════════════════════
-- LIBERAR ACESSO PELO PAINEL, SEM SQL
--
-- `liberar_fases` e `liberar_ferramentas` tem EXECUTE revogado de
-- `authenticated` — sem isso qualquer aluno logado chamaria a funcao
-- pelo console do navegador e se liberaria sozinho. Por isso elas so
-- rodam aqui no SQL Editor, e por isso o painel nao conseguia usa-las.
--
-- A funcao abaixo pode ser chamada pelo navegador porque ela mesma
-- confere quem esta chamando. A trava saiu do GRANT e foi para dentro
-- do corpo: primeira coisa que ela faz e perguntar se auth.uid() e
-- admin, e explodir se nao for. Um aluno que descobrir o nome da
-- funcao e chamar recebe excecao, nao acesso.
--
-- Rode uma vez. Pode rodar de novo: e create or replace.
-- ═══════════════════════════════════════════════════════════════

create or replace function public.admin_definir_acesso(
  p_email       text,
  p_fases       int[],
  p_ferramentas boolean default null
)
returns text
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_id   uuid;
  v_ids  text[];
  v_ruim int;
begin
  -- A trava. Nao e o botao escondido no front que protege isto.
  if not exists (select 1 from public.acesso a
                  where a.user_id = auth.uid() and a.admin) then
    raise exception 'acao permitida apenas para administradores';
  end if;

  select id into v_id from auth.users where lower(email) = lower(trim(p_email));
  if v_id is null then
    return 'nao encontrei conta com o e-mail ' || p_email ||
           ' — crie primeiro em Authentication > Users';
  end if;

  -- Fora de 1..7 e engano de digitacao. Recusar e melhor do que gravar
  -- uma fase que nao existe e o aluno reclamar que nao abre.
  select n into v_ruim from unnest(coalesce(p_fases,'{}'::int[])) n
   where n < 1 or n > 7 limit 1;
  if v_ruim is not null then
    raise exception 'numero de fase invalido: % (use 1 a 5, 6 para o Bonus 1 e 7 para o Bonus 2)', v_ruim;
  end if;

  -- O painel manda o numero humano; o banco guarda o id do modulo.
  -- A conversao mora aqui, nunca no front — e onde o erro silencioso
  -- de liberar a fase errada apareceria.
  select coalesce(array_agg(distinct (n - 1)::text), '{}')
    into v_ids
    from unnest(coalesce(p_fases,'{}'::int[])) n;

  insert into public.acesso (user_id, fases, ferramentas, liberado_em)
       values (v_id, v_ids, coalesce(p_ferramentas,false), now())
  on conflict (user_id) do update
    set fases       = excluded.fases,
        -- null = nao mexe no que ja estava
        ferramentas = coalesce(p_ferramentas, acesso.ferramentas),
        liberado_em = now();

  return 'acesso atualizado para ' || p_email;
end $$;


-- Quem tem o que, para a lista do painel. Mesma trava por dentro:
-- sem ela, um aluno logado leria o e-mail de todos os outros.
create or replace function public.admin_listar_acessos()
returns table (email text, fases int[], ferramentas boolean, admin boolean)
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
           coalesce(a.admin,false)
      from auth.users u
      left join public.acesso a on a.user_id = u.id
     order by u.email;
end $$;


-- `anon` (visitante sem login) nunca. `authenticated` pode chamar —
-- e leva excecao se nao for admin.
revoke all on function public.admin_definir_acesso(text, int[], boolean) from public, anon;
revoke all on function public.admin_listar_acessos()                     from public, anon;
grant execute on function public.admin_definir_acesso(text, int[], boolean) to authenticated;
grant execute on function public.admin_listar_acessos()                     to authenticated;


-- ═══════════════════════════════════════════════════════════════
-- Conferencia. As duas precisam vir com aluno_executa = true — a
-- protecao esta dentro do corpo, nao no GRANT.
--   select p.proname, has_function_privilege('authenticated', p.oid, 'execute') as aluno_executa
--     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
--    where n.nspname='public' and p.proname like 'admin\_%';
--
-- Voltar atras:
--   drop function if exists public.admin_definir_acesso(text,int[],boolean);
--   drop function if exists public.admin_listar_acessos();
-- ═══════════════════════════════════════════════════════════════
