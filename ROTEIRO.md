# Roteiro passo a passo — OpenShift Welcome API

Este documento descreve, em ordem, tudo o que você precisa fazer para rodar o projeto localmente, publicar a imagem no Docker Hub, fazer deploy no OpenShift e validar que a aplicação está funcionando na nuvem.

---

## Visão geral do fluxo

```
1. Preparar ambiente (Node, Docker, contas, CLI oc)
        ↓
2. Configurar o arquivo .env
        ↓
3. Testar localmente (npm ou Docker)
        ↓
4. Publicar imagem no Docker Hub
        ↓
5. Fazer login no OpenShift
        ↓
6. Deploy no cluster (Deployment + Service + Route)
        ↓
7. Validar na nuvem (pods, logs, endpoints)
```

**Comando único (após configurar tudo):**

```powershell
.\scripts\deploy-all.ps1
```

Ou:

```powershell
npm run deploy
```

---

## Etapa 0 — O que você precisa ter instalado

| Item | Para que serve | Onde obter |
|------|----------------|------------|
| **Node.js 18+** | Rodar a API localmente | https://nodejs.org |
| **Docker Desktop** | Construir e publicar a imagem | https://www.docker.com/products/docker-desktop |
| **Conta Docker Hub** | Hospedar a imagem pública do container | https://hub.docker.com |
| **Conta Red Hat** | Acessar o Developer Sandbox | https://developers.redhat.com/developer-sandbox |
| **CLI `oc`** | Login e deploy no OpenShift | https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest |
| **PowerShell** | Executar os scripts de automação | Já vem no Windows |
| **Git** (opcional) | Versionar o código no GitHub | https://git-scm.com |

### Verificar se está tudo instalado

Abra o PowerShell e execute:

```powershell
node -v          # deve retornar v18 ou superior
npm -v
docker info      # Docker Desktop precisa estar em "Running"
oc version       # CLI do OpenShift instalada
```

Se `docker info` falhar, abra o **Docker Desktop** e aguarde até o status ficar **Running**.

---

## Etapa 1 — Clonar ou abrir o projeto

```powershell
cd openshift-welcome-api
npm install
```

Isso instala a dependência `express` e prepara o ambiente local.

---

## Etapa 2 — Configurar o arquivo `.env`

O arquivo `.env` guarda suas credenciais e **não vai para o Git**.

```powershell
copy .env.example .env
```

Abra o `.env` e preencha os campos principais:

| Variável | O que preencher | Exemplo |
|----------|-----------------|---------|
| `DOCKER_HUB_USER` | Seu usuário do Docker Hub | `rafael230125` |
| `DOCKER_HUB_TOKEN` | Token com permissão de escrita (opcional) | *(deixe vazio para login interativo)* |
| `DOCKER_IMAGE_NAME` | Nome da imagem | `openshift-welcome-api` |
| `DOCKER_IMAGE_TAG` | Versão da imagem | `1.0` |
| `REDHAT_USERNAME` | Usuário da conta Red Hat | `cloud-open` |
| `OPENSHIFT_SERVER` | URL da API do cluster | `https://api.sandbox.x8e5.p1.openshiftapps.com:6443` |
| `OPENSHIFT_TOKEN` | Token de autenticação do `oc` | *(copiado do console)* |
| `OPENSHIFT_PROJECT` | Projeto no Sandbox | `cloud-open-dev` *(formato: `{usuario}-dev`)* |
| `OPENSHIFT_APP_NAME` | Nome da aplicação no cluster | `welcome-api` |
| `DEPLOY_STRATEGY` | `clean` ou `unique` | `clean` |
| `APP_PORT` | Porta da aplicação | `3000` |
| `APP_ENVIRONMENT` | Texto exibido em `/status` | `OpenShift` |

> **Importante (Developer Sandbox):** no Sandbox você **não pode criar projetos novos**. Use o projeto existente da sua conta, no formato `{REDHAT_USERNAME}-dev` (ex.: se seu usuário Red Hat é `cloud-open`, o projeto é `cloud-open-dev`).

---

## Etapa 3 — Testar a aplicação localmente

### Opção A: Node.js direto

```powershell
npm start
```

Em outro terminal:

```powershell
curl http://localhost:3000/
curl http://localhost:3000/status
```

**Respostas esperadas:**

- `GET /` → texto: `Aplicação executando no OpenShift com sucesso!`
- `GET /status` → JSON: `{"status":"online","ambiente":"OpenShift"}`

Para parar o servidor: `Ctrl + C`.

### Opção B: Container Docker local

```powershell
.\scripts\run-docker-local.ps1
```

Ou manualmente:

```powershell
docker build -t openshift-welcome-api:1.0 .
docker run --rm -p 3000:3000 openshift-welcome-api:1.0
```

Teste novamente com `curl http://localhost:3000/status`.

---

## Etapa 4 — Preparar o Docker Hub

1. Crie uma conta em https://hub.docker.com
2. Crie um repositório **público** chamado `openshift-welcome-api`
3. (Recomendado) Crie um **Access Token** com permissão **Read & Write**:
   - Acesse https://hub.docker.com/settings/security
   - Copie o token para `DOCKER_HUB_TOKEN` no `.env`

> A imagem precisa ser **pública** para o OpenShift conseguir baixá-la sem credenciais extras.

---

## Etapa 5 — Fazer login no OpenShift

### 5.1 Ativar o Developer Sandbox

1. Acesse https://developers.redhat.com/developer-sandbox
2. Crie ou entre com sua conta Red Hat gratuita
3. Ative o Sandbox e aguarde o cluster ficar disponível

### 5.2 Obter o token de login

No console web do OpenShift:

1. Clique no seu **nome de usuário** (canto superior direito)
2. Clique em **Copy login command** (Copiar comando de login)
3. Na página que abrir, clique em **Display Token**
4. Copie:
   - o **token** → cole em `OPENSHIFT_TOKEN` no `.env`
   - a **URL do servidor** → cole em `OPENSHIFT_SERVER` no `.env`

### 5.3 Instalar a CLI `oc` (se ainda não tiver)

No Windows, baixe o binário em:
https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/

Extraia o `oc.exe` e adicione a pasta ao **PATH** do sistema, ou coloque em uma pasta já acessível pelo terminal.

> **Não commite o `oc.exe` no Git.** O GitHub rejeita arquivos acima de 100 MB.

### 5.4 Executar o login

```powershell
oc login --token=SEU_TOKEN --server=https://api.sandbox...
```

Confirme que o login funcionou:

```powershell
oc whoami
oc project
```

Se o `.env` já estiver preenchido, os scripts fazem o login automaticamente usando `OPENSHIFT_TOKEN` e `OPENSHIFT_SERVER`.

---

## Etapa 6 — Deploy na nuvem

### Opção recomendada: deploy completo automatizado

Com Docker Desktop rodando, `.env` preenchido e `oc` no PATH:

```powershell
.\scripts\deploy-all.ps1
```

O script executa **3 etapas em sequência**:

| Etapa | Script | O que faz |
|-------|--------|-----------|
| 1/3 | `publish-dockerhub.ps1` | Build da imagem + push para o Docker Hub |
| 2/3 | `deploy-openshift.ps1` | Login, seleção de projeto, apply dos manifests |
| 3/3 | `validate-openshift.ps1` | Verifica pods, logs e testa os endpoints |

### O que acontece no OpenShift (Etapa 2/3)

1. Login automático com token do `.env`
2. Seleção do projeto (`OPENSHIFT_PROJECT` ou `{REDHAT_USERNAME}-dev`)
3. Remoção de recursos antigos (se `DEPLOY_STRATEGY=clean`)
4. Geração dos manifests em `openshift/.generated/`
5. Aplicação de:
   - **Deployment** — cria o Pod com a imagem do Docker Hub
   - **Service** — expõe a porta 3000 internamente
   - **Route** — cria URL pública HTTPS
6. Aguarda o rollout: `oc rollout status deployment/welcome-api`

### Executar etapas separadamente (debug)

```powershell
# Apenas build + push Docker Hub
.\scripts\publish-dockerhub.ps1

# Apenas deploy no OpenShift
.\scripts\deploy-openshift.ps1

# Apenas validação
.\scripts\validate-openshift.ps1
```

---

## Etapa 7 — Validar se o projeto está rodando na nuvem

### 7.1 Script automático

```powershell
.\scripts\validate-openshift.ps1
```

O script mostra:

- Status dos **Pods**
- Status do **Deployment**
- Status do **Service**
- URL da **Route**
- Últimas 20 linhas de **logs**
- Teste de `GET /` e `GET /status` na URL pública

### 7.2 Validação manual no terminal

```powershell
# Ver pods (deve estar Running 1/1)
oc get pods -l app=welcome-api

# Ver deployment
oc get deployment welcome-api

# Ver service
oc get svc welcome-api

# Ver route e URL pública
oc get route welcome-api
oc get route welcome-api -o jsonpath='https://{..spec.host}{"\n"}'

# Ver logs
oc logs deployment/welcome-api
oc logs -f deployment/welcome-api
```

