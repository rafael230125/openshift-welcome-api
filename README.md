# OpenShift Welcome API

API web simples de mensagem de boas-vindas, containerizada com Docker e preparada para deploy no Red Hat OpenShift.

## Endpoints

| Método | Rota | Resposta |
|--------|------|----------|
| GET | `/` | Texto: `Aplicação executando no OpenShift com sucesso!` |
| GET | `/status` | JSON: `{ "status": "online", "ambiente": "OpenShift" }` |

## Arquitetura

```
Usuário → OpenShift Route → Service → Pod → Container Docker → Node.js/Express
```

## Pré-requisitos

- [Node.js](https://nodejs.org/) 18 ou superior
- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- Conta no [Docker Hub](https://hub.docker.com)
- Acesso ao [Red Hat Developer Sandbox](https://developers.redhat.com/developer-sandbox) (ou outro cluster OpenShift)
- CLI [oc](https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/) instalada

## Variáveis de ambiente (`.env`)

Copie o template e preencha com seus dados:

```powershell
copy .env.example .env
```

| Variável | Descrição |
|----------|-----------|
| `DOCKER_HUB_USER` | Usuário do Docker Hub |
| `DOCKER_HUB_TOKEN` | Token de acesso (opcional; evita login interativo) |
| `DOCKER_IMAGE_NAME` | Nome da imagem (`openshift-welcome-api`) |
| `DOCKER_IMAGE_TAG` | Tag da imagem (`1.0`) |
| `REDHAT_USERNAME` | Usuário da conta Red Hat |
| `OPENSHIFT_SERVER` | URL da API do cluster (ex.: Sandbox) |
| `OPENSHIFT_TOKEN` | Token de login do `oc` |
| `OPENSHIFT_PROJECT` | Projeto OpenShift (no Sandbox use `seu-usuario-dev`, ex.: `cloud-open-dev`) |
| `OPENSHIFT_APP_NAME` | Nome base da aplicacao no cluster (`welcome-api`) |
| `DEPLOY_STRATEGY` | `clean` remove recursos antigos antes do deploy; `unique` gera nome/tag aleatorios |
| `APP_PORT` | Porta local da aplicação (`3000`) |
| `APP_ENVIRONMENT` | Valor retornado em `/status` (`OpenShift`) |
| `GITHUB_USER` / `GITHUB_REPO` | Opcional, para publicar no GitHub |

Os scripts em `scripts/` leem automaticamente o arquivo `.env`. O `.env` **não** vai para o Git.

## Deploy com um comando

Com o `.env` preenchido, Docker Desktop rodando e CLI `oc` instalada:

```powershell
.\scripts\deploy-all.ps1
```

Ou via npm:

```powershell
npm run deploy
```

Esse comando executa em sequência:

1. Build da imagem Docker e push para o Docker Hub
2. Deploy no OpenShift (Deployment, Service e Route)
3. Validação dos endpoints `/` e `/status` via Route externa

Para executar etapas isoladas (debug), use os scripts individuais listados abaixo.

### Estrategias de deploy (`DEPLOY_STRATEGY`)

| Valor | Docker | OpenShift |
|-------|--------|-----------|
| `clean` (padrao) | Reutiliza tag `1.0` | Remove deployment/service/route antigos e recria |
| `unique` | Tag aleatoria ex.: `1.0-a3k9m2` | App aleatorio ex.: `welcome-api-a3k9m2` |

No **Developer Sandbox** nao e possivel criar/excluir **projetos** inteiros; a limpeza remove apenas os **recursos da aplicacao** dentro do projeto `cloud-open-dev`.

Para remover manualmente o ultimo deploy:

```powershell
.\scripts\cleanup-openshift.ps1
```

## Etapa 1 — Desenvolvimento local

```powershell
cd openshift-welcome-api
npm install
npm start
```

Testar:

```powershell
curl http://localhost:3000/
curl http://localhost:3000/status
```

Modo desenvolvimento com reload automático:

```powershell
npm run dev
```

## Scripts auxiliares

| Script | Descrição |
|--------|-----------|
| `scripts/deploy-all.ps1` | **Comando unico:** build, push, deploy e validacao |
| `scripts/cleanup-openshift.ps1` | Remove deployment/service/route do ultimo deploy |
| `scripts/run-docker-local.ps1` | Build + run local do container |
| `scripts/publish-dockerhub.ps1` | Build, tag e push (usa `.env`) |
| `scripts/deploy-openshift.ps1` | Deploy completo (usa `.env`) |
| `scripts/validate-openshift.ps1` | Valida pods, logs e endpoints via Route |

## Etapa 2 — Containerização

Construir a imagem:

```powershell
docker build -t openshift-welcome-api:1.0 .
```

Executar localmente:

```powershell
docker run --rm -p 3000:3000 openshift-welcome-api:1.0
```

Ou use o script:

```powershell
.\scripts\run-docker-local.ps1
```

Validar:

```powershell
curl http://localhost:3000/status
```

## Etapa 3 — Publicação no Docker Hub

1. Crie uma conta em [hub.docker.com](https://hub.docker.com)
2. Crie um repositório público chamado `openshift-welcome-api`
3. Substitua `SEU_USUARIO` pelo seu usuário Docker Hub nos comandos abaixo

```powershell
docker login
docker tag openshift-welcome-api:1.0 SEU_USUARIO/openshift-welcome-api:1.0
docker push SEU_USUARIO/openshift-welcome-api:1.0
```

Ou use o script:

```powershell
.\scripts\publish-dockerhub.ps1 -DockerHubUser SEU_USUARIO
```

Confirme em: `https://hub.docker.com/r/SEU_USUARIO/openshift-welcome-api`

## Etapa 4 — Obter acesso ao OpenShift

### Red Hat Developer Sandbox (recomendado)

1. Acesse [developers.redhat.com/developer-sandbox](https://developers.redhat.com/developer-sandbox)
2. Crie uma conta Red Hat gratuita e ative o Sandbox
3. No console web, clique no seu usuário → **Copy login command**
4. Instale a CLI `oc` se ainda não tiver:

   - Windows: baixe em [mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/](https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/)

5. Execute o comando de login copiado:

```powershell
oc login --token=SEU_TOKEN --server=https://api.sandbox...
oc whoami
```

## Etapa 5 — Deploy no OpenShift

### 5.1 Atualizar imagem no manifest

Edite `openshift/deployment.yaml` e substitua `SEU_USUARIO` pelo seu usuário Docker Hub:

```yaml
image: docker.io/SEU_USUARIO/openshift-welcome-api:1.0
```

### 5.2 Criar projeto e aplicar recursos

```powershell
oc new-project welcome-api
oc apply -f openshift/deployment.yaml
oc apply -f openshift/service.yaml
oc apply -f openshift/route.yaml
```

Ou use o script (substitui a imagem e aplica os manifests):

```powershell
.\scripts\deploy-openshift.ps1 -DockerHubUser SEU_USUARIO
```

### 5.3 Obter URL externa

```powershell
oc get route welcome-api
oc get route welcome-api -o jsonpath='https://{.spec.host}{"\n"}'
```

## Etapa 6 — Testes e validação

```powershell
# Verificar pods
oc get pods
oc get pods -l app=welcome-api

# Ver logs
oc logs deployment/welcome-api
oc logs -f deployment/welcome-api

# Testar endpoints (substitua ROUTE_HOST)
curl https://ROUTE_HOST/
curl https://ROUTE_HOST/status
```

Ou use o script de validação:

```powershell
.\scripts\validate-openshift.ps1
```

### Checklist de sucesso

- [ ] Pod em estado `Running` (`1/1`)
- [ ] `GET /` retorna mensagem de boas-vindas
- [ ] `GET /status` retorna JSON com `"status": "online"`
- [ ] Logs mostram servidor iniciado na porta 3000
- [ ] Acesso externo funciona via Route

## Troubleshooting

### Docker push: `access token has insufficient scopes`

O token do Docker Hub no `.env` nao tem permissao de **escrita**.

1. Acesse [hub.docker.com/settings/security](https://hub.docker.com/settings/security)
2. Crie um **Access Token** com permissao **Read & Write**
3. Atualize `DOCKER_HUB_TOKEN` no `.env`
4. Rode novamente: `.\scripts\deploy-all.ps1`

Alternativa: deixe `DOCKER_HUB_TOKEN` vazio e use `docker login` interativo.

### Docker: `failed to connect to the docker API`

- Abra o **Docker Desktop** e aguarde o status "Running"
- Reinicie o terminal e teste: `docker info`
- Se persistir, reinicie o Docker Desktop

### OpenShift Sandbox: `You may not request a new project via this API`

No Developer Sandbox **nao e possivel criar projetos novos**. Use o projeto existente da sua conta:

```env
OPENSHIFT_PROJECT=cloud-open-dev
```

O valor e `{REDHAT_USERNAME}-dev`. O script `deploy-openshift.ps1` tenta isso automaticamente se o projeto configurado nao existir.

### Pod não inicia (ImagePullBackOff)

- Confirme que a imagem está pública no Docker Hub
- Verifique se o nome da imagem em `deployment.yaml` está correto

```powershell
oc describe pod -l app=welcome-api
oc get events --sort-by=.lastTimestamp
```

### Probe falhando

- Confirme que a aplicação escuta em `0.0.0.0` e usa `process.env.PORT`
- Verifique logs: `oc logs deployment/welcome-api`

### Route não responde

```powershell
oc get route welcome-api
oc get svc welcome-api
oc describe route welcome-api
```

## Estrutura do projeto

```
openshift-welcome-api/
├── src/
│   └── server.js
├── openshift/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── route.yaml
├── scripts/
│   ├── run-docker-local.ps1
│   ├── publish-dockerhub.ps1
│   ├── deploy-openshift.ps1
│   └── validate-openshift.ps1
├── .dockerignore
├── .gitignore
├── Dockerfile
├── package.json
└── README.md
```

## Publicar no GitHub

```powershell
git init
git add .
git commit -m "feat: API de boas-vindas containerizada para OpenShift"
git branch -M main
git remote add origin https://github.com/SEU_USUARIO/openshift-welcome-api.git
git push -u origin main
```

## Licença

MIT
