-- ═══════════════════════════════════════════════════════════════
-- OS ARQUIVOS DAS FASES SAEM DO HTML E VIRAM DADO
--
-- Ate aqui os 23 arquivos por fase estavam escritos dentro do
-- index.html. Consequencia: o painel Admin nao conseguia incluir nem
-- excluir nenhum deles — so mexia no que estava na tabela `conteudo`,
-- que estava vazia. Tirar um arquivo de uma fase exigia editar o HTML
-- e publicar.
--
-- Depois deste script os 23 estao na tabela: aparecem no painel com
-- botao Remover, e a politica por fase vale para eles como vale para
-- qualquer conteudo publicado.
--
-- Rode UMA vez. Rodar de novo nao duplica: apaga o que ele mesmo
-- semeou (marca `origem: seed-v1` dentro de cada linha) e semeia de
-- novo. Conteudo que voce tenha cadastrado pelo painel nao e tocado.
--
-- O card do app "Ferramentas APM" NAO entra aqui — nao e um arquivo, e
-- um atalho para o proprio app, e quem manda no acesso dele e a flag
-- `acesso.ferramentas`. Ele continua no index.html.
--
-- ATENCAO: isto e metade da tranca. O arquivo em si continua publico
-- por URL em /files/ ate a etapa do bucket privado. O que passa a
-- respeitar a fase comprada aqui e a LISTA.
-- ═══════════════════════════════════════════════════════════════

do $$
declare
  v_base timestamptz := now() - interval '1 day';
  v_qtd  int;
