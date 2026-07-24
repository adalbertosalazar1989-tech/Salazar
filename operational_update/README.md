# SAENG Software SST V2 — atualização operacional integrada

Esta atualização transforma a V2 instalada em uma central operacional integrada ao banco principal.

## O que é implementado

- banco integrado com tabelas para estabelecimentos, GHE, funções, produtos, substâncias, exames, exposições, autorizações, importações, inconsistências e homologação;
- motor de riscos com validação de agentes químicos, Tabela 24, avaliação quantitativa, EPC/EPI e Tabela 27;
- geração de rascunho S-2240 no cadastro principal de eventos;
- importação integral de XLSX: cada linha é importada ou registrada como inconsistência;
- registro de autorizações e procurações com vigência e link de conferência oficial;
- central de inconsistências;
- checklist de Produção Restrita e Produção com protocolo e recibo;
- item de menu integrado ao sistema principal;
- backup reversível e testes antes da conclusão.

## Limite jurídico e técnico

A atualização não concede procurações, não acessa senha GOV.BR, não automatiza MFA e não faz scraping do e-CAC.

A expressão **homologado oficialmente** somente pode ser usada depois de executar os cenários no Ambiente Nacional, obter protocolo, processamento final e recibo individual. O software registra essas evidências, mas não pode fabricar a homologação.

## Instalação

1. Mantenha `C:\SAENG_Software_SST_V2` instalado.
2. Feche o navegador e a janela do servidor SAENG.
3. Extraia este pacote.
4. Clique com o botão direito em `ATUALIZAR_SAENG_V2_OPERACIONAL.cmd` e escolha **Executar como administrador**.
5. Aguarde compilação, testes e smoke test.
6. Abra `http://127.0.0.1:8765/operacional`.

## Estado seguro aplicado

```text
APP_VERSION=2.1.0-rc2
TRANSMISSION_MODE=MOCK
ALLOW_REAL_TRANSMISSION=false
ALLOW_PRODUCTION_TRANSMISSION=false
ESOCIAL_ENVIRONMENT=2
```

A Produção Restrita e a Produção devem ser liberadas somente depois da conferência do certificado, autorização, XML/XSD, assinatura e cenários de homologação.
