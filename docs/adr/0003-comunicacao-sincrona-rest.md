# ADR 0003 — Comunicação síncrona REST entre os componentes

**Status:** Aceito · **Data:** 2026-09-15

## Contexto

A arquitetura tem três componentes que trocam informação: o API Gateway, a
Lambda de autenticação e a aplicação Rails. Havia a opção de introduzir
mensageria (SQS/SNS/EventBridge) entre eles, especialmente para a notificação de
mudança de status, que hoje é um e-mail enviado pela aplicação.

## Decisão

Mantemos **comunicação síncrona sobre HTTP/REST** entre gateway, Lambda e
aplicação. A Lambda e o Rails não se falam diretamente: compartilham apenas o
banco e o segredo de assinatura do JWT.

O envio de e-mail continua assíncrono dentro da aplicação, via `deliver_later`
sobre Solid Queue.

## Consequências

**Positivas**

- Nenhum componente novo para provisionar, monitorar ou pagar
- O fluxo de autenticação é inerentemente síncrono: o cliente manda o CPF e
  espera o token. Uma fila no meio só adicionaria latência e complexidade
- Depuração direta: uma requisição, um trace, um `X-Request-Id`

**Negativas**

- Se o RDS ficar indisponível, a autenticação falha imediatamente (a Lambda
  devolve 503). Não há retry nem buffer
- Acoplamento temporal: Lambda e banco precisam estar no ar ao mesmo tempo

## Alternativas consideradas

**EventBridge entre a aplicação e as notificações** seria a evolução natural se
houvesse mais consumidores do evento "status da OS mudou" — hoje só existe um, o
e-mail. Introduzir o barramento agora seria arquitetura especulativa.

**SQS entre o gateway e a aplicação** não se aplica: as APIs de consulta e
abertura de OS precisam de resposta imediata com o identificador da ordem.
