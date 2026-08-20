-- ═══════════════════════════════════════════════════════════════
-- SEIS FASES VIRAM CINCO — 20/08/2026
--
-- Decisão do Luka:
--   · a Fase 2 (Rentabilidade) passa a se chamar Fundamentos;
--   · a Fase 1 (Fundamentos) é dissolvida: o currículo dela foi absorvido
--     pela nova Fase 1, e os 3 contratos que eram material dela vão para
--     a Operação;
--   · o programa fica com 5 fases + 2 bônus.
--
-- O `conteudo.fase_id` e o `acesso.fases` guardam o ÍNDICE do módulo, não
-- o número humano da fase. Renumerar a trilha no `index.html` sem rodar
-- este arquivo troca o material de fase para todo aluno, em silêncio.
--
--   índice antigo → índice novo
--   '0' Fundamentos   → '2'  (os 3 contratos vão para a Operação)
--   '1' Rentabilidade → '0'  (vira a Fase 1 — Fundamentos)
--   '2' Comercial     → '1'
--   '3' Operação      → '2'
--   '4' Liderança     → '3'
--   '5' Escala        → '4'
--   '6' Bônus 1       → '5'
--   '7' Bônus 2       → '6'
--
-- Cole inteiro no SQL Editor e rode UMA vez. Rodar de novo não faz nada:
-- a trava é a tabela `migracoes` lá embaixo. Sem essa trava, a segunda
-- execução deslocaria tudo mais uma casa e o estrago seria invisível.
--
-- Pré-requisitos já rodados: `supabase-setup.sql`, `fases-por-aluno.sql`,
-- `acesso-pelo-painel.sql`, `ementa-por-fase.sql`.
--
-- ESTE ARQUIVO NÃO ANDA SOZINHO. Os módulos das fases 2, 5 e 6 carregam o
-- número da fase dentro do próprio título ("FASE 2 — RENTABILIDADE") e do
-- nome do arquivo no bucket. Quem conserta as duas coisas é
--   python3 publicar-fase.py <fase> --sobrescrever
-- rodado para as fases 1, 4 e 5 DEPOIS deste SQL: ele reenvia o HTML
-- regerado por cima do caminho novo e regrava o `name` a partir do
-- <title>. Rodar só o SQL deixa o aluno com botão que dá 404.
-- ═══════════════════════════════════════════════════════════════

create table if not exists public.migracoes (
  nome       text primary key,
  rodada_em  timestamptz not null default now()
);
alter table public.migracoes enable row level security;

do $$
declare
  v_conteudo int;
  v_acesso   int;
begin
  if exists (select 1 from public.migracoes where nome = 'cinco-fases-2026-08-20') then
    raise notice 'migracao ja rodou em % — nada a fazer',
      (select rodada_em from public.migracoes where nome = 'cinco-fases-2026-08-20');
    return;
  end if;

  -- ─────────────────────────────────────────────────────────────
  -- 1. O CAMINHO NO BUCKET
  -- A pasta do Storage é o índice da fase, e o prefixo do arquivo carrega
  -- a ordem de leitura. Os objetos são movidos por fora deste SQL (a API
  -- de Storage não é acessível daqui); este UPDATE só reaponta o registro.
  -- Rodar um sem o outro = aluno com botão que dá 404.
  --   1/f2-*  →  0/f1-*      4/f5-*  →  3/f4-*      5/f6-*  →  4/f5-*
  -- `from 6` porque o prefixo `1/f2-` tem 5 caracteres. Com `from 7` — que foi
  -- o que rodou na primeira tentativa, em 20/08 — o primeiro dígito do número
  -- do módulo some: `f2-13-pro-labore` vira `f1-3-pro-labore`, e os 47 botões
  -- passam a apontar para objeto que não existe. Recuperável só porque o slug
  -- identifica o módulo; não conte com isso de novo.
  -- ─────────────────────────────────────────────────────────────
  update public.conteudo
     set dados = jsonb_set(dados, '{path}',
                 to_jsonb('0/f1-' || substring(dados->>'path' from 6)))
   where fase_id = '1' and dados->>'path' like '1/f2-%';

  update public.conteudo
     set dados = jsonb_set(dados, '{path}',
                 to_jsonb('3/f4-' || substring(dados->>'path' from 6)))
   where fase_id = '4' and dados->>'path' like '4/f5-%';

  update public.conteudo
     set dados = jsonb_set(dados, '{path}',
                 to_jsonb('4/f5-' || substring(dados->>'path' from 6)))
   where fase_id = '5' and dados->>'path' like '5/f6-%';

  -- ─────────────────────────────────────────────────────────────
  -- 2. A FASE DE CADA MATERIAL
  -- Um único passo, com CASE: '0' e '3' caem os dois em '2' e isso é o
  -- desejado (os contratos entram na Operação). Em dois UPDATEs
  -- encadeados o '1'→'0' seria pego de novo pelo '0'→'2'.
  -- ─────────────────────────────────────────────────────────────
  update public.conteudo
     set fase_id = case fase_id
                     when '0' then '2'   -- contratos: Fundamentos velha → Operação
                     when '1' then '0'   -- Rentabilidade → Fase 1 Fundamentos
                     when '2' then '1'
                     when '3' then '2'
                     when '4' then '3'
                     when '5' then '4'
                     when '6' then '5'
                     when '7' then '6'
                     else fase_id
                   end
   where fase_id is not null;
  get diagnostics v_conteudo = row_count;

  -- ─────────────────────────────────────────────────────────────
  -- 3. O QUE CADA ALUNO COMPROU
  -- Mesmo mapa. Quem tinha a Fase 1 antiga fica com a Operação (decisão
  -- do Luka): é para lá que foi o material pelo qual ele pagou.
  -- `distinct` porque quem tinha a 1 e a 4 antigas cairia duas vezes no
  -- mesmo '2', e array com item repetido faz a lista do painel mentir.
  -- ─────────────────────────────────────────────────────────────
  update public.acesso a
     set fases = coalesce((
           select array_agg(distinct novo order by novo)
             from (select case f
                            when '0' then '2'
                            when '1' then '0'
                            when '2' then '1'
                            when '3' then '2'
                            when '4' then '3'
                            when '5' then '4'
                            when '6' then '5'
                            when '7' then '6'
                            else f
                          end as novo
                     from unnest(a.fases) f) t
         ), '{}')
   where a.fases is not null and array_length(a.fases, 1) > 0;
  get diagnostics v_acesso = row_count;

  insert into public.migracoes (nome) values ('cinco-fases-2026-08-20');
  raise notice 'ok: % materiais e % alunos renumerados', v_conteudo, v_acesso;
