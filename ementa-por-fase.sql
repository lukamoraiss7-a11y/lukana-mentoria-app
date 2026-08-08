-- ═══════════════════════════════════════════════════════════════
-- O QUE EXISTE DENTRO DA FASE FECHADA — o título, nunca o arquivo
--
-- Cole este arquivo inteiro no SQL Editor do Supabase e rode uma vez.
-- Painel → SQL Editor → New query → colar → Run.
--
-- Pode rodar de novo quantas vezes quiser: só cria/substitui funções.
-- Não mexe em tabela, não mexe em política, não apaga nada.
--
-- Pré-requisitos já rodados: `supabase-setup.sql` e `fases-por-aluno.sql`.
--
-- SUBSTITUI o `contagem-por-fase.sql`: as duas funções estão aqui, então
-- rodar este arquivo já resolve os dois pendentes. Não precisa rodar
-- aquele antes nem depois.
-- ═══════════════════════════════════════════════════════════════

-- POR QUE ISTO EXISTE
--
-- A política de `conteudo` faz o certo: material de fase não comprada
-- não sai do banco. O efeito colateral é que a tela da fase fechada
-- fica vazia — e vazio não vende. O aluno olha a Fase 4 trancada e não
-- tem a menor ideia se ali dentro tem 1 PDF ou 12 planilhas prontas.
--
-- A decisão é deixar ele LER o que existe e não CONSEGUIR ABRIR:
--   sai   → o título do material, do vídeo e do link, e a contagem.
--   fica  → descrição, URL, caminho no bucket, texto de nota do
--           instrutor, e o arquivo em si.
--
-- Título não é conteúdo, é vitrine. "Planilha de Precificação por m²"
-- desperta a compra; ela só abre quando a fase entra no plano dele.
-- A nota do instrutor (`comments`) fica fora de propósito: ali é aula
-- escrita, não índice.
--
-- `security definer` porque a função precisa enxergar por cima do RLS —
-- é esse o ponto dela. Nenhuma das duas aceita parâmetro: não existe
-- filtro para o aluno manipular e extrair linha individual.


-- ───────────────────────────────────────────────────────────────
-- 1. A EMENTA — o que está publicado em cada fase, só o título
-- ───────────────────────────────────────────────────────────────
create or replace function public.ementa_por_fase()
returns table (fase_id text, tipo text, titulo text)
language sql
security definer
set search_path = public
as $$
  select c.fase_id,
         c.tipo,
         -- `materials` guarda em `name`, `videos` e `links` em `title`.
         coalesce(nullif(btrim(c.dados->>'name'),''),
                  nullif(btrim(c.dados->>'title'),''),
                  'Material sem nome')
    from public.conteudo c
   where c.fase_id is not null
     and c.tipo in ('materials','videos','links')
   order by c.fase_id, c.tipo, c.criado_em;
$$;


-- ───────────────────────────────────────────────────────────────
-- 2. A CONTAGEM — quantos materiais por fase
--
-- Vem de `contagem-por-fase.sql`, repetida aqui para que um único Run
-- deixe o app completo. Idêntica à de lá.
-- ───────────────────────────────────────────────────────────────
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


-- Só quem está logado. Visitante anônimo não fica sabendo nem o título.
revoke all on function public.ementa_por_fase()   from public, anon;
revoke all on function public.contagem_por_fase() from public, anon;
grant execute on function public.ementa_por_fase()   to authenticated;
grant execute on function public.contagem_por_fase() to authenticated;


-- ═══════════════════════════════════════════════════════════════
-- CONFERÊNCIA — rode depois e olhe o resultado.
-- ═══════════════════════════════════════════════════════════════
-- 1. O que o aluno vai ler nas fases fechadas
--    (fase_id '0' = Fase 1 … '7' = Bônus 2):
--    select * from public.ementa_por_fase();
--
-- 2. Os números da vitrine:
--    select * from public.contagem_por_fase() order by fase_id;
--
-- 3. Confirmar que a URL e o caminho do arquivo NÃO saem — a ementa tem
--    três colunas e nenhuma delas é endereço:
--    select * from public.ementa_por_fase() limit 3;
--
-- 4. Aluno logado executa (true) e visitante não (false):
--    select has_function_privilege('authenticated','public.ementa_por_fase()','execute') as aluno,
--           has_function_privilege('anon',         'public.ementa_por_fase()','execute') as visitante;
--
-- ═══════════════════════════════════════════════════════════════
-- VOLTAR ATRÁS: uma linha. O app detecta a falta e volta a mostrar a
-- fase fechada sem a lista — nada mais muda de lugar na tela.
-- ═══════════════════════════════════════════════════════════════
-- drop function if exists public.ementa_por_fase();
