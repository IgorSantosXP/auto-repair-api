# Documentação arquitetural — Tech Challenge Fase 3

Sistema de gestão de oficina mecânica. Este índice reúne toda a documentação
exigida pela fase; é o link único a ser informado na entrega do portal.

## Arquitetura

| Documento | Conteúdo |
|---|---|
| [Diagrama de componentes](architecture/component-diagram.md) | Visão de nuvem: APIs, banco, monitoramento, o que cada repositório provisiona e o fluxo de deploy |
| [Sequência — autenticação por CPF](architecture/sequence-auth-cpf.md) | Do CPF ao token, e do token ao consumo de rota protegida |
| [Sequência — ordem de serviço](architecture/sequence-service-order.md) | Abertura, orçamento, aprovação, débito de estoque e entrega, mais a máquina de estados |

## Decisões arquiteturais (ADRs)

Decisões permanentes, com contexto, consequências e alternativas descartadas.

| ADR | Decisão |
|---|---|
| [0001](adr/0001-eks-como-orquestrador.md) | EKS como orquestrador de contêineres |
| [0002](adr/0002-api-gateway-com-vpc-link.md) | API Gateway HTTP com VPC Link e alvos por instância |
| [0003](adr/0003-comunicacao-sincrona-rest.md) | Comunicação síncrona REST entre os componentes |
| [0004](adr/0004-hpa-por-cpu-e-memoria.md) | HPA escalando por CPU e memória |
| [0005](adr/0005-separacao-em-quatro-repositorios.md) | Quatro repositórios com estado remoto compartilhado |

## Propostas técnicas (RFCs)

Decisões que envolveram comparação entre opções, com riscos e questões em aberto.

| RFC | Assunto |
|---|---|
| [0001](rfc/0001-escolha-da-nuvem.md) | Escolha do provedor de nuvem |
| [0002](rfc/0002-escolha-do-banco-de-dados.md) | Escolha e modelagem do banco de dados |
| [0003](rfc/0003-estrategia-de-autenticacao.md) | Estratégia de autenticação |

## Banco de dados

| Documento | Conteúdo |
|---|---|
| [Diagrama ER e relacionamentos](database/er-diagram.md) | Modelo completo e explicação de cada relacionamento |
| [RFC 0002](rfc/0002-escolha-do-banco-de-dados.md) | Justificativa formal da escolha e ajustes feitos no modelo relacional |

## Repositórios

| Repositório | Responsabilidade |
|---|---|
| [auto-repair-api](https://github.com/IgorSantosXP/auto-repair-api) | Aplicação Rails, manifestos Kubernetes e esta documentação |
| [auto-repair-infra-k8s](https://github.com/IgorSantosXP/auto-repair-infra-k8s) | VPC, EKS, ECR, NLB, API Gateway, OIDC |
| [auto-repair-infra-database](https://github.com/IgorSantosXP/auto-repair-infra-database) | RDS PostgreSQL e Secrets Manager |
| [auto-repair-auth-lambda](https://github.com/IgorSantosXP/auto-repair-auth-lambda) | Função serverless de autenticação por CPF |

A ordem de aplicação da infraestrutura é obrigatória e está documentada no
[ADR 0005](adr/0005-separacao-em-quatro-repositorios.md).

## API

A especificação OpenAPI é gerada a partir dos testes (rswag) e servida pela
própria aplicação em `/api-docs`. O arquivo versionado está em
[`swagger/v1/swagger.yaml`](../swagger/v1/swagger.yaml).
