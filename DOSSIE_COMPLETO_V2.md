# SAENG Software SST V2 — Dossiê técnico, funcional e de reconstrução

**Versão de desenvolvimento:** 2.0.0-rc1  
**Modelo de instalação:** aplicação web local, executada em Python/FastAPI e aberta no navegador  
**Diretório previsto:** `C:\SAENG_Software_SST_V2`  
**Política de implantação:** preservar a versão 0.3.2 e seu backup até a conclusão de testes, Produção Restrita e restauração controlada.

---

## 1. Objetivo da V2

A V2 não é um protótipo isolado e não deve reduzir a cobertura da versão 0.3.2. O instalador reconstrói a nova pasta a partir do núcleo completo já instalado, preserva os dados locais autorizados, corrige falhas de sessão, incorpora a identidade visual SAENG e adiciona uma camada de governança para planilhas, autorizações, motor de riscos e auditoria estrutural.

A versão somente pode ser considerada:

- **validada localmente** depois de compilação, `pip check`, testes automatizados e auditoria de pastas;
- **homologada em Produção Restrita** depois de eventos reais de teste processados no `tpAmb=2`;
- **operacional em produção** depois de certificado válido, autorização vigente, transmissão controlada, consulta final e recibo individual oficial.

Nenhum software consegue garantir antecipadamente que todo evento será aceito pelo Ambiente Nacional. A aceitação depende dos dados, da sequência cadastral, das regras vigentes, do certificado, da procuração e do retorno oficial.

---

## 2. Diagnóstico da versão reduzida `Salazar-main`

O pacote reduzido anteriormente disponibilizado continha um único `app.py`, cadastro básico de empresas, trabalhadores, riscos, exames e eventos locais. Ele não equivalia ao núcleo 0.3.2 e não deveria substituir a instalação antiga.

Principais lacunas identificadas nesse pacote reduzido:

- não possuía a arquitetura modular completa da versão 0.3.2;
- não continha os 52 XSDs e o ciclo robusto de validação;
- não preservava todos os módulos de documentos, lotes, relatórios, PPP, diagnóstico, governança e atualização;
- gerava XML simplificado, inadequado para ser tratado como XML final do eSocial;
- tinha poucos testes e não comprovava a regressão integral;
- não migrava o banco e os documentos da instalação existente;
- não possuía auditoria pasta por pasta nem manifesto SHA-256 completo.

A reconstrução V2 corrige a estratégia: o núcleo completo instalado é copiado, corrigido e expandido, em vez de substituído por uma aplicação menor.

---

## 3. Funcionalidades preservadas da versão 0.3.2

### 3.1 Núcleo e infraestrutura

- aplicação local em `127.0.0.1:8765`;
- Python 3.11+;
- FastAPI, Jinja2 e servidor Uvicorn;
- SQLite/SQLAlchemy;
- armazenamento local de banco, documentos, XMLs e relatórios;
- ambiente virtual próprio `.venv`;
- instalação, diagnóstico, execução, testes e backup por scripts Windows;
- auditoria de ações;
- configurações por `.env`;
- modos `MOCK`, `RESTRICTED` e `PRODUCTION`, com travas distintas.

### 3.2 Cadastros e governança

- responsável SST;
- empresas e estabelecimentos;
- autorização/procuração por empresa;
- até cinco e-mails operacionais por empresa;
- trabalhadores, CPF, matrícula, categoria, CBO, função, setor e admissão;
- ficha e histórico ocupacional;
- documentos técnicos por empresa;
- upload e extração assistida;
- revisão humana antes da aplicação de dados;
- importação XLSX de trabalhadores e eventos.

### 3.3 Eventos SST

- S-2210 — Comunicação de Acidente de Trabalho;
- S-2220 — Monitoramento da Saúde do Trabalhador;
- S-2240 — Condições Ambientais do Trabalho — Agentes Nocivos;
- S-3000 — Exclusão de Eventos;
- inclusão, retificação e exclusão conforme requisitos;
- validação de campos, datas, CPF/CNPJ, Tabelas 24 e 27;
- geração de identificador de evento;
- construção de XML S-1.3;
- validação XSD;
- assinatura XMLDSig RSA-SHA256;
- fila e processamento assíncrono;
- lote de um a cinquenta eventos;
- protocolo, consulta, retorno, advertência, rejeição e recibo individual;
- relatório individual e consolidado;
- pacote ZIP com manifesto e evidências;
- PPP gerencial, sem se apresentar como PPP eletrônico oficial.

### 3.4 Segurança e operação

- login local de recuperação;
- login principal por certificado A1 quando necessário;
- PFX e senha somente na memória da sessão;
- metadados do certificado gravados sem chave privada;
- bloqueio de combinação inválida entre modo, ambiente e endpoint;
- validação dos hosts oficiais;
- confirmação expressa antes de envio com efeito jurídico;
- diagnóstico de banco, schemas, certificado, internet, SMTP e modo;
- monitor de atualizações oficiais;
- relatórios PDF, CSV e ZIP;
- backup local;
- trilha de auditoria;
- assistência operacional local.

---

## 4. Erros encontrados e correções obrigatórias

### 4.1 Redirecionamento indevido para `/login`

**Causa:** a função global de autenticação exigia certificado sempre que `CERTIFICATE_LOGIN_REQUIRED=true`, inclusive para navegação, relatórios, importações e testes com login local.

**Efeitos observados:**

- painel retornava a tela de login depois de autenticação local;
- CSV era substituído por HTML de login;
- criação de evento retornava `/login` em vez do identificador;
- upload de documento e páginas protegidas falhavam;
- cadastro de metadados do certificado não era concluído;
- sete testes falhavam como consequência do mesmo bloqueio central.

**Correção V2:**

- `require_login()` exige somente sessão autenticada;
- o A1 continua obrigatório exclusivamente em assinatura, prontidão e transmissão;
- `CERTIFICATE_LOGIN_REQUIRED=false` é aplicado como padrão seguro;
- as travas de produção permanecem independentes e ativas.

### 4.2 Diferença entre protocolo e recibo

A interface e os relatórios devem apresentar separadamente:

- protocolo de recepção do lote;
- situação de processamento;
- retorno integral;
- resultado de cada evento;
- advertências;
- rejeições;
- recibo individual de evento aceito.

Protocolo não comprova cumprimento da obrigação. O comprovante final é o recibo individual associado ao retorno aceito.

### 4.3 Certificado e senha

- o arquivo PFX/P12 não entra no código-fonte;
- não é copiado para a pasta V2;
- não é incluído em backup ou ZIP;
- a senha não é gravada em banco, `.env`, log ou documentação;
- o operador seleciona o certificado apenas durante a sessão local;
- ao sair, o material é removido da memória do processo.

### 4.4 Pastas vazias e estrutura incompleta

A V2 cria todas as pastas operacionais e adiciona `.keep` quando uma pasta ainda não possui registros. A auditoria verifica:

- arquivos obrigatórios;
- pastas obrigatórias;
- diretórios vazios;
- arquivos secretos proibidos;
- manifesto SHA-256;
- relatório final de aprovação ou reprovação.

### 4.5 Atualização e rollback

Nenhuma atualização altera silenciosamente o sistema. O fluxo correto é:

1. detectar mudança em fonte oficial;
2. registrar aviso;
3. revisar aplicabilidade;
4. criar backup;
5. aplicar mudança em cópia;
6. executar testes;
7. aprovar ou restaurar.

---

## 5. Identidade visual V2

A interface utiliza a identidade SAENG:

- azul-marinho profundo;
- dourado institucional;
- branco e cinza-claro para leitura;
- logomarca central com acabamento dourado;
- tela de abertura com painel institucional e cartão de acesso;
- sidebar e navegação sincronizadas;
- cartões, alertas, tabelas e botões com hierarquia consistente;
- responsividade para notebooks, tablets e celulares.

Os arquivos gráficos são importados localmente durante a instalação. O repositório público não armazena imagens privadas nem documentos do cliente.

---

## 6. Fontes complementares incorporadas localmente

A pasta `imports\references` pode receber, entre outros:

- Controle Financeiro;
- Controle de Envios do eSocial SST;
- Agenda Empresarial Estratégica;
- Controle SMS/SST Comercial;
- Planilha Mestra de Riscos Ocupacionais;
- Controle de ASO NR-07/eSocial;
- manual de orientação;
- tabelas S-1.3;
- documentos de procuração/autorização;
- identidade visual.

A extensão V2:

- calcula SHA-256;
- classifica cada fonte;
- identifica abas, dimensões e cabeçalhos das planilhas;
- registra metadados em banco separado;
- identifica documentos de autorização por texto;
- extrai escopo e vigência para conferência;
- não altera dados do núcleo automaticamente;
- exige validação humana antes de qualquer uso operacional.

---

## 7. Motor mestre de riscos ocupacionais

