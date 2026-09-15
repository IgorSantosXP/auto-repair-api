# Diagrama de componentes

Visão de nuvem da solução: APIs, banco, monitoramento e o que provisiona cada
parte.

```mermaid
flowchart TB
    Cliente([Cliente])
    Admin([Atendente da oficina])

    subgraph AWS["AWS · us-east-1"]
        AGW["API Gateway HTTP API<br/>throttling 50 req/s<br/>injeta X-Request-Id"]

        subgraph VPC["VPC 10.0.0.0/16 · 2 AZs"]
            subgraph PUB["Subnets públicas"]
                NODES["EKS node group<br/>2x t3.medium"]
            end

            subgraph PRIV["Subnets privadas · sem NAT"]
                NLB["NLB interno"]
                LMB["Lambda auth<br/>Node.js 22"]
                RDS[("RDS PostgreSQL 16<br/>db.t3.micro<br/>auto_repair_prod<br/>auto_repair_homolog")]
            end
        end

        ECR[("ECR<br/>auto-repair-api")]
        SM["Secrets Manager<br/>auto-repair/app"]
        CW["CloudWatch Logs"]
    end

    subgraph EKS["Cluster EKS"]
        direction TB
        POD["Deployment api<br/>Rails 8.1"]
        HPA["HPA<br/>CPU 70% · mem 80%<br/>2 a 5 réplicas"]
        SVC["Service NodePort 30080"]
        JOB["Job db-migrate"]
        MP["Mailpit<br/>SMTP de demonstração"]
        DDA["Datadog Agent<br/>DaemonSet"]
    end

    DD([Datadog SaaS<br/>APM · Logs · Infra])

    Cliente -->|"POST /auth/cpf"| AGW
    Cliente -->|"Bearer token de cliente"| AGW
    Admin   -->|"Bearer token de admin"| AGW

    AGW -->|AWS_PROXY| LMB
    AGW -->|VPC Link| NLB
    NLB --> NODES
    NODES --- EKS

    LMB --> RDS
    POD --> RDS
    JOB --> RDS
    POD --> MP

    SVC --> POD
    HPA -.escala.-> POD
    ECR -.imagem.-> POD
    SM  -.credenciais em apply.-> LMB
    SM  -.Secret do K8s.-> POD

    LMB -.logs.-> CW
    AGW -.access logs.-> CW
    POD -.traces, métricas, logs JSON.-> DDA
    DDA --> DD
    CW -.integração.-> DD

```

## Provisionamento por repositório

| Repositório | Cria |
|---|---|
| `auto-repair-infra-k8s` | VPC, subnets, EKS, node group, ECR, NLB, API Gateway, VPC Link, role OIDC, Datadog Agent |
| `auto-repair-infra-database` | RDS, subnet group, security group, Secrets Manager |
| `auto-repair-auth-lambda` | Lambda, role, security group, rota `POST /auth/cpf` |
| `auto-repair-api` | Imagem no ECR, namespaces, Deployment, Service, HPA, Job de migração, Mailpit |

## Fluxo de deploy

```mermaid
flowchart LR
    DEV[Desenvolvedor] -->|"pull request"| PR{CI}
    PR -->|"brakeman, bundler-audit,<br/>rspec, kustomize build"| OK{Verde?}
    OK -->|não| DEV
    OK -->|sim| MERGE[Merge autorizado<br/>main protegida]

    MERGE -->|"push em homolog"| H[Deploy<br/>namespace auto-repair-homolog]
    MERGE -->|"push em main"| P[Deploy<br/>namespace auto-repair-prod]

    H --> STEPS
    P --> STEPS

    subgraph STEPS["Job de deploy"]
        direction TB
        S1["assume role via OIDC"] --> S2["build e push no ECR"]
        S2 --> S3["kubeconfig do EKS"]
        S3 --> S4["Secret a partir do<br/>Secrets Manager"]
        S4 --> S5["kubectl apply -k"]
        S5 --> S6["aguarda db-migrate<br/>e rollout"]
        S6 --> S7["smoke test no<br/>API Gateway"]
    end
```

Nenhum dos quatro pipelines guarda credencial AWS de longa duração: todos
assumem a role `auto-repair-github-actions` por **OIDC**, com token de curta
duração emitido pelo próprio GitHub.
