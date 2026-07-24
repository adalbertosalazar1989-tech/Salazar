# SAENG Software SST V2 — Reconstrutor controlado

Este repositório contém o **reconstrutor/instalador da V2**, destinado a evoluir a instalação completa `SAENG_Software_SST_0.3.2_PROD_CANDIDATE` já existente no computador.

Ele não substitui o núcleo completo por um protótipo menor. O instalador:

- valida `C:\SAENG_Software_SST`;
- cria backup reversível;
- copia o núcleo completo para `C:\SAENG_Software_SST_V2`;
- corrige o bloqueio indevido de sessão/certificado;
- preserva assinatura, XML/XSD, lotes, relatórios, documentos e auditoria;
- adiciona governança de planilhas, riscos químicos, autorizações e estrutura;
- aplica identidade visual local quando as imagens estiverem em `C:\SAENG_TEMP`;
- executa `pip check`, compilação, todos os testes e auditoria pasta por pasta;
- cria `C:\SAENG_Software_SST_V2_FINAL.zip` **sem senha**, somente se as validações forem aprovadas.

## Segurança

O pacote e o instalador **não contêm senha**. Arquivos `.pfx`, `.p12`, `.pem` e `.key` não são copiados para a V2, backup ou ZIP. A senha do certificado não é gravada em código, banco, `.env`, relatório ou log.

## Preparação

Mantenha a instalação completa atual em:

```text
C:\SAENG_Software_SST
```

Coloque as referências que devem ser indexadas localmente em:

```text
C:\SAENG_TEMP
```

Exemplos permitidos: planilhas XLSX, manuais PDF, procurações PDF, textos de tabelas e imagens PNG. Não coloque o certificado dentro dessa pasta.

## Instalação

Extraia o ZIP do reconstrutor e execute como administrador:

```text
INSTALAR_SAENG_V2.cmd
```

Alternativa PowerShell:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\INSTALAR_SAENG_V2.ps1 -Iniciar
```

## Resultado esperado

```text
C:\SAENG_Software_SST_V2
C:\SAENG_Software_SST_BACKUP_V2_AAAAMMDD_HHMMSS
C:\SAENG_Software_SST_V2_FINAL.zip
```

O sistema local abre em:

```text
http://127.0.0.1:8765
```

## Limite de validação

A aprovação automatizada confirma instalação e testes locais. A operação oficial ainda depende de certificado A1 válido, procuração compatível, Produção Restrita, retorno final e recibo individual do eSocial.
