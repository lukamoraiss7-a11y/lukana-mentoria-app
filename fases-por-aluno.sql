-- ═══════════════════════════════════════════════════════════════
-- ACESSO POR FASE — vender fase avulsa
--
-- Cole este arquivo inteiro no SQL Editor do Supabase e rode uma vez.
-- Painel → SQL Editor → New query → colar → Run.
--
-- Pode rodar de novo quantas vezes quiser: não duplica nada e não
-- apaga nada. Só acrescenta uma coluna e troca a regra de leitura.
--
-- Pré-requisito: `supabase-setup.sql` já rodado (feito em 05/08/2026).
--
-- ATENÇÃO, o efeito é imediato: assim que rodar, todo conteúdo preso a
-- uma fase some para quem não for admin e não tiver aquela fase
-- liberada. Conteúdo cadastrado como "Geral" continua visível para
-- todo aluno. Isso é o comportamento certo — mas rode ANTES de abrir
-- turma, não no meio dela.
-- ═══════════════════════════════════════════════════════════════

-- Quais fases o aluno comprou. Guardado como texto porque `conteudo.fase_id`
-- é texto — comparar texto com texto evita cast dentro da política, e cast
-- que estoura dentro de RLS não nega bonito: derruba a consulta inteira e o
-- aluno vê a área em branco.
--
-- O conteúdo dessa coluna é o id do módulo (0 a 7), não o número da fase.
-- Fase 1 = '0' … Fase 6 = '5', Bônus 1 = '6', Bônus 2 = '7'. Você nunca
-- precisa saber disso: as funções lá embaixo recebem o número humano.
alter table public.acesso
  add column if not exists fases text[] not null default '{}';


-- ═══════════════════════════════════════════════════════════════
-- A TRAVA DE VERDADE
--
-- Antes: `using (true)` — qualquer aluno logado lia todo o conteúdo
-- publicado. Esconder a fase na tela não adiantaria nada: o vídeo e o
-- material chegavam ao navegador dele do mesmo jeito, bastava abrir o
-- DevTools. Agora o que ele não comprou não sai do banco.
--
-- Três caminhos de liberação, nesta ordem:
--   1. conteúdo "Geral" (fase_id nulo) — todo aluno vê;
--   2. admin — vê tudo, sempre. Sem esta linha você tranca a si mesmo
--      fora do que acabou de publicar;
--   3. aluno com a fase no array.
-- ═══════════════════════════════════════════════════════════════
drop policy if exists "aluno le o conteudo" on public.conteudo;

create policy "aluno le o conteudo"
  on public.conteudo for select to authenticated
  using (
    fase_id is null
    or exists (
      select 1 from public.acesso a
       where a.user_id = auth.uid()
         and (a.admin or fase_id = any(a.fases))
    )
  );


-- ═══════════════════════════════════════════════════════════════
-- LIBERAR FASE PELO E-MAIL
--
-- Você passa o número que usa para vender. 1 a 6 são as fases,
-- 7 é o Bônus 1 e 8 é o Bônus 2. A conversão para o id interno é
-- feita aqui dentro — é exatamente onde o erro silencioso moraria.
--
--   select public.liberar_fases('aluno@email.com', '{1,3}');   -- só Fase 1 e 3
--   select public.liberar_fases('aluno@email.com', '{1,2,3,4,5,6,7,8}'); -- tudo
--   select public.bloquear_fases('aluno@email.com');           -- tira todas
--   select * from public.listar_acessos();                     -- quem tem o quê
--
-- SUBSTITUI a lista, não soma. Se ele já tinha a 1 e você rodar com
-- '{3}', ele fica só com a 3. Passe sempre o conjunto completo do que
-- ele comprou até hoje.
-- ═══════════════════════════════════════════════════════════════
create or replace function public.liberar_fases(p_email text, p_fases int[])
returns text
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_id    uuid;
  v_ids   text[];
  v_ruim  int;
begin
  select id into v_id from auth.users where lower(email) = lower(trim(p_email));
  if v_id is null then
    return 'nao encontrei usuario com o e-mail ' || p_email ||
           ' — crie a conta primeiro em Authentication > Users';
  end if;

  -- Fora de 1..8 é engano de digitação. Recusar é melhor do que gravar
  -- uma fase que não existe e o aluno reclamar que não abre.
  select n into v_ruim from unnest(coalesce(p_fases,'{}'::int[])) n
   where n < 1 or n > 8 limit 1;
  if v_ruim is not null then
    return 'numero de fase invalido: ' || v_ruim ||
           ' — use 1 a 6 para as fases, 7 para o Bonus 1 e 8 para o Bonus 2';
  end if;

  select coalesce(array_agg(distinct (n - 1)::text), '{}')
    into v_ids
    from unnest(coalesce(p_fases,'{}'::int[])) n;

  insert into public.acesso (user_id, fases, liberado_em)
       values (v_id, v_ids, now())
  on conflict (user_id) do update
    set fases = excluded.fases;

  return 'fases ' || array_to_string(p_fases, ', ') || ' liberadas para ' || p_email;
end $$;


create or replace function public.bloquear_fases(p_email text)
returns text
language plpgsql
security definer
set search_path = public, auth
as $$
declare v_id uuid;
begin
  select id into v_id from auth.users where lower(email) = lower(trim(p_email));
  if v_id is null then
    return 'nao encontrei usuario com o e-mail ' || p_email;
  end if;
  update public.acesso set fases = '{}' where user_id = v_id;
  return 'todas as fases bloqueadas para ' || p_email;
end $$;


-- Quem tem o quê, com e-mail em vez de UUID. `acesso` sozinha só mostra
-- o id do usuário, que não diz nada a olho nu.
create or replace function public.listar_acessos()
returns table (email text, fases int[], ferramentas boolean, admin boolean)
language sql
security definer
set search_path = public, auth
as $$
  select u.email::text,
         coalesce((select array_agg((f::int + 1) order by f::int)
                     from unnest(a.fases) f), '{}'::int[]),
         coalesce(a.ferramentas,false),
         coalesce(a.admin,false)
    from auth.users u
    left join public.acesso a on a.user_id = u.id
   order by u.email;
$$;


-- Sem isto, o próprio aluno logado chama a função pelo navegador e se
-- libera sozinho — ou lê o e-mail de todo mundo pela `listar_acessos`.
-- No SQL Editor você continua rodando normalmente: lá a conexão é de
-- serviço e não passa por este revoke.
revoke all on function public.liberar_fases(text, int[]) from public, anon, authenticated;
revoke all on function public.bloquear_fases(text)       from public, anon, authenticated;
revoke all on function public.listar_acessos()           from public, anon, authenticated;


-- ═══════════════════════════════════════════════════════════════
-- CONFERÊNCIA — rode depois e olhe o resultado.
-- ═══════════════════════════════════════════════════════════════
-- 1. A coluna existe e o RLS continua ligado:
--    select tablename, rowsecurity from pg_tables
--     where tablename in ('dados','acesso','conteudo');
--
-- 2. Nenhum aluno logado executa as funções (as três precisam vir false):
--    select p.proname, has_function_privilege('authenticated', p.oid, 'execute') as aluno_executa
--      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
--     where n.nspname = 'public' and p.proname in
--           ('liberar_fases','bloquear_fases','listar_acessos');
--
-- 3. Quem tem o quê:
--    select * from public.listar_acessos();
--
-- ═══════════════════════════════════════════════════════════════
-- VOLTAR ATRÁS, se precisar. Uma linha, e o app fica igual ao que era.
-- A coluna `fases` pode ficar onde está: sem a política, ela é ignorada.
-- ═══════════════════════════════════════════════════════════════
-- drop policy if exists "aluno le o conteudo" on public.conteudo;
-- create policy "aluno le o conteudo" on public.conteudo
--   for select to authenticated using (true);
