# Checklist de liberação do SAENG Software SST

## Gate A — instalação local
- [ ] Pasta final criada sem apagar a V2
- [ ] Ambiente virtual recriado
- [ ] Compilação aprovada
- [ ] Todos os testes aprovados
- [ ] Login local aprovado
- [ ] Login por PFX aprovado
- [ ] Login por certificado instalado no Windows aprovado ou contingência manual validada
- [ ] Nenhum PFX/P12/PEM/KEY dentro do projeto
- [ ] Atalho silencioso aprovado
- [ ] Manifesto SHA-256 criado

## Gate B — dados e documentos
- [ ] Empresa, estabelecimento, trabalhador e matrícula conferidos
- [ ] CBO, setor, GHE e função conferidos
- [ ] Agentes da Tabela 24 conferidos
- [ ] Exames da Tabela 27 conferidos
- [ ] Responsáveis e registros profissionais válidos
- [ ] Procuração ou autorização válida
- [ ] Histórico de alterações preservado

## Gate C — Produção Restrita
- [ ] Ambiente `tpAmb=2`
- [ ] XML gerado
- [ ] XSD vigente aprovado
- [ ] XMLDSig validada
- [ ] Lote transmitido
- [ ] Protocolo registrado
- [ ] Consulta concluída
- [ ] Recibo individual de evento aceito
- [ ] Rejeições tratadas e revalidadas

## Gate D — Produção
- [ ] Revisão humana do evento
- [ ] Ambiente `tpAmb=1` explicitamente autorizado
- [ ] Certificado válido
- [ ] Procuração válida
- [ ] Backup verificado
- [ ] Evento piloto transmitido
- [ ] Protocolo oficial
- [ ] Processamento concluído
- [ ] Recibo individual arquivado

Sem a conclusão dos quatro gates, o sistema é candidato técnico e não deve ser apresentado como homologado oficialmente.