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


-- ═══════════════════════════════════════════════════════════════
-- QUEM PODE ENTRAR EM QUE — dois níveis de produto
--
-- Nível 1, aulas: basta ter conta. Todo aluno da mentoria entra na
--   área de membros.
-- Nível 2, ferramentas: precisa de linha nesta tabela com
--   ferramentas = true. É o upsell, liberado na mão.
--
-- Sem esta separação, criar a conta para assistir aula liberaria o
-- app de ferramentas de graça: os dois níveis virariam um só.
-- ═══════════════════════════════════════════════════════════════
create table if not exists public.acesso (
  user_id     uuid primary key references auth.users(id) on delete cascade,
  ferramentas boolean     not null default false,
  nome        text,
  liberado_em timestamptz,
  obs         text
);

alter table public.acesso enable row level security;

drop policy if exists "membro le o proprio acesso" on public.acesso;

-- Só leitura, e só da própria linha. Nenhuma política de insert,
-- update ou delete: o app NUNCA escreve aqui. Quem libera é você,
-- pelo SQL Editor. Se o aluno pudesse escrever, se autolibera.
create policy "membro le o proprio acesso"
  on public.acesso for select
  using (auth.uid() = user_id);


-- ═══════════════════════════════════════════════════════════════
-- LIBERAR E BLOQUEAR PELO E-MAIL
--
-- Você não precisa procurar o UUID de ninguém. No SQL Editor:
--
--   select public.liberar_ferramentas('aluno@email.com', 'Nome do Aluno');
--   select public.bloquear_ferramentas('aluno@email.com');
--   select * from public.acesso;              -- quem tem o quê
--
-- SECURITY DEFINER porque precisa ler auth.users. O EXECUTE é
-- revogado de anon e authenticated logo abaixo — sem isso, qualquer
-- aluno logado chamaria a função e se liberaria sozinho.
-- ═══════════════════════════════════════════════════════════════
create or replace function public.liberar_ferramentas(p_email text, p_nome text default null)
returns text
language plpgsql
security definer
set search_path = public, auth
as $$
declare v_id uuid;
begin
  select id into v_id from auth.users where lower(email) = lower(trim(p_email));
  if v_id is null then
    return 'nao encontrei usuario com o e-mail ' || p_email ||
           ' — crie a conta primeiro em Authentication > Users';
  end if;
  insert into public.acesso (user_id, ferramentas, nome, liberado_em)
       values (v_id, true, p_nome, now())
  on conflict (user_id) do update
    set ferramentas = true,
        nome        = coalesce(excluded.nome, acesso.nome),
        liberado_em = now();
  return 'ferramentas liberadas para ' || p_email;
end $$;

create or replace function public.bloquear_ferramentas(p_email text)
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
  update public.acesso set ferramentas = false where user_id = v_id;
  return 'ferramentas bloqueadas para ' || p_email;
end $$;

revoke all on function public.liberar_ferramentas(text, text) from public, anon, authenticated;
revoke all on function public.bloquear_ferramentas(text)       from public, anon, authenticated;

-- ═══════════════════════════════════════════════════════════════
-- ADMIN DE VERDADE
--
-- Antes a senha do painel estava escrita no HTML público, e o que
-- era cadastrado por ele ficava no localStorage do próprio navegador
-- — ou seja, nenhum aluno via. Agora admin é uma flag na conta.
--
--   select public.tornar_admin('voce@email.com');
-- ═══════════════════════════════════════════════════════════════
alter table public.acesso add column if not exists admin boolean not null default false;

create or replace function public.tornar_admin(p_email text)
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
  insert into public.acesso (user_id, ferramentas, admin, liberado_em)
       values (v_id, true, true, now())
  on conflict (user_id) do update
    set admin = true, ferramentas = true;
  return p_email || ' agora e admin e tem as ferramentas';
end $$;

revoke all on function public.tornar_admin(text) from public, anon, authenticated;


-- ═══════════════════════════════════════════════════════════════
-- CONTEÚDO PUBLICADO — o que o admin cadastra e todo aluno vê
--
-- Uma linha por item. `dados` guarda o payload de cada tipo, então
-- acrescentar campo no futuro não pede migração.
-- ═══════════════════════════════════════════════════════════════
create table if not exists public.conteudo (
  id        uuid primary key default gen_random_uuid(),
  tipo      text        not null check (tipo in ('materials','videos','links','comments')),
  fase_id   text,
  dados     jsonb       not null default '{}'::jsonb,
  criado_em timestamptz not null default now()
);

alter table public.conteudo enable row level security;

drop policy if exists "aluno le o conteudo"     on public.conteudo;
drop policy if exists "admin publica conteudo"  on public.conteudo;
drop policy if exists "admin remove conteudo"   on public.conteudo;

-- Qualquer aluno logado lê. É esse o ponto: o que você publica chega.
create policy "aluno le o conteudo"
  on public.conteudo for select to authenticated
  using (true);

-- Escrever, só admin. A checagem é no banco, não no navegador —
-- botão escondido no front não é controle de acesso.
create policy "admin publica conteudo"
  on public.conteudo for insert to authenticated
  with check (exists (select 1 from public.acesso a
                       where a.user_id = auth.uid() and a.admin));

create policy "admin remove conteudo"
  on public.conteudo for delete to authenticated
  using (exists (select 1 from public.acesso a
                  where a.user_id = auth.uid() and a.admin));


-- ═══════════════════════════════════════════════════════════════
-- Conferência. As duas tabelas precisam vir com rowsecurity = true,
-- e as duas funções não podem ter EXECUTE para authenticated.
-- ═══════════════════════════════════════════════════════════════
-- select tablename, rowsecurity from pg_tables
--  where tablename in ('dados','acesso','conteudo');
--
-- select p.proname, has_function_privilege('authenticated', p.oid, 'execute') as aluno_executa
--   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
--  where n.nspname = 'public' and p.proname like '%_ferramentas';
