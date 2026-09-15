# ADR 0005 — Separação em quatro repositórios com estado remoto compartilhado

**Status:** Aceito · **Data:** 2026-09-15

## Contexto

O enunciado exige quatro repositórios separados — Lambda, infraestrutura
Kubernetes, infraestrutura de banco e aplicação — cada um com CI/CD próprio,
`main` protegida e deploy automático.

Isso cria um problema real: os quatro provisionam recursos da mesma VPC e
precisam conhecer identificadores uns dos outros (subnets, security groups, ARN
do listener, endpoint do banco).

## Decisão

Cada repositório tem seu próprio estado Terraform em um **bucket S3
compartilhado**, sob chaves distintas, e lê o que precisa dos outros via
`terraform_remote_state`.

A ordem de aplicação é fixa e documentada em todos os READMEs:

```
bootstrap (manual, uma vez)
   └─► auto-repair-infra-k8s       (dono da VPC)
          └─► auto-repair-infra-database
                 └─► auto-repair-auth-lambda
                        └─► auto-repair-api
```

O lock usa o mecanismo nativo do S3 (`use_lockfile = true`, Terraform 1.10+),
dispensando a tabela DynamoDB do padrão antigo.

## Consequências

**Positivas**

- Cada repositório tem ciclo de vida próprio: mexer na Lambda não replaneja o
  cluster
- Blast radius menor — um `destroy` acidental atinge uma camada, não tudo
- Atende ao requisito do enunciado

**Negativas**

- **A ordem de aplicação é obrigatória e não é verificada por nada.** Aplicar o
  repositório do banco antes do de Kubernetes falha com um erro de output
  inexistente, que não é autoexplicativo
- O bucket de estado precisa existir antes de qualquer `init`, e não pode ser
  criado por Terraform (não pode guardar o próprio estado). É um passo manual,
  documentado em `auto-repair-infra-k8s/bootstrap/README.md`
- Uma mudança de rede exige `apply` em cascata em três repositórios

## Alternativas consideradas

**Monorepo com workspaces** eliminaria o acoplamento por estado remoto e
garantiria a ordem pelo grafo de dependências do próprio Terraform. Contraria o
requisito explícito de quatro repositórios.

**Terragrunt** resolveria a orquestração entre repositórios com dependências
declaradas, mas adiciona uma ferramenta a mais para a banca avaliar e para
justificar.
