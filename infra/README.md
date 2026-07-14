# Infraestrutura como Código (Terraform)

Provisiona toda a infraestrutura local necessária para rodar a aplicação em Kubernetes.

## Recursos criados

| Recurso | Tipo | Descrição |
|---|---|---|
| `kind_cluster.this` | Cluster kind | Cluster Kubernetes local (1 control-plane + 1 worker) com portas mapeadas para o host: API em `localhost:8080`, Mailpit em `localhost:8026` |
| `helm_release.metrics_server` | Helm release | metrics-server no `kube-system` (com `--kubelet-insecure-tls`, exigido no kind) — necessário para o HPA funcionar |
| `kubernetes_namespace.auto_repair` | Namespace | Namespace `auto-repair` onde a aplicação é implantada |
| `kubernetes_secret.db` | Secret | Senha do PostgreSQL (`db-secrets`) |
| `kubernetes_service.db` | Service | Service ClusterIP `db` apontando para o PostgreSQL |
| `kubernetes_stateful_set.postgres` | StatefulSet | PostgreSQL 16 com volume persistente de 1Gi |

## Pré-requisitos

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- [Docker](https://docs.docker.com/engine/install/) (o kind roda os nós como containers)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)

## Como aplicar

```bash
cd infra
terraform init
terraform plan
terraform apply
```

Ao final, o kubeconfig do cluster fica em `infra/auto-repair-config` (output `kubeconfig_path`).

```bash
export KUBECONFIG=$(terraform output -raw kubeconfig_path)
kubectl get nodes
```

Com o cluster de pé, aplique os manifestos da aplicação:

```bash
kubectl apply -f ../k8s/
```

## Variáveis

| Variável | Default | Descrição |
|---|---|---|
| `cluster_name` | `auto-repair` | Nome do cluster kind |
| `postgres_password` | `auto_repair_local_pg` | Senha do postgres (mantenha em sincronia com `k8s/secrets.yaml`) |
| `api_host_port` | `8080` | Porta do host para a API |
| `mailpit_host_port` | `8026` | Porta do host para a UI do Mailpit |

## Como destruir

```bash
terraform destroy
```
