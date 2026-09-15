# ADR 0004 — HPA escalando por CPU e memória

**Status:** Aceito · **Data:** 2026-09-15

## Contexto

O enunciado da Fase 2 exige HPA escalando conforme consumo de CPU/memória, e a
Fase 3 exige monitorar esse consumo. É preciso decidir quais métricas disparam o
escalonamento e com que limiares.

## Decisão

HPA com **duas métricas de recurso**: CPU a 70% de utilização e memória a 80%,
com `minReplicas: 2` e `maxReplicas: 5`.

A janela de estabilização de subida é **zero** (escala assim que o limiar é
cruzado) e a de descida é de **60 segundos**.

Requests e limits são obrigatórios para o HPA funcionar e estão definidos em
`k8s/base/deployment.yaml`: 250m/512Mi de request, 500m/1Gi de limit.

## Consequências

**Positivas**

- `minReplicas: 2` garante que uma queda de pod não derruba o serviço
- Janela de subida zero torna o scale-out visível em cerca de 40 segundos sob
  carga, o que é demonstrável em vídeo
- Duas métricas cobrem os dois gargalos reais de uma aplicação Rails: CPU nas
  requisições e memória por processo Puma

**Negativas**

- CPU e memória são métricas indiretas. Uma fila de requisições crescendo com
  CPU baixa (espera de I/O no banco) não dispara escalonamento
- Teto de 5 réplicas em 2 nós `t3.medium`: acima disso os pods ficariam
  `Pending` por falta de CPU alocável, já que não há cluster autoscaler

## Alternativas consideradas

**Métricas customizadas do Datadog** (requisições por segundo, latência p95) via
`clusterAgent.metricsProvider` descreveriam melhor a saturação real. Ficou
desabilitado: exige a API key configurada antes do cluster subir, o que inverte
a ordem de provisionamento, e o ganho não compensa para o volume desta fase.

**Cluster Autoscaler** para escalar os nós junto com os pods foi descartado por
custo — cada nó adicional é dinheiro, e o teto de 5 réplicas já demonstra o
comportamento exigido.