Substitua `welcome-api` pelo nome real se usou `DEPLOY_STRATEGY=unique`.

### 7.3 Testar os endpoints na URL pública

Copie a URL da Route (ex.: `https://welcome-api-cloud-open-dev.apps.sandbox...`) e teste:

```powershell
curl https://SUA-ROUTE/
curl https://SUA-ROUTE/status
```

Ou abra a URL no navegador.

### Checklist de sucesso

- [ ] Pod em estado **Running** (`1/1`)
- [ ] Deployment com **1/1** réplicas disponíveis
- [ ] Route com host HTTPS gerado
- [ ] `GET /` retorna a mensagem de boas-vindas
- [ ] `GET /status` retorna `{"status":"online",...}`
- [ ] Logs mostram: `Servidor iniciado em http://0.0.0.0:3000`

### 7.4 Validação pelo console web do OpenShift

1. Acesse o Developer Sandbox no navegador
2. Vá em **Workloads → Pods** — confirme que o pod está **Running**
3. Vá em **Networking → Routes** — clique na URL da aplicação
4. A página deve exibir: `Aplicação executando no OpenShift com sucesso!`

---

## Estratégias de deploy

| Estratégia | Comportamento |
|------------|---------------|
| `clean` (padrão) | Reutiliza o nome `welcome-api` e a tag `1.0`; remove deployment/service/route antigos antes de recriar |
| `unique` | Gera nome e tag aleatórios (ex.: `welcome-api-a3k9m2`); útil para testes sem sobrescrever |

Defina no `.env`:

```env
DEPLOY_STRATEGY=clean
```

---

## Limpar recursos no OpenShift

Para remover deployment, service e route da última execução:

```powershell
.\scripts\cleanup-openshift.ps1
```

> No Sandbox, isso remove apenas os **recursos da aplicação** dentro do seu projeto — não apaga o projeto inteiro.

---

## Problemas comuns e soluções

### `docker info` falha / Docker API não responde

- Abra o Docker Desktop e aguarde ficar **Running**
- Reinicie o terminal e teste: `docker info`

### `access token has insufficient scopes` (Docker Hub)

- Crie um token com permissão **Read & Write** em https://hub.docker.com/settings/security
- Atualize `DOCKER_HUB_TOKEN` no `.env`
- Ou deixe `DOCKER_HUB_TOKEN` vazio e use `docker login` interativo

### `CLI 'oc' nao encontrada`

- Instale o cliente OpenShift e adicione ao PATH
- Teste: `oc version`

### `You may not request a new project via this API` (Sandbox)

- Use o projeto existente: `OPENSHIFT_PROJECT={seu-usuario-redhat}-dev`
- Exemplo: `OPENSHIFT_PROJECT=cloud-open-dev`

### Pod com `ImagePullBackOff`

- Confirme que a imagem está **pública** no Docker Hub
- Verifique se `DOCKER_HUB_USER` e a tag estão corretos
- Diagnóstico:

```powershell
oc describe pod -l app=welcome-api
oc get events --sort-by=.lastTimestamp
```

### Route não responde / probe falhando

```powershell
oc logs deployment/welcome-api
oc describe route welcome-api
oc get svc welcome-api
```

A aplicação escuta em `0.0.0.0:3000` e o endpoint `/status` é usado pelos health checks.

---

## Referência rápida de comandos

```powershell
# Local
npm install
npm start
.\scripts\run-docker-local.ps1

# Publicar e deploy completo
.\scripts\deploy-all.ps1

# Apenas validar na nuvem
.\scripts\validate-openshift.ps1

# Limpar recursos
.\scripts\cleanup-openshift.ps1

# Login manual OpenShift
oc login --token=TOKEN --server=URL
oc whoami
oc project
```

---

## Arquitetura na nuvem

```
Usuário (navegador/curl)
        ↓
   OpenShift Route (HTTPS público)
        ↓
   Service (porta 3000)
        ↓
   Pod (container Docker)
        ↓
   Node.js / Express (src/server.js)
```

A imagem do container vem do Docker Hub:

```
docker.io/SEU_USUARIO/openshift-welcome-api:1.0
```

---

## Próximos passos (opcional)

- Publicar o código no GitHub
- Configurar CI/CD para build e deploy automático
- Adicionar variáveis de ambiente no Deployment via ConfigMap/Secret
- Escalar réplicas no `deployment.yaml`

Para mais detalhes técnicos, consulte o [README.md](README.md).