### 7.1 Encadeamento

`Empresa → estabelecimento → setor → GHE → função → CBO → atividade → risco → produto → substância → CAS → agente/Tabela 24 → avaliação → EPC/EPI → exame/Tabela 27 → S-2240/S-2220`.

### 7.2 Agentes químicos

Não é suficiente registrar “tinta”, “solvente”, “graxa”, “cimento”, “óleo” ou outro nome comercial. O sistema deve exigir:

- produto comercial;
- composição/substância;
- CAS, quando disponível;
- código e descrição da Tabela 24;
- forma de exposição;
- via de exposição;
- frequência e tempo;
- avaliação qualitativa ou quantitativa;
- intensidade/concentração;
- unidade;
- técnica ou norma de medição;
- limite de tolerância e nível de ação, quando aplicáveis;
- EPC;
- EPI;
- documento/CA;
- eficácia;
- exame correspondente;
- código da Tabela 27;
- periodicidade definida no PCMSO.

O software deve distinguir:

- risco ocupacional do PGR;
- agente nocivo previdenciário da Tabela 24;
- caracterização de insalubridade pela NR-15;
- exame médico definido no PCMSO.

Esses conceitos podem se relacionar, porém não são equivalentes.

### 7.3 Código 09.01.001

O código de ausência de agente nocivo previdenciário:

- não significa ausência de todo risco ocupacional;
- não pode coexistir indevidamente com agentes nocivos no mesmo contexto;
- bloqueia o grupo EPC/EPI específico do evento quando aplicado conforme a regra;
- exige coerência com o inventário de riscos e documentação técnica.

---

## 8. Autorizações e permissões

A V2 registra a evidência documental e o escopo de cada autorização. Ela não cria, concede ou amplia permissão governamental.

Regras:

- aplicar o princípio do menor privilégio;
- para operação SST, registrar o escopo efetivamente concedido;
- não marcar “todos os serviços” quando não houver necessidade contratual;
- não armazenar senha GOV.BR do cliente;
- não automatizar MFA;
- não fazer scraping de página privada;
- não considerar o status interno como confirmação oficial;
- conferir vigência e escopo no e-CAC antes da transmissão.

A consulta automática de “Minhas Autorizações” não é prometida porque depende de sessão privada, autenticação e disponibilidade de interface oficial. O sistema oferece link, registro documental e conferência assistida.

---

## 9. Integração eSocial

### 9.1 Fluxo

`dados → validação de negócio → XML → XSD → XMLDSig → verificação da assinatura → lote → mTLS/SOAP → protocolo → consulta → retorno por evento → recibo ou rejeição`.

### 9.2 Ambientes

- `MOCK`: treinamento local, sem comunicação externa;
- `RESTRICTED`, `tpAmb=2`: Produção Restrita oficial, sem efeito jurídico;
- `PRODUCTION`, `tpAmb=1`: ambiente com efeito jurídico quando o evento é aceito.

### 9.3 Prontidão

A tentativa controlada exige:

- empresa ativa;
- CNPJ e estabelecimento corretos;
- autorização/procuração vigente;
- responsável SST conferido;
- A1 válido e compatível;
- XSD íntegro;
- XML válido;
- assinatura válida;
- endpoint oficial;
- ambiente correto;
- confirmação consciente do operador.

A interface deve informar **“Pronto para tentativa controlada”**, e não “aceitação garantida”.

---

## 10. Java e compatibilidade

O software integrador não depende de applet Java do navegador. A assinatura ocorre por biblioteca criptográfica sobre o XML. O componente Java eventualmente utilizado em páginas governamentais pertence ao fluxo do portal, não ao núcleo de Web Services.

Plataforma oficialmente suportada pela V2 local:

- Windows 10 64 bits atualizado;
- Windows 11 64 bits atualizado;
- Python 3.11 ou superior;
- Chrome ou Edge atualizado.

Windows XP, Windows 7 e Windows 8/8.1 não devem ser tratados como ambientes suportados por estarem fora de suporte e não oferecerem base adequada de segurança, TLS e atualizações.

Tablets, iOS e Android podem acessar uma interface responsiva quando o administrador configurar acesso seguro em rede. O agente que mantém o A1 e realiza assinatura/transmissão deve permanecer no computador Windows autorizado. A abertura indiscriminada da porta na rede não é feita pelo instalador.

---

## 11. Estrutura da pasta V2

