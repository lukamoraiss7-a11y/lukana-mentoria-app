-- ═══════════════════════════════════════════════════════════════
-- ⚠️  SUBSTITUÍDO por `ementa-por-fase.sql` (08/08/2026).
--     Aquele arquivo cria esta mesma função e mais a `ementa_por_fase`,
--     que devolve o título do que está publicado na fase fechada. Rode
--     o de lá; este fica só como referência do que a função faz.
-- ═══════════════════════════════════════════════════════════════
--
-- QUANTO MATERIAL EXISTE EM CADA FASE — o número, nunca o arquivo
--
-- Cole este arquivo inteiro no SQL Editor do Supabase e rode uma vez.
-- Painel → SQL Editor → New query → colar → Run.
--
-- Pode rodar de novo quantas vezes quiser: só cria/substitui uma
-- função. Não mexe em tabela, não mexe em política, não apaga nada.
--
-- Pré-requisitos já rodados: `supabase-setup.sql` e `fases-por-aluno.sql`.
-- ═══════════════════════════════════════════════════════════════

-- POR QUE ISTO EXISTE
--
-- A política de `conteudo` faz o certo: material de fase não comprada
-- não sai do banco. O efeito colateral é que a tela da fase fechada
-- fica vazia — e uma tela vazia não desperta vontade nenhuma. Saber que
-- existem 12 planilhas prontas esperando na Fase 4 é exatamente o que
-- faz o aluno querer comprar a fase.
--
-- O número não é o arquivo. Esta função devolve só a contagem: nome,
-- descrição, URL e caminho no bucket continuam presos pela política.
-- É a única informação de fase fechada que o aluno recebe.
--
-- `security definer` porque a função precisa enxergar por cima do RLS —
-- é esse o ponto dela. O `select` é fixo e agregado, não aceita
-- parâmetro nenhum: não há filtro para o aluno manipular e extrair
-- linha individual.
create or replace function public.contagem_por_fase()
returns table (fase_id text, total bigint)
language sql
security definer
set search_path = public
as $$
  select c.fase_id, count(*)
    from public.conteudo c
   where c.fase_id is not null
     and c.tipo = 'materials'
   group by c.fase_id;
$$;

-- Só quem está logado. Visitante anônimo não fica sabendo nem o número.
revoke all on function public.contagem_por_fase() from public, anon;
grant execute on function public.contagem_por_fase() to authenticated;


-- ═══════════════════════════════════════════════════════════════
-- CONFERÊNCIA — rode depois e olhe o resultado.
-- ═══════════════════════════════════════════════════════════════
-- 1. O que o app vai mostrar (fase_id '0' = Fase 1 … '7' = Bônus 2):
--    select * from public.contagem_por_fase() order by fase_id;
--
-- 2. Aluno logado executa (precisa vir true) e anônimo não (false):
--    select has_function_privilege('authenticated','public.contagem_por_fase()','execute') as aluno,
--           has_function_privilege('anon',         'public.contagem_por_fase()','execute') as visitante;
--
-- ═══════════════════════════════════════════════════════════════
-- VOLTAR ATRÁS: uma linha. O app detecta a falta e simplesmente para
-- de mostrar os números — nada mais muda de lugar na tela.
-- ═══════════════════════════════════════════════════════════════
-- drop function if exists public.contagem_por_fase();
