-- ═══════════════════════════════════════════════════════════════
-- OS ARQUIVOS SAEM DA WEB ABERTA E VAO PARA UM BUCKET PRIVADO
--
-- Hoje `mentoria-app-self.vercel.app/files/pcp_simplificado_pro.xlsx`
-- responde 200 para qualquer um. A lista respeita a fase comprada, o
-- arquivo nao. Num modelo de fase avulsa, em que um aluno tem a 1 e o
-- outro tem tudo, os dois se falam e o link circula.
--
-- Aqui o arquivo passa a viver no Storage do Supabase, em pasta por
-- fase (`0/`, `1/` … `7/`), num bucket que nao e publico. O aluno nao
-- recebe um endereco fixo: o app pede um link assinado na hora do
-- clique, e esse link expira. Quem nao tem a fase nao consegue nem
-- gerar o link — a checagem e a mesma politica abaixo.
--
-- A pasta e a fase. `3/pcp_simplificado_pro.xlsx` pertence a Fase 4
-- (id interno 3), e e isso que a politica compara com `acesso.fases`.
--
-- Rode uma vez. Pode rodar de novo.
-- ═══════════════════════════════════════════════════════════════

-- Bucket privado. `public = false` e o que faz o Storage exigir
-- assinatura em vez de servir o arquivo a quem pedir.
insert into storage.buckets (id, name, public)
     values ('materiais', 'materiais', false)
on conflict (id) do update set public = false;


drop policy if exists "aluno le arquivo da fase que comprou" on storage.objects;
drop policy if exists "admin escreve arquivo"                on storage.objects;
drop policy if exists "admin atualiza arquivo"               on storage.objects;
drop policy if exists "admin apaga arquivo"                  on storage.objects;

-- LER: admin sempre; aluno so se a pasta do arquivo estiver entre as
-- fases dele. Sem linha em `acesso`, nao le nada — inclusive quem
-- criou conta e ainda nao comprou.
create policy "aluno le arquivo da fase que comprou"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'materiais'
    and exists (
      select 1 from public.acesso a
       where a.user_id = auth.uid()
         and (a.admin or (storage.foldername(name))[1] = any(a.fases))
    )
  );

-- ESCREVER: so admin. E o que permite o upload pelo painel sem abrir
-- a porta para o aluno subir arquivo no seu bucket.
create policy "admin escreve arquivo"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'materiais'
    and exists (select 1 from public.acesso a
                 where a.user_id = auth.uid() and a.admin)
  );

create policy "admin atualiza arquivo"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'materiais'
    and exists (select 1 from public.acesso a
                 where a.user_id = auth.uid() and a.admin)
  );

create policy "admin apaga arquivo"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'materiais'
    and exists (select 1 from public.acesso a
                 where a.user_id = auth.uid() and a.admin)
  );


-- A migracao reescreve cada linha de `conteudo` trocando o arquivo
-- publico pelo caminho no bucket. Ate aqui o admin so tinha insert e
-- delete; faltava o update.
drop policy if exists "admin atualiza conteudo" on public.conteudo;
create policy "admin atualiza conteudo"
  on public.conteudo for update to authenticated
  using      (exists (select 1 from public.acesso a where a.user_id = auth.uid() and a.admin))
  with check (exists (select 1 from public.acesso a where a.user_id = auth.uid() and a.admin));


-- ═══════════════════════════════════════════════════════════════
-- Conferencia:
--   select id, public from storage.buckets where id='materiais';
--   -> public precisa vir false
--
--   select policyname, cmd from pg_policies
--    where schemaname='storage' and tablename='objects'
--    order by policyname;
--
-- Voltar atras: apagar as quatro politicas acima. O bucket pode ficar;
-- vazio ele nao atrapalha nada.
-- ═══════════════════════════════════════════════════════════════
