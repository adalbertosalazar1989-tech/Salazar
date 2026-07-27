# SAENG Software SST — Dossiê consolidado de erros e soluções

## 1. Redirecionamento contínuo para `/login`
**Causa:** `require_login()` exigia sessão e certificado A1 para qualquer página. O login local era aceito, mas bloqueado logo depois.

**Solução definitiva:** a sessão controla a navegação; o certificado permanece obrigatório apenas para assinatura, prontidão e transmissão oficial.

## 2. CSV retornando HTML
**Causa:** a rota era interceptada pelo redirecionamento de autenticação antes do `FileResponse`.

**Solução:** corrigir a autenticação global e validar o `Content-Type` nos testes.

## 3. Seis testes falhando
**Causa:** o mesmo bloqueio afetava eventos, documentos, relatórios, governança e painel.

**Solução:** o finalizador executa `compileall` e `pytest -q`; qualquer falha interrompe a instalação.

## 4. Mockup usado como tela real
**Causa:** a imagem de referência do layout foi usada como fundo/splash, duplicando campos e botões.

**Solução:** a tela deve ser HTML/CSS funcional. O finalizador remove referências ao splash e ao mockup no login.

## 5. Títulos e avisos duplicados
**Causa:** o formulário original foi inserido dentro de uma nova moldura sem eliminar elementos repetidos.

**Solução:** bloco único, idempotente, com contingência manual recolhida.

## 6. Porta 8765 ocupada — Errno 10048
**Causa:** duas instâncias do Uvicorn foram abertas.

**Solução:** launcher silencioso consulta a porta, reutiliza a instância já ativa e não encerra processos alheios.

## 7. Janela preta permanente
**Causa:** o servidor era iniciado por `.bat` em modo console.

**Solução:** atalho aponta para `pythonw.exe`; o servidor roda sem console e grava falhas em `storage/launcher_server.log`.

## 8. Aviso “Fornecedor desconhecido”
**Causa:** execução diária do BAT baixado.

**Solução:** instalação única e uso diário do atalho local `.lnk`.

## 9. Ícone genérico ou com bordas brancas
**Causa:** atalho apontando para BAT ou conversão de ICO defeituosa.

**Solução:** usar o melhor ICO já validado no projeto e fixar `IconLocation` no atalho. A marca não é redesenhada.

## 10. Logo interna antiga “SS”
**Causa:** placeholder do protótipo permaneceu nos templates.

**Solução:** substituir por `logo_saeng_transparente.png` sem alterar rotas, textos funcionais ou banco.

## 11. Procura manual do PFX/P12 a cada entrada
**Causa:** páginas web não podem preencher automaticamente um `<input type=file>`.

**Solução:** integração com `Cert:\CurrentUser\My`. Certificados válidos, exportáveis e com chave privada são carregados somente em memória. O formulário manual permanece como contingência.

## 12. Certificado não exportável
**Causa:** política da chave privada impede exportação.

**Solução:** certificados não exportáveis são ignorados pelo acesso automático. Nenhuma política de segurança é contornada.

## 13. `favicon.ico` 404
**Causa:** navegador solicitava o caminho padrão sem arquivo correspondente.

**Solução:** copiar o ICO validado para `app/static/favicon.ico` e inserir o link nos templates.

## 14. PowerShell com `if` dentro de cast
**Causa:** construções como `[byte](if (...) {...})` são inválidas no Windows PowerShell 5.1.

**Solução:** o finalizador principal foi implementado em Python 3.11; o PowerShell ficou restrito a operações nativas do Windows.

## 15. ZIP negado porque já existia
**Causa:** criação sem remover ou versionar o destino anterior.

**Solução:** a saída anterior é removida antes da compactação e o novo ZIP é criado sem senha.

## 16. Pastas vazias
**Causa:** diretórios operacionais ainda sem uso ficavam vazios.

**Solução:** diretórios obrigatórios recebem `.keep` explicativo até terem conteúdo real.

## 17. Risco de declarar “homologado” apenas com testes locais
**Causa:** confusão entre teste do código e processamento oficial do eSocial.

**Solução:** quatro gates independentes: instalação local, dados/documentos, Produção Restrita e Produção. Somente protocolo e recibo oficial fecham a validação de transmissão.

## Regra de segurança
A instalação não deve manter PFX, P12, PEM, KEY ou senha do certificado dentro do projeto, backup ou ZIP.