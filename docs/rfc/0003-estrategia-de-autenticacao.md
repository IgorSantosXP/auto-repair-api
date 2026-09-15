# RFC 0003 — Estratégia de autenticação

**Autor:** Igor Santos · **Status:** Aprovado · **Data:** 2026-09-15

## Resumo

Propõe **dois emissores de JWT com públicos distintos**: a aplicação Rails emite
token de administrador por e-mail e senha; uma função Lambda emite token de
cliente por CPF. Ambos assinam com o mesmo segredo e são distinguidos pelo claim
`aud`.

## Motivação

Até a Fase 2, clientes não tinham autenticação: acompanhavam a OS por um UUID
não adivinhável e aprovavam orçamento por um token assinado enviado no e-mail.
A Fase 3 exige proteger rotas sensíveis com **autenticação via CPF**, feita por
uma função serverless que valida o CPF, consulta o cliente na base e devolve um
JWT.

## Proposta

### Dois públicos, um segredo

| | Token de administrador | Token de cliente |
|---|---|---|
| Emissor | Rails, `POST /api/v1/auth/login` | Lambda, `POST /auth/cpf` |
| Credencial | e-mail + senha (bcrypt) | CPF |
| `iss` | `auto-repair-api` | `auto-repair-auth` |
| `aud` | `admin` | `customer` |
| Validade | 24 horas | 1 hora |
| Alcance | Rotas administrativas | Somente as próprias OS |

Ambos usam HS256 com o segredo guardado no Secrets Manager. A aplicação valida
assinatura, `aud` **e** `iss` — um token de admin apresentado numa rota de
cliente é rejeitado com 401, e vice-versa. Sem a verificação de `aud`, os dois
tokens seriam intercambiáveis, e um cliente autenticado por CPF teria acesso
administrativo.

### Autorização por posse

Autenticar não basta. O `sub` do token de cliente carrega o id do cliente, e
toda rota de cliente confere se a OS consultada pertence a ele, devolvendo 403
caso contrário. Sem essa checagem, qualquer cliente autenticado leria a OS de
qualquer outro apenas trocando o UUID.

### Convivência com o fluxo da Fase 2

As rotas de aprovação e recusa continuam aceitando o token assinado que vai no
link do e-mail, além do token de CPF no header. O enunciado da Fase 2 exigia um
endpoint para "receber notificações externas de aprovação ou recusa", e os links
já enviados a clientes não podem quebrar.

## O problema desta abordagem

**CPF é identificador público, não credencial.** Está em nota fiscal, cadastro de
loja, vazamento de base. Qualquer pessoa que conheça o CPF de um cliente obtém um
token válido e lê o histórico de serviços e os valores pagos por ele.

Isto está sendo implementado porque o enunciado da fase o especifica
explicitamente. Não é uma decisão de segurança defensável para um sistema real.

### Mitigações adotadas

| Mitigação | Efeito |
|---|---|
| Expiração de 1 hora (contra 24h do admin) | Reduz a janela de uso de um token vazado |
| Escopo restrito ao próprio cliente | Um token comprometido expõe um cliente, não a base |
| Throttling no API Gateway (50 req/s, burst 100) | Dificulta enumeração de CPFs em massa |
| Resposta 404 distinta de 403 | Decisão consciente: facilita o suporte ao cliente, ao custo de confirmar se um CPF está na base. Num sistema real, as duas deveriam responder igual |
| Log estruturado de toda rejeição, com motivo | Permite alertar sobre padrão de tentativa |

### O que faria isso seguro

Um sistema real trataria o CPF como **identificador** e exigiria um segundo
fator como credencial: código enviado por SMS ou e-mail cadastrado (OTP), ou
senha definida pelo cliente no primeiro acesso. A Lambda continuaria sendo o
ponto de emissão; mudaria apenas o que ela valida antes de assinar.

## Alternativas consideradas

**Lambda Authorizer no API Gateway**, validando o token a cada requisição antes
de chegar no cluster, tiraria a validação da aplicação. Descartado: adiciona
latência e uma invocação por requisição, e o Rails já precisa decodificar o token
para saber qual cliente está autenticado.

**Amazon Cognito** seria a resposta correta para gestão de identidade, com MFA e
rotação de chaves prontos. Contraria o enunciado, que pede explicitamente uma
função serverless própria fazendo a validação e a emissão.

**RS256 com chave assimétrica** permitiria que a aplicação validasse sem
conhecer a chave privada. Descartado pelo prazo: HS256 com segredo compartilhado
via Secrets Manager é suficiente para o escopo, e a rotação já exige `apply` de
qualquer forma.

## Riscos

| Risco | Mitigação |
|---|---|
| Enumeração de CPFs | Throttling no gateway, log de rejeições |
| Segredo compartilhado entre Lambda e aplicação | Guardado no Secrets Manager, injetado em tempo de `apply`, nunca versionado |
| Girar o segredo invalida todos os tokens e exige novo `apply` | Aceito: tokens duram no máximo 24h |