begin

  delete from public.conteudo where dados->>'origem' = 'seed-v1';

  insert into public.conteudo (tipo, fase_id, dados, criado_em) values
  ('materials', '1', '{"name": "Diagnóstico Financeiro", "type": "xlsx", "desc": "Mapeamento completo do financeiro: custos, margem e estrutura.", "sz": "21 KB", "origem": "seed-v1", "file": "diagnostico_financeiro_pro.xlsx"}'::jsonb, v_base + interval '0 seconds'),
  ('materials', '1', '{"name": "Precificação v2", "type": "xlsx", "desc": "Calculadora de preço por m² + complexidade + variáveis.", "sz": "12 KB", "origem": "seed-v1", "file": "precificacao_pro.xlsx"}'::jsonb, v_base + interval '1 seconds'),
  ('materials', '2', '{"name": "CRM Simplificado", "type": "xlsx", "desc": "Gestão de leads, funil comercial e acompanhamento por origem.", "sz": "11 KB", "origem": "seed-v1", "file": "crm_simplificado_pro.xlsx"}'::jsonb, v_base + interval '2 seconds'),
  ('materials', '3', '{"name": "PCP Simplificado", "type": "xlsx", "desc": "Controle de projetos, etapas e cronograma 60 dias úteis.", "sz": "12 KB", "origem": "seed-v1", "file": "pcp_simplificado_pro.xlsx"}'::jsonb, v_base + interval '3 seconds'),
  ('materials', '3', '{"name": "Painel de Indicadores", "type": "xlsx", "desc": "KPI 25/50/75/100 + aderência ao cronograma + comercial.", "sz": "13 KB", "origem": "seed-v1", "file": "painel_indicadores_pro.xlsx"}'::jsonb, v_base + interval '4 seconds'),
  ('materials', '3', '{"name": "Controle de Estoque", "type": "xlsx", "desc": "Gestão de material: entrada, saída e estoque mínimo por item.", "sz": "14 KB", "origem": "seed-v1", "file": "controle_estoque_pro.xlsx"}'::jsonb, v_base + interval '5 seconds'),
  ('materials', '3', '{"name": "Fluxograma Produtivo", "type": "html", "desc": "Do caderno técnico aprovado à entrega em obra — cada etapa, responsável e prazo esperado.", "sz": "", "origem": "seed-v1", "url": "apm-fluxograma.html"}'::jsonb, v_base + interval '6 seconds'),
  ('materials', '3', '{"name": "Checklist por Etapa", "type": "xlsx", "desc": "Verificação por etapa (corte, pré-montagem, expedição, instalação) — elimina retrabalho na origem.", "sz": "12 KB", "origem": "seed-v1", "file": "checklist_por_etapa_pro.xlsx"}'::jsonb, v_base + interval '7 seconds'),
  ('materials', '3', '{"name": "Kanban de Produção", "type": "xlsx", "desc": "Quadro visual por ambiente/projeto nos 9 checkpoints de fábrica e obra.", "sz": "9 KB", "origem": "seed-v1", "file": "kanban_producao_pro.xlsx"}'::jsonb, v_base + interval '8 seconds'),
  ('materials', '3', '{"name": "Cronograma Mestre", "type": "html", "desc": "Calculadora do ciclo de 60 dias úteis — datas-alvo por bloco a partir da aprovação do caderno técnico.", "sz": "", "origem": "seed-v1", "url": "apm-cronograma.html"}'::jsonb, v_base + interval '9 seconds'),
  ('materials', '0', '{"name": "Contrato — Cliente Final", "type": "html", "desc": "Modelo de contrato de venda de móveis planejados ao consumidor final, com campos em branco.", "sz": "27 KB", "origem": "seed-v1", "file": "08-contrato-cliente-final.html"}'::jsonb, v_base + interval '10 seconds'),
  ('materials', '0', '{"name": "Contrato de Trabalho CLT", "type": "html", "desc": "Contrato individual por prazo indeterminado: função, jornada, confidencialidade e rescisão.", "sz": "23 KB", "origem": "seed-v1", "file": "09-contrato-trabalho-clt.html"}'::jsonb, v_base + interval '11 seconds'),
  ('materials', '0', '{"name": "Contrato — Prestador de Serviços", "type": "html", "desc": "Dois modelos em um: prestador pessoa física e pessoa jurídica, com garantia pessoal do representante.", "sz": "28 KB", "origem": "seed-v1", "file": "10-contrato-prestador.html"}'::jsonb, v_base + interval '12 seconds'),
  ('materials', '4', '{"name": "Regulamento Interno", "type": "html", "desc": "Valores, organização, direitos, deveres, disciplina e ciência assinada por cada colaborador.", "sz": "16 KB", "origem": "seed-v1", "file": "11-regulamento-interno.html"}'::jsonb, v_base + interval '13 seconds'),
  ('materials', '4', '{"name": "Termo de Uso de Imagem", "type": "html", "desc": "Autorização individual de uso de imagem, com nota sobre guarda dos dados pela LGPD.", "sz": "13 KB", "origem": "seed-v1", "file": "12-autorizacao-uso-imagem.html"}'::jsonb, v_base + interval '14 seconds'),
  ('materials', '2', '{"name": "Checklist para Orçamento", "type": "html", "desc": "O que o projeto executivo precisa conter antes de você orçar. Planta baixa, layout, vistas, ambientes e estado da obra.", "sz": "14 KB", "origem": "seed-v1", "file": "01-checklist-orcamento.html"}'::jsonb, v_base + interval '15 seconds'),
  ('materials', '2', '{"name": "Checklist de Projeto de Arquitetura", "type": "html", "desc": "Grade de materiais e definições, ambiente por ambiente. Item indefinido não entra em produção.", "sz": "16 KB", "origem": "seed-v1", "file": "02-checklist-projeto-arquitetura.html"}'::jsonb, v_base + interval '16 seconds'),
  ('materials', '2', '{"name": "Ata de Reunião", "type": "html", "desc": "Assuntos, definições, alterações solicitadas e pendências — cada uma com dono e prazo.", "sz": "12 KB", "origem": "seed-v1", "file": "06-ata-de-reuniao.html"}'::jsonb, v_base + interval '17 seconds'),
  ('materials', '3', '{"name": "Levantamento Técnico e Status da Obra", "type": "html", "desc": "As duas conferências que andam juntas: instalações levantadas e obra pronta para receber marcenaria.", "sz": "18 KB", "origem": "seed-v1", "file": "03-levantamento-e-status-obra.html"}'::jsonb, v_base + interval '18 seconds'),
  ('materials', '3', '{"name": "Protocolo de Detalhamentos", "type": "html", "desc": "Entrega do escritório técnico para a fábrica, com assinatura de recebimento e controle de revisões.", "sz": "12 KB", "origem": "seed-v1", "file": "04-protocolo-detalhamentos.html"}'::jsonb, v_base + interval '19 seconds'),
  ('materials', '3', '{"name": "Checklist de Montagem e Logística", "type": "html", "desc": "Da conferência na fábrica à saída da obra: conduta, embalagem, transporte, montagem e entrega.", "sz": "16 KB", "origem": "seed-v1", "file": "05-checklist-montagem-logistica.html"}'::jsonb, v_base + interval '20 seconds'),
  ('materials', '3', '{"name": "Entrega Técnica", "type": "html", "desc": "Termo de inspeção por ambiente, recebimento, garantia e assinaturas das quatro partes.", "sz": "16 KB", "origem": "seed-v1", "file": "07-entrega-tecnica.html"}'::jsonb, v_base + interval '21 seconds'),
  ('materials', '3', '{"name": "KPI 25/50/75/100", "type": "xlsx", "desc": "Aderência a cronograma por ambiente — % planejado x % real, semáforo automático.", "sz": "12 KB", "origem": "seed-v1", "file": "kpi_25_50_75_100_pro.xlsx"}'::jsonb, v_base + interval '22 seconds')
  ;

  select count(*) into v_qtd from public.conteudo where dados->>'origem' = 'seed-v1';
  if v_qtd <> 23 then
    raise exception 'esperava 23 arquivos semeados, encontrei %', v_qtd;
  end if;

end $$;

-- Conferencia:
--   select fase_id, count(*) from public.conteudo group by 1 order by 1;
--   -> fase 0: 3 | fase 1: 2 | fase 2: 4 | fase 3: 12 | fase 4: 2
--
-- Voltar atras (apaga so o que este script semeou):
--   delete from public.conteudo where dados->>'origem'='seed-v1';
