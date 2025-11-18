## Módulo `modules/vpc` — Rede base reutilizável

Este módulo cria a infraestrutura de rede básica necessária em AWS de forma padronizada e parametrizável. Ele oferece uma topologia pronta para produção ou testes: VPC, sub-redes públicas/privadas/de banco, IGW, NAT Gateways, tabelas de rota e Network ACLs para subnets de banco.

Resumo do que o módulo cria
- VPC com CIDR principal e associações de CIDRs adicionais (opcional)
- Internet Gateway (IGW)
- Sub-redes públicas (uma por item em `public_subnets`)
- EIPs e NAT Gateways (um por subnet pública)
- Sub-redes privadas (uma por item em `private_subnets`) e tabelas de rota apontando para NATs
- Sub-redes de banco de dados (opcional)
- Route tables e associações (públicas e privadas)
- Network ACL para as subnets de banco de dados com regras padrão (deny genérico + allow para MySQL e Redis a partir das private_subnets)

Entradas (variáveis principais)
- `project_name` (string): nome do projeto usado nas tags.
- `vpc_cidr` (string): CIDR principal da VPC (ex.: "10.0.0.0/16").
- `vpc_additional_cidrs` (list(string)): CIDRs adicionais a serem associados à VPC (opcional).
- `public_subnets` (list(object)): lista de sub-redes públicas. Cada item é um objeto com: `name`, `cidr`, `availability_zone`.
- `private_subnets` (list(object)): lista de sub-redes privadas. Cada item é um objeto com: `name`, `cidr`, `availability_zone`.
- `database_subnets` (list(object)): lista de sub-redes para bancos (opcional). Cada item: `name`, `cidr`, `availability_zone`.
- `tags` (map(string)): mapa opcional de tags adicionais aplicadas a todos os recursos.

Formato de exemplo para `public_subnets` / `private_subnets` / `database_subnets`:
```hcl
public_subnets = [
  { name = "gle-public-1a", cidr = "10.0.48.0/24", availability_zone = "us-east-1a" },
  { name = "gle-public-1b", cidr = "10.0.49.0/24", availability_zone = "us-east-1b" },
  { name = "gle-public-1c", cidr = "10.0.50.0/24", availability_zone = "us-east-1c" },
]
```

Saídas (outputs)
- `vpc_id`: ID da VPC criada.
- `public_subnet_ids`: lista de IDs das subnets públicas.
- `private_subnet_ids`: lista de IDs das subnets privadas.
- `database_subnet_ids`: lista de IDs das subnets de banco (se fornecidas).
- `network_acl_id`: ID do Network ACL criado para as subnets de banco (se aplicável).

Como usar (exemplo no root)
```hcl
module "vpc" {
  source = "./modules/vpc"

  project_name         = var.project_name
  vpc_cidr             = var.vpc_cidr
  vpc_additional_cidrs = var.vpc_additional_cidrs

  public_subnets   = var.public_subnets
  private_subnets  = var.private_subnets
  database_subnets = var.database_subnets
}
```

Passo-a-passo para executar (terminal zsh)
1. Inicializar:
```bash
terraform init
```
2. Validar configuração:
```bash
terraform validate
```
3. Gerar plano (ex.: usando um arquivo de variáveis):
```bash
terraform plan -var-file=environment/prod/terraform.tfvars -out=tfplan
```
4. Aplicar o plano:
```bash
terraform apply "tfplan"
```
5. Destruir quando necessário:
```bash
terraform destroy -var-file=environment/prod/terraform.tfvars
```

Verificações pós-criação (checks rápidos)
- Verificar a VPC no Console AWS ou com AWS CLI: `aws ec2 describe-vpcs --filters Name=tag:Name,Values="<project-name>" --region <region>`
- Confirmar NATs/EIPs estão criados e associados.
- Confirmar rotas públicas (0.0.0.0/0 → IGW) e rotas privadas (0.0.0.0/0 → NAT).
- Confirmar Network ACL aplicado às subnets de banco e regras para 3306/6379.

Permissões (IAM) necessárias
- Permissões para criar/ler/atualizar/deletar: VPCs, subnets, internet-gateway, route-tables, nat gateways, eips, network-acl, network-acl-rules, route associations. Preferir princípio do menor privilégio.

Boas práticas e observações
- Teste em ambiente de staging antes de aplicar em produção.
- Garanta que as `public_subnets` e `private_subnets` listadas tenham AZs correspondentes para que o mapeamento NAT por AZ funcione corretamente.
- Ajuste as regras do Network ACL caso sua arquitetura precise de portas ou protocolos adicionais.
- Considere criar submódulos (subnet/nat/acl) se for reutilizar partes isoladas do módulo em outros projetos.
- Adicione `validation` blocks nas variáveis para proteger formatos (ex.: validar CIDR) se desejar.

Exemplo de `terraform.tfvars` mínimo para testes
```hcl
project_name = "gle-vpc"
vpc_cidr = "10.0.0.0/16"
vpc_additional_cidrs = ["100.64.0.0/16"]

public_subnets = [
  { name = "gle-public-1a", cidr = "10.0.48.0/24", availability_zone = "us-east-1a" },
  { name = "gle-public-1b", cidr = "10.0.49.0/24", availability_zone = "us-east-1b" },
  { name = "gle-public-1c", cidr = "10.0.50.0/24", availability_zone = "us-east-1c" },
]

private_subnets = [
  { name = "gle-private-1a", cidr = "10.0.0.0/20", availability_zone = "us-east-1a" },
  { name = "gle-private-1b", cidr = "10.0.16.0/20", availability_zone = "us-east-1b" },
  { name = "gle-private-1c", cidr = "10.0.32.0/20", availability_zone = "us-east-1c" },
]

database_subnets = [
  { name = "gle-database-1a", cidr = "10.0.51.0/24", availability_zone = "us-east-1a" },
  { name = "gle-database-1b", cidr = "10.0.52.0/24", availability_zone = "us-east-1b" },
  { name = "gle-database-1c", cidr = "10.0.53.0/24", availability_zone = "us-east-1c" },
]
```

Resumo em 3 linhas
1. Módulo `modules/vpc` cria VPC, subnets públicas/privadas/de-banco, IGW, NAT (com EIPs), route tables e Network ACLs.
2. É parametrizável por listas de subnets e CIDRs; retorna IDs úteis (vpc_id, subnet_ids, network_acl_id).
3. Executar: terraform init → plan (com tfvars) → apply; testar em staging antes de produção.

----

Se quiser, posso:
- adicionar `validation` blocks nas variáveis do módulo,
- quebrar o módulo em submódulos (subnet/nat/acl) para maior reutilização,
- ou criar um exemplo em `examples/` com um `terraform.tfvars` pronto.