```text
C:\SAENG_Software_SST_V2\
├── .env
├── .venv\
├── requirements.txt
├── START_SAENG_SST.bat
├── EXECUTAR_TESTES.bat
├── BACKUP_LOCAL.bat
├── MANIFEST_SHA256_V2.txt
├── app\
│   ├── main.py
│   ├── config.py
│   ├── database.py
│   ├── models.py
│   ├── validators.py
│   ├── importers.py
│   ├── reports.py
│   ├── v2_extensions.py
│   ├── esocial\
│   ├── templates\
│   └── static\
├── schemas\
│   └── S-1.3\
├── imports\
│   └── references\
├── storage\
│   ├── documents\
│   ├── uploads\
│   ├── xml\
│   ├── reports\
│   ├── backups\
│   ├── logs\
│   └── temp\
├── docs\
│   ├── DOSSIE_COMPLETO_V2.md
│   ├── RELATORIO_TESTES_V2.txt
│   ├── RELATORIO_AUDITORIA_PASTAS_V2.txt
│   ├── evidencias\
│   └── manuais\
├── scripts\
│   ├── AUDITAR_PASTAS_V2.ps1
│   └── build_icon.py
└── tests\
```

Pastas operacionais ainda sem registros recebem `.keep`, evitando diretórios vazios no pacote.

---

## 12. Processo de instalação e validação

1. verificar a versão completa em `C:\SAENG_Software_SST`;
2. criar backup reversível sem certificado/chave;
3. copiar o núcleo para `C:\SAENG_Software_SST_V2`;
4. aplicar correção da sessão;
5. registrar extensão V2;
6. configurar `MOCK`, `tpAmb=2` e envio real bloqueado;
7. copiar referências locais permitidas;
8. aplicar logo e abertura;
9. criar novo ambiente virtual;
10. instalar dependências;
11. executar `pip check`;
12. compilar código;
13. executar todos os testes;
14. indexar referências;
15. auditar pastas e segredos;
16. gerar manifesto SHA-256;
17. criar atalho;
18. gerar ZIP final local sem senha.

Se qualquer teste ou auditoria impeditiva falhar, o instalador não cria o ZIP final.

---

## 13. Critérios de aceite

### 13.1 Aceite local

- instalação concluída;
- `pip check` sem erro;
- compilação sem erro;
- todos os testes aprovados;
- rotas principais renderizadas;
- login local funcional;
- certificado de teste processado somente em memória;
- documentos, CSV, PDF e ZIP com tipos corretos;
- geração e validação de eventos;
- pacote sem PFX/P12/chave;
- auditoria estrutural aprovada;
- manifesto SHA-256 criado;
- backup e restauração testáveis.

### 13.2 Aceite em Produção Restrita

- S-2210 inclusão/retificação/exclusão;
- S-2220 com vários procedimentos;
- S-2240 com agente químico;
- S-2240 com múltiplos agentes;
- S-2240 com 09.01.001 válido;
- S-3000 vinculado ao recibo correto;
- lote misto dentro das regras;
- protocolo;
- consulta;
- advertência;
- rejeição tratada;
- recibo de evento aceito no ambiente restrito.

### 13.3 Aceite de produção

- A1 novo e seguro;
- autorização/procuração conferida;
- evento real necessário e revisado;
- transmissão de um evento no primeiro ciclo;
- protocolo arquivado;
- consulta final;
- recibo individual oficial;
- pacote de evidências;
- auditoria e backup.

---

## 14. Segurança imediata do certificado

Um certificado e sua senha nunca devem ser publicados, anexados a repositório, mantidos em pasta compartilhada ou incluídos no instalador. Quando uma senha foi exposta fora do fluxo operacional controlado, a conduta recomendada é gerar nova proteção para o arquivo ou providenciar substituição/revogação conforme a avaliação do titular e da autoridade certificadora.

A V2 não incorpora a senha fornecida em mensagens, arquivos de configuração, banco, documentação ou código.

---

## 15. Encerramento

A V2 é construída como evolução controlada do núcleo completo 0.3.2. Ela preserva funcionalidades, corrige o bloqueio de autenticação, incorpora planilhas e documentos como fontes revisáveis, adiciona governança de autorizações e riscos químicos, melhora a identidade visual e cria uma auditoria estrutural que impede a entrega com arquivos obrigatórios ausentes ou segredos dentro da pasta.

A versão antiga somente deve ser arquivada depois de:

1. migração conferida;
2. testes aprovados;
3. backup restaurado em ensaio;
4. Produção Restrita concluída;
5. primeiro recibo oficial confirmado.
