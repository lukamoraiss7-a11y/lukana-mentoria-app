#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Publica os HTMLs de uma fase no bucket privado + na tabela `conteudo`.

Faz exatamente o que o painel do APM faz (index.html: admSubirArquivo), com uma
diferenca que importa: e' IDEMPOTENTE. O painel usa `publicar()`, que e' insert
puro sem upsert, e `renderMat` nao deduplica — foi assim que a Fase 5 ficou com
34 registros para 18 nomes em 07/08/2026. Este script le o que ja existe antes
de gravar e pula o que ja esta la.

Uso:
    export SUPABASE_SERVICE_KEY='eyJ...'      # chave service_role do projeto
    python3 publicar-fase.py 2                # numero da fase (1 a 6)
    python3 publicar-fase.py 2 --dry-run      # so mostra o que faria

A chave service_role ignora RLS por definicao. Pegar em:
  Supabase -> Project Settings -> API -> service_role (secret)
REVOGAR/ROTACIONAR depois de usar.
"""
import os, sys, json, re, glob, urllib.request, urllib.parse

PROJETO = 'frqoxmerrfucprtgvghm'
BUCKET  = 'materiais'
BASE    = os.path.dirname(os.path.abspath(__file__))
FONTE   = os.path.join(os.path.dirname(BASE), 'mentoria-conteudo', 'publicar')

API_REST    = 'https://%s.supabase.co/rest/v1' % PROJETO
API_STORAGE = 'https://%s.supabase.co/storage/v1' % PROJETO


def chave():
    k = os.environ.get('SUPABASE_SERVICE_KEY', '').strip()
    if not k:
        sys.exit('Falta SUPABASE_SERVICE_KEY no ambiente. Veja o cabecalho deste arquivo.')
    return k


def req(url, metodo='GET', corpo=None, tipo='application/json', extra=None):
    k = chave()
    h = {'apikey': k, 'Authorization': 'Bearer ' + k}
    if corpo is not None:
        h['Content-Type'] = tipo
    if extra:
        h.update(extra)
    r = urllib.request.Request(url, data=corpo, headers=h, method=metodo)
    try:
        with urllib.request.urlopen(r) as resp:
            d = resp.read()
            return resp.status, (json.loads(d) if d and d[:1] in b'[{' else d)
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode('utf-8', 'replace')


def titulo(caminho):
    """O nome que o aluno ve. Mesma regra do painel: o <title> do HTML."""
    with open(caminho, encoding='utf-8') as f:
        cabeca = f.read(4096)
    m = re.search(r'<title>([^<]+)</title>', cabeca, re.I)
    return m.group(1).strip() if m else os.path.basename(caminho).rsplit('.', 1)[0]


def tamanho(b):
    return '%d B' % b if b < 1024 else ('%d KB' % round(b / 1024) if b < 1048576
                                        else '%.1f MB' % (b / 1048576))


def slug(nome):
    import unicodedata
    s = unicodedata.normalize('NFD', nome)
    s = ''.join(c for c in s if unicodedata.category(c) != 'Mn')
    s = re.sub(r'[^A-Za-z0-9._-]+', '-', s).strip('-').lower()
    return s


def main():
    if len(sys.argv) < 2:
        sys.exit('Uso: publicar-fase.py <numero da fase> [--dry-run]')
    fase = int(sys.argv[1])
    seco = '--dry-run' in sys.argv
    # A pasta do bucket e o fase_id sao o INDICE do modulo: fase menos 1.
    # Errar isso publica a fase certa na pasta errada e o RLS bloqueia o aluno
    # que comprou — falha silenciosa, so aparece quando ele reclama.
    idx = str(fase - 1)
    sigla = 'f%d' % fase

    arquivos = sorted(glob.glob(os.path.join(FONTE, '%s-*.html' % sigla)))
    if not arquivos:
        sys.exit('Nenhum %s-*.html em %s' % (sigla, FONTE))

    print('Fase %d  ->  pasta "%s/" do bucket, fase_id "%s"' % (fase, idx, idx))
    print('%d arquivos em %s\n' % (len(arquivos), FONTE))

    # o que ja esta publicado nesta fase
    url = '%s/conteudo?select=id,dados&tipo=eq.materials&fase_id=eq.%s' % (API_REST, idx)
    st, existente = req(url)
    if st != 200:
        sys.exit('Nao consegui ler `conteudo` (%s): %s' % (st, existente))
    ja = {}
    for r in existente:
        d = r.get('dados') or {}
        if d.get('path'):
            ja[d['path']] = d.get('name', '?')
    print('Ja publicados nesta fase: %d registro(s), %d com arquivo no bucket.'
          % (len(existente), len(ja)))
    for r in existente:
        d = r.get('dados') or {}
        print('   - %s  (%s)' % (d.get('name', '?'), d.get('path') or d.get('file') or 'sem arquivo'))
    print()

    novos, pulados = 0, 0
    for caminho in arquivos:
        nome_arq = os.path.basename(caminho)
        destino = '%s/%s' % (idx, slug(nome_arq))
        nome = titulo(caminho)
        if destino in ja:
            print('  = %-46s ja publicado como "%s"' % (nome_arq, ja[destino]))
            pulados += 1
            continue
        dados = {'name': nome, 'type': 'html', 'desc': '',
                 'sz': tamanho(os.path.getsize(caminho)), 'path': destino}
        if seco:
            print('  + %-46s -> %s  |  "%s"' % (nome_arq, destino, nome))
            novos += 1
            continue
        with open(caminho, 'rb') as f:
            conteudo = f.read()
        # upsert no Storage: reenviar o mesmo caminho sobrescreve, nao duplica
        st, resp = req('%s/object/%s/%s' % (API_STORAGE, BUCKET, destino),
                       'POST', conteudo, 'text/html; charset=utf-8',
                       {'x-upsert': 'true'})
        if st not in (200, 201):
            print('  ! %s  FALHOU no upload (%s): %s' % (nome_arq, st, resp))
            continue
        st, resp = req('%s/conteudo' % API_REST, 'POST',
                       json.dumps({'tipo': 'materials', 'fase_id': idx,
                                   'dados': dados}).encode('utf-8'))
        if st not in (200, 201, 204):
            print('  ! %s  arquivo subiu, REGISTRO NAO (%s): %s' % (nome_arq, st, resp))
            continue
        print('  + %-46s "%s"' % (nome_arq, nome))
        novos += 1

    print('\n%s%d publicado(s), %d pulado(s) por ja existirem.'
          % ('[dry-run] ' if seco else '', novos, pulados))
    if not seco:
        st, depois = req(url)
        if st == 200:
            print('Total da fase %d agora: %d materiais.' % (fase, len(depois)))
        print('\nConfira em mentoria-app-self.vercel.app -> Admin -> Materiais.')


if __name__ == '__main__':
    main()
