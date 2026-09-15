# Diagrama de sequência — autenticação por CPF

Fluxo completo desde o CPF até o consumo de uma rota protegida.

```mermaid
sequenceDiagram
    autonumber
    actor C as Cliente
    participant G as API Gateway
    participant L as Lambda auth
    participant SM as Secrets Manager
    participant D as RDS PostgreSQL
    participant A as API Rails (EKS)

    Note over SM,L: O segredo JWT é injetado como variável<br/>de ambiente em terraform apply,<br/>não lido a cada invocação

    C->>G: POST /auth/cpf<br/>{ "cpf": "111.444.777-35" }
    G->>G: gera $context.requestId<br/>aplica throttling
    G->>L: invoke (payload v2.0)

    L->>L: normaliza para dígitos<br/>valida dígitos verificadores

    alt CPF malformado
        L-->>G: 400 invalid_cpf
        G-->>C: 400 { error: { code, message } }
    else CPF bem formado
        L->>D: SELECT id, name, deleted_at FROM customers<br/>WHERE document = $1 AND kind = 'individual'
        D-->>L: linha ou vazio

        alt nenhum cliente
            L-->>G: 404 customer_not_found
            G-->>C: 404
        else cliente com deleted_at
            L-->>G: 403 customer_inactive
            G-->>C: 403
        else cliente ativo
            L->>L: assina HS256<br/>sub, aud=customer,<br/>iss=auto-repair-auth, exp=1h
            L-->>G: 200 { token, expires_in, customer }
            G-->>C: 200 + x-request-id
        end
    end

    Note over C,A: Token em mãos, o cliente consome as rotas protegidas

    C->>G: GET /api/v1/customer/service_orders/{uuid}<br/>Authorization: Bearer ...
    G->>A: via VPC Link → NLB → NodePort<br/>X-Request-Id: $context.requestId

    A->>A: decodifica e verifica<br/>assinatura, aud e iss

    alt aud diferente de "customer"
        A-->>C: 401 unauthorized
    else token válido
        A->>D: SELECT ... FROM service_orders WHERE uuid = $1
        D-->>A: ordem de serviço

        alt ordem pertence a outro cliente
            A-->>C: 403 forbidden
        else ordem do próprio cliente
            A-->>G: 200 { uuid, status, itens, histórico }
            G-->>C: 200
        end
    end
```

## Pontos de atenção

**Por que `aud` importa.** Sem verificar o público, o token emitido pela Lambda
abriria também as rotas administrativas, e um cliente autenticado por CPF teria
acesso ao CRUD inteiro. A aplicação valida `aud` e `iss` em toda decodificação.

**Por que a checagem de posse existe.** Autenticar prova quem é o cliente, não a
que ordem ele tem direito. Sem o 403, bastaria trocar o UUID na URL para ler a OS
de outra pessoa.

**Correlação.** O `requestId` gerado pelo gateway aparece no log de acesso do
próprio gateway, no log estruturado da Lambda e — via header `X-Request-Id` — em
cada linha de log do Rails, junto do `dd.trace_id`. É o que permite seguir uma
requisição de ponta a ponta no Datadog.

**A limitação de segurança** desta estratégia está documentada no
[RFC 0003](../rfc/0003-estrategia-de-autenticacao.md): CPF é identificador
público, não credencial.
