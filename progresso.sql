-- ═══════════════════════════════════════════════════════════════
-- ANDAMENTO DO ALUNO — que aula ele já abriu
--
-- Cole este arquivo inteiro no SQL Editor do Supabase e rode uma vez.
-- Painel do Supabase → SQL Editor → New query → colar → Run.
--
-- Sem esta tabela o app NÃO quebra: o andamento fica só no
-- localStorage do navegador e a área de membros abre igual. O que a
-- tabela resolve é o mesmo problema que a senha resolveu em 08/08/2026
-- — o acesso passou a ser da conta, e o progresso tem de seguir a
-- conta também. Sem ela, o aluno que abre a aula no computador da
-- fábrica e depois entra pelo celular vê a barra voltar a zero.
--
-- Uma linha por aluno, um JSON dentro. Mesmo desenho de `public.dados`
-- (Ferramentas APM): sem tabela por tipo de evento, sem migração
-- quando um campo novo entrar.
--
-- Formato do payload:
--   {
--     "aulas":  { "<caminho do arquivo no bucket>": <timestamp ms> },
--     "checks": { "<fase_id>": [true, false, true, ...] }
--   }
-- A chave da aula é o `dados.path` do registro em `public.conteudo` —
-- o mesmo caminho do objeto no bucket. Material antigo, cadastrado por
-- URL em vez de arquivo, cai no `file`, na `url` ou no nome.
-- ═══════════════════════════════════════════════════════════════
create table if not exists public.progresso (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  payload    jsonb       not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

-- Sem isto, qualquer pessoa com a chave pública lê o andamento de todo
-- mundo. É esta trava que torna a chave "anon" segura de publicar.
alter table public.progresso enable row level security;

drop policy if exists "aluno le o proprio andamento"       on public.progresso;
drop policy if exists "aluno cria o proprio andamento"     on public.progresso;
drop policy if exists "aluno atualiza o proprio andamento" on public.progresso;

create policy "aluno le o proprio andamento"
  on public.progresso for select
  using (auth.uid() = user_id);

create policy "aluno cria o proprio andamento"
  on public.progresso for insert
  with check (auth.uid() = user_id);

create policy "aluno atualiza o proprio andamento"
  on public.progresso for update
  using      (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ═══════════════════════════════════════════════════════════════
-- Conferência: rode depois. `rowsecurity` precisa vir true.
-- ═══════════════════════════════════════════════════════════════
-- select tablename, rowsecurity from pg_tables where tablename = 'progresso';
