-- ═══════════════════════════════════════════════════════════════
-- Ferramentas APM — estrutura de dados por membro
--
-- Cole este arquivo inteiro no SQL Editor do Supabase e rode uma vez.
-- Painel do Supabase → SQL Editor → New query → colar → Run.
-- ═══════════════════════════════════════════════════════════════

-- Uma linha por membro. O app inteiro cabe num único JSON, então não
-- há tabela por módulo: menos peça para quebrar, e o app não precisa
-- de migração quando um módulo novo entrar.
create table if not exists public.dados (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  payload    jsonb       not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

-- Sem isto, qualquer pessoa com a chave pública lê os dados de todo
-- mundo. É esta trava que torna a chave "anon" segura de publicar.
alter table public.dados enable row level security;

drop policy if exists "membro le os proprios dados"      on public.dados;
drop policy if exists "membro cria os proprios dados"    on public.dados;
drop policy if exists "membro atualiza os proprios dados" on public.dados;

create policy "membro le os proprios dados"
  on public.dados for select
  using (auth.uid() = user_id);

create policy "membro cria os proprios dados"
  on public.dados for insert
  with check (auth.uid() = user_id);

create policy "membro atualiza os proprios dados"
  on public.dados for update
  using      (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ═══════════════════════════════════════════════════════════════
-- Conferência: rode depois para confirmar que o RLS está ligado.
-- A coluna rowsecurity precisa vir como true.
-- ═══════════════════════════════════════════════════════════════
-- select tablename, rowsecurity from pg_tables where tablename = 'dados';
