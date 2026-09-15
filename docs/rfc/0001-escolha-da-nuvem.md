# RFC 0001 — Escolha do provedor de nuvem

**Autor:** Igor Santos · **Status:** Aprovado · **Data:** 2026-09-15

## Resumo

Propõe a **AWS** como provedor para toda a infraestrutura da Fase 3: API
Gateway, Lambda, banco gerenciado, cluster Kubernetes e provisionamento por
Terraform.

## Motivação

O enunciado deixa a escolha livre, mas fixa os componentes: API Gateway, função
serverless, banco gerenciado, cluster Kubernetes e IaC. A escolha precisa
atender aos cinco com serviços de primeira classe, ter provider Terraform
maduro e permitir provisionar e destruir o ambiente repetidamente sem
burocracia.

## Proposta

| Componente exigido | Serviço AWS |
|---|---|
| API Gateway | API Gateway HTTP API |
| Function Serverless | Lambda (Node.js 22) |
| Banco gerenciado | RDS PostgreSQL 16 |
| Cluster Kubernetes | EKS |
| IaC | Terraform, provider `hashicorp/aws` |
| Registro de imagens | ECR |
| Segredos | Secrets Manager |

Região **us-east-1**, por ser a mais barata e a primeira a receber todos os
serviços.

## Alternativas consideradas

**Google Cloud** tem, discutivelmente, o melhor Kubernetes gerenciado — o GKE
Autopilot tem control plane gratuito no tier free, o que eliminaria o maior
custo desta fase. Foi descartado por dois motivos: o autor tem experiência
prática com AWS e não com GCP, e o prazo da entrega não comporta aprender um
provedor novo enquanto se depura VPC e IAM.

**Azure** atende aos requisitos (API Management, Functions, AKS, Database for
PostgreSQL), mas o API Management tem um tempo de provisionamento na casa de
dezenas de minutos no tier Developer, o que tornaria o ciclo de teste
inviável.

**Oracle Cloud** tem o tier gratuito mais generoso do mercado, incluindo
Kubernetes gerenciado sem custo de control plane. Descartado pela maturidade
menor do provider Terraform e pela escassez de material de referência, o que
aumenta o risco de travar num problema sem resposta pronta.

## Riscos

| Risco | Mitigação |
|---|---|
| Custo do EKS sem free tier (~US$ 136/mês rodando 24/7) | Provisionar sob demanda e destruir após a gravação; AWS Budget alertando em US$ 10 |
| Conta pessoal com cartão do autor | Usuário IAM dedicado, perfil separado do SSO corporativo, orçamento monitorado |
| Lock-in em serviços proprietários | Limitado: a aplicação é um contêiner Docker padrão em Kubernetes, portável. Só gateway e Lambda são específicos |

## Questões em aberto

Se o projeto continuasse além da disciplina, valeria reavaliar GKE Autopilot
pelo control plane gratuito, ou consolidar tudo em ECS/Fargate e abrir mão de
Kubernetes — mas isso contrariaria o requisito da fase.
