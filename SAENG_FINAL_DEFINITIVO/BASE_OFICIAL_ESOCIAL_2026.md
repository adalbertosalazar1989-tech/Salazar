# Base oficial adotada — julho de 2026

A validação normativa e técnica deve usar fontes oficiais:

- Portal eSocial: https://www.gov.br/esocial/pt-br
- Documentação técnica: https://www.gov.br/esocial/pt-br/documentacao-tecnica/documentacao-tecnica
- Leiautes S-1.3 consolidados até NT 06/2026 rev. 09/04/2026
- Esquemas XSD S-1.3 vigentes, inclusive pacote do CNPJ alfanumérico com produção em 01/07/2026
- MOS S-1.3 consolidado até a Nota Orientativa 11/2026
- Manual de Orientação do Desenvolvedor do eSocial v1.15
- Mensagens do Sistema v2.5
- Pacote de Comunicação eSocial v1.6
- Regras de validação do Anexo II
- Gov.br — orientações de login com certificado digital
- Microsoft Learn — provedor `Cert:` do PowerShell

## Princípios incorporados

1. `tpAmb=2` para Produção Restrita; `tpAmb=1` somente após liberação formal.
2. XML precisa respeitar leiaute e XSD vigentes.
3. Protocolo do lote e recibo individual do evento são registros diferentes.
4. Produção Restrita é gate obrigatório, mas não substitui o teste final em produção.
5. Certificado A1 e procuração devem corresponder ao empregador ou representante autorizado.
6. Portal web gov.br e transmissão por Web Service são fluxos distintos.
7. O FastAPI e os Web Services XML/TLS não dependem estruturalmente de Java. Java somente deve ser instalado quando uma ferramenta externa específica o exigir.
8. A versão oficial somente pode ser declarada operacional após protocolo e recibo individual reais.