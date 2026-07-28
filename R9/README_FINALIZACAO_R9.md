# SAENG Software SST R9 — Finalização controlada

## Objetivo

Este pacote cria um candidato isolado a partir da instalação canônica `C:\SAENG_Software_SST_V2`, preserva backup, executa gates de engenharia e impede que uma versão com bloqueadores seja empacotada como final.

A rotina **não habilita Produção oficial automaticamente**. A transmissão com efeito jurídico somente pode ser liberada depois de um evento real e devido retornar protocolo, processamento e recibo individual oficiais em `tpAmb=1`.

## O que o pacote executa

1. valida a instalação existente;
2. cria backup reversível fora da árvore ativa;
3. cria `C:\SAENG_Software_SST_R9_CANDIDATE`;
4. exclui certificados, chaves privadas, caches, ambientes virtuais e backups da cópia;
5. força configuração fail-closed em Produção Restrita;
6. gera inventário SHA-256;
7. cria ambiente Python limpo;
8. instala dependências e ferramentas de qualidade;
9. executa `pip check`, `compileall`, `pytest`, Ruff, Bandit e `pip-audit`;
10. executa o gate arquitetural R9;
11. cria ZIP apenas quando não existem bloqueadores ou achados altos.

## Bloqueadores conhecidos que o gate procura

- certificado ou chave privada dentro do projeto;
- segredo persistido em `.env`;
- produção habilitada por padrão;
- banco paralelo `saeng_v2_extensions.db`;
- normalização de CNPJ que remove letras;
- ausência de Alembic;
- múltiplas bases ORM;
- ausência de XSD;
- estados MOCK misturados ao código operacional;
- estrutura mínima incompleta.

## Execução

1. mantenha a versão atual intacta em `C:\SAENG_Software_SST_V2`;
2. extraia a pasta `R9`;
3. clique com o botão direito em `EXECUTAR_FINALIZACAO_R9.cmd`;
4. execute como administrador;
5. aguarde a conclusão dos gates.

Alternativa PowerShell:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\FINALIZAR_SAENG_R9.ps1 -Iniciar
```

## Resultados

Quando os gates locais forem aprovados:

```text
C:\SAENG_Software_SST_R9_CANDIDATE
C:\SAENG_Software_SST_BACKUP_R9_AAAAMMDD_HHMMSS
C:\SAENG_Software_SST_R9_CANDIDATE.zip
```

As evidências serão gravadas em:

```text
C:\SAENG_Software_SST_R9_CANDIDATE\docs\evidence\r9_AAAAMMDD_HHMMSS
```

## Interpretação dos resultados

### `LOCAL_GATE_READY`

O artefato passou nos gates locais. Isso não equivale a homologação do eSocial.

### `BLOCKED`

O relatório `R9_GATE_REPORT.json` lista cada achado, severidade, evidência e tratamento. O ZIP não é criado.

## Gate oficial posterior

A liberação jurídica exige, no mínimo:

- certificado A1 válido e autorizado;
- empresa real selecionada;
- procuração compatível quando o transmissor não for o empregador;
- evento real revisado por profissional responsável;
- XML no leiaute vigente;
- XSD e XMLDSig aprovados;
- envio ao endpoint oficial de Produção;
- protocolo oficial;
- consulta do processamento;
- recibo individual oficial;
- conferência no ambiente Web do eSocial;
- preservação de XML, SOAP, hashes, protocolo, retorno e recibo.

## Estado do repositório

Este repositório contém o reconstrutor e os gates. O núcleo completo continua na instalação local do usuário. Alterações de domínio, fila, banco, autenticação, XML, SOAP e interface precisam ser aplicadas sobre o código-fonte canônico e comprovadas pelos testes do próprio produto.
