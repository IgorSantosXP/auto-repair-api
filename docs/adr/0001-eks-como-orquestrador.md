# ADR 0001 — EKS como orquestrador de contêineres

**Status:** Aceito · **Data:** 2026-09-15

## Contexto

A Fase 2 rodava em um cluster `kind` local, provisionado por Terraform na
própria máquina do desenvolvedor. A Fase 3 exige um cluster Kubernetes com
escalabilidade rodando em nuvem, com deploy automático a partir do CI.

Três caminhos foram avaliados:

1. **EKS** — control plane gerenciado pela AWS
2. **k3s em EC2** — distribuição leve, control plane operado por nós
3. **ECS/Fargate** — orquestração proprietária da AWS

## Decisão

Adotamos **EKS**, com um managed node group de duas instâncias `t3.medium` nas
subnets públicas e o add-on `metrics-server` habilitado para alimentar o HPA.

## Consequências

**Positivas**

- Control plane replicado em três zonas, com patch e backup de etcd pela AWS
- Integração nativa com IAM (access entries), ECR e ELB
- Os manifestos da Fase 2 foram reaproveitados quase sem alteração
- É o que a indústria usa; o enunciado pede "nível de operação corporativa"

**Negativas**

- **US$ 0,10/hora de control plane, sem free tier.** Rodando 24/7, o conjunto
  (EKS + nós + NLB + RDS) custa cerca de US$ 136/mês. Mitigação adotada: a
  infraestrutura é provisionada para testes e para a gravação do vídeo e
  destruída em seguida, com `make down` documentado em cada repositório e um
  AWS Budget alertando em US$ 10
- `terraform apply` leva de 15 a 20 minutos, e `destroy` de 10 a 15. Isso
  inviabiliza mostrar o provisionamento ao vivo em um vídeo de 15 minutos — a
  infra precisa estar de pé antes da gravação

## Alternativas consideradas

**k3s em EC2** reduziria o custo mensal de US$ 136 para cerca de US$ 30 e
provisiona em 2-3 minutos, o que caberia no vídeo. É Kubernetes certificado pela
CNCF: mesma API, mesmos manifestos, HPA idêntico. Foi descartado pelo risco de
avaliação — o enunciado não exige cluster gerenciado explicitamente, mas
espera-se uma solução corporativa, e operar o control plane numa instância única
é exatamente o oposto disso.

**ECS/Fargate** foi descartado de imediato: o enunciado exige Kubernetes.