end $$;


-- ═══════════════════════════════════════════════════════════════
-- 4. AS FUNÇÕES DE LIBERAÇÃO ACEITAVAM 1..8. Agora são 1..7.
-- Fora deste bloco de propósito: `create or replace` é idempotente e
-- precisa valer mesmo se a migração acima já tiver rodado antes.
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
  if not exists (select 1 from public.acesso a
                  where a.user_id = auth.uid() and a.admin) then
    raise exception 'acao permitida apenas para administradores';
  end if;

  select id into v_id from auth.users where lower(email) = lower(trim(p_email));
  if v_id is null then
    return 'nao encontrei conta com o e-mail ' || p_email ||
           ' — crie primeiro em Authentication > Users';
  end if;

  select n into v_ruim from unnest(coalesce(p_fases,'{}'::int[])) n
   where n < 1 or n > 7 limit 1;
  if v_ruim is not null then
    raise exception 'numero de fase invalido: % (use 1 a 5, 6 para o Bonus 1 e 7 para o Bonus 2)', v_ruim;
  end if;

  select coalesce(array_agg(distinct (n - 1)::text), '{}')
    into v_ids
    from unnest(coalesce(p_fases,'{}'::int[])) n;

  insert into public.acesso (user_id, fases, ferramentas, liberado_em)
       values (v_id, v_ids, coalesce(p_ferramentas,false), now())
  on conflict (user_id) do update
    set fases       = excluded.fases,
        ferramentas = coalesce(p_ferramentas, acesso.ferramentas),
        liberado_em = now();

  return 'acesso atualizado para ' || p_email;
end $$;


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

  select n into v_ruim from unnest(coalesce(p_fases,'{}'::int[])) n
   where n < 1 or n > 7 limit 1;
  if v_ruim is not null then
    return 'numero de fase invalido: ' || v_ruim ||
           ' — use 1 a 5 para as fases, 6 para o Bonus 1 e 7 para o Bonus 2';
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

revoke all on function public.liberar_fases(text, int[]) from public, anon, authenticated;


-- ═══════════════════════════════════════════════════════════════
-- CONFERÊNCIA — rode depois e olhe o resultado.
-- ═══════════════════════════════════════════════════════════════
-- 1. Quantos materiais por fase. Esperado, com 69 no total:
--    '0' Fundamentos 17 · '1' Comercial 4 · '2' Operação 15
--    '3' Liderança 18 · '4' Escala 15
--    select fase_id, count(*) from public.conteudo
--     where fase_id is not null group by 1 order by 1;
--
-- 2. Nenhum caminho velho sobrou (as três contagens têm de vir zero):
--    select count(*) filter (where dados->>'path' like '1/f2-%') as f2,
--           count(*) filter (where dados->>'path' like '4/f5-%') as f5,
--           count(*) filter (where dados->>'path' like '5/f6-%') as f6
--      from public.conteudo;
--
-- 3. Ninguém ficou com fase que não existe mais (tem de vir vazio):
--    select user_id, fases from public.acesso
--     where exists (select 1 from unnest(fases) f where f::int > 6);
--
-- 4. Quem tem o quê, em número humano:
--    select * from public.listar_acessos();
--
-- 5. A trava está gravada:
--    select * from public.migracoes;
