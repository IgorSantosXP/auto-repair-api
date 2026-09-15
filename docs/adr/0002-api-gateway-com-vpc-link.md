# ADR 0002 — API Gateway HTTP com VPC Link e alvos por instância

**Status:** Aceito · **Data:** 2026-09-15

## Contexto

O enunciado exige um API Gateway controlando e roteando o tráfego. Ele precisa
atender dois destinos muito diferentes: uma função Lambda (autenticação por CPF)
e a aplicação Rails rodando em pods no EKS.

Expor o cluster diretamente à internet e colocar o gateway "ao lado" anularia o
propósito do gateway. O tráfego para o cluster precisa passar por ele.

## Decisão

Usamos **API Gateway HTTP API** (não REST API) com duas integrações:

- `POST /auth/cpf` → integração `AWS_PROXY` direta com a Lambda
- `ANY /api/{proxy+}` → integração `HTTP_PROXY` via **VPC Link** para um **NLB
  interno**, que entrega no **NodePort 30080** dos nós do cluster

O NLB e o target group são criados pelo Terraform, com alvos do tipo
`instance` registrados por `aws_autoscaling_attachment` no ASG do node group.

## Consequências

**Positivas**

- Todo o tráfego externo entra por um único ponto, onde ficam o throttling
  (50 req/s, burst 100) e o log de acesso estruturado
- O cluster não tem exposição direta à internet
- HTTP API custa cerca de 70% menos que REST API e tem 1M de chamadas grátis
  nos 12 primeiros meses
- O gateway injeta `X-Request-Id: $context.requestId` na requisição, o que dá
  correlação ponta a ponta entre o log do gateway, o da Lambda e o do Rails

**Negativas**

- Alvos por instância significam que o NLB entrega no nó, e o `kube-proxy`
  reencaminha para o pod. Há um salto extra de rede e o IP de origem real se
  perde
- HTTP API não tem request validation nem transformações de payload como a REST
  API. Não é um problema aqui: a validação é responsabilidade da aplicação

## Alternativas consideradas

**Service `type=LoadBalancer`** criaria o NLB pelo Kubernetes, com alvos direto
nos pods (melhor caminho de rede). Foi descartado por dependência circular: o
API Gateway precisa do ARN do listener no `terraform apply`, mas o NLB só passa
a existir depois que o cluster está no ar e o Service é aplicado. Resolver isso
exigiria dois `apply` encadeados ou o AWS Load Balancer Controller com IRSA —
complexidade que não se paga no prazo desta fase.

**ALB no lugar do NLB** daria roteamento por path e health checks mais ricos,
mas custa mais e o roteamento por path já é feito pelo próprio gateway.
