# Runbook operacional e política de acessos

Este documento consolida o estado operacional da demonstração **HeatWave Fraud
Copilot** após a implantação na VM. Ele descreve contas, responsabilidades,
privilégios, modelo, inicialização e validações, sem expor segredos.

> Regra obrigatória: senhas, chaves privadas, endpoints privados, tokens e
> valores reais de variáveis de ambiente nunca devem ser registrados neste
> documento, no Git, em prints ou no código-fonte.

## 1. Arquitetura operacional

```text
Navegador
  -> porta pública 3500
  -> Nginx
  -> Node.js (127.0.0.1:8787)
  -> MySQL HeatWave por rede privada
```

| Componente | Estado operacional |
| --- | --- |
| Serviço web | `febraban-fraud-copilot.service` |
| Proxy reverso | Nginx |
| Usuário do processo Linux | `opc` |
| Usuário MySQL da aplicação | `febraban` |
| Usuário MySQL administrativo | `admin` |
| Schema da aplicação | `fraud_demo` e `fraud_ml` |
| Camada pública de leitura | `fraud_demo_public` |
| Catálogo de modelo da aplicação | `ML_SCHEMA_febraban` |

## 2. Onde os segredos ficam

| Finalidade | Local permitido | Observação |
| --- | --- | --- |
| Credencial administrativa do MySQL | `/etc/febraban-mysql-admin.env` na VM | Arquivo protegido; usado apenas em manutenção controlada. |
| Credencial do usuário da aplicação | `/etc/febraban-fraud-copilot.env` na VM | Arquivo protegido e lido pelo systemd. |
| Chave SSH | Arquivo privado fora do repositório | Nunca copiar para a VM, código ou documentação. |

As configurações operacionais registram somente nomes de variáveis, por
exemplo `MYSQL_ADMIN_USER`, `MYSQL_ADMIN_PASSWORD`, `MYSQL_USER` e
`MYSQL_PASSWORD`. O usuário administrador é `admin`; a senha correspondente
fica exclusivamente no arquivo protegido da VM e deve ser rotacionada quando
necessário.

## 3. Princípio de acesso aplicado

- `admin`: tarefas administrativas controladas — grants, manutenção do modelo,
  carga e diagnóstico do DB System.
- `febraban`: usuário de serviço da aplicação. Possui acesso aos schemas da
  demo, às rotinas ML/GenAI requeridas e ao catálogo do seu modelo importado.
- O navegador nunca recebe credenciais do banco.
- O serviço Node não usa a credencial `admin`.

## 4. Roles e privilégios do HeatWave

O usuário `febraban` recebeu as roles abaixo. Elas foram definidas para ficarem
ativas em novas conexões; a validação retornou
`CURRENT_ROLE() = administrator`.

| Role | Uso |
| --- | --- |
| `administrator` | Role administrativa disponível neste DB System e definida como padrão para `febraban`. |
| `mysql_task_user` | Criação e execução de tarefas assíncronas, incluindo fluxos de vector store. |
| `mysql_task_admin` | Administração de tarefas assíncronas. |

Além das roles, foram aplicadas as permissões funcionais previstas na
documentação do MySQL HeatWave:

| Área | Permissões concedidas ao `febraban` |
| --- | --- |
| Dados da demo | Todos os privilégios em `fraud_demo.*` e `fraud_ml.*`. |
| Camada pública | `SELECT, SHOW VIEW` em `fraud_demo_public.*`. |
| Catálogo de modelos | Leitura/escrita/DDL e `GRANT OPTION` em `ML_SCHEMA_admin.*` e `ML_SCHEMA_febraban.*`. |
| Rotinas ML | `SELECT, EXECUTE` em `sys.*`, incluindo treinamento, carga e predição. |
| Observabilidade | Leitura das tabelas `performance_schema.rpd_*` necessárias para HeatWave e AutoML. |
| Vetorização | `VECTOR_STORE_LOAD_EXEC`, metadados de vector store e execução dos procedimentos de carga vetorial. |

O DB System gerenciado recusou a tentativa de conceder `ALL PRIVILEGES ON *.*
WITH GRANT OPTION`. Isso é uma restrição da plataforma. A role
`administrator`, os grants por schema e as permissões especializadas acima são
o conjunto efetivo disponível e necessário para este laboratório.

## 5. Modelo de risco em produção na demo

O modelo final foi originalmente treinado por `admin`. Para evitar falhas de
acesso interno ao catálogo durante `ML_PREDICT_TABLE`, foi usado o fluxo oficial
de compartilhamento:

1. `admin` exporta o modelo com `ML_MODEL_EXPORT`.
2. `febraban` importa uma cópia com `ML_MODEL_IMPORT`.
3. A cópia passa a residir no catálogo `ML_SCHEMA_febraban`.
4. O modelo é carregado no HeatWave pelo próprio usuário `febraban`.
5. A aplicação recebe o handle apenas por `HEATWAVE_MODEL_HANDLE` no arquivo
   protegido da VM.

Validação realizada: `ML_PREDICT_TABLE` executado como `febraban` classificou
10 linhas com sucesso em aproximadamente 1,16 segundo.

## 6. Vetorização, RAG e treinamento futuro

Com as roles e grants atuais, o usuário `febraban` está habilitado para:

- criar e carregar um Vector Store;
- executar `ML_EMBED_TABLE`, `ML_RAG_TABLE` e rotinas GenAI compatíveis;
- treinar novos modelos com `ML_TRAIN` no seu próprio catálogo;
- carregar e executar predições em modelos próprios;
- acompanhar tarefas e estatísticas do HeatWave.

Antes de qualquer novo treinamento ou carga vetorial em demonstração, conferir
a capacidade do cluster e evitar rodar cargas pesadas simultaneamente com a
simulação ao vivo.

## 7. Persistência após reboot

Os serviços estão habilitados para iniciar automaticamente:

```bash
sudo systemctl enable febraban-fraud-copilot nginx
```

Características da unidade da aplicação:

- `WantedBy=multi-user.target`;
- aguarda `network-online.target`;
- `Restart=on-failure`;
- retentativa após 5 segundos.

Validação feita após reboot completo da VM e reinício controlado dos serviços:

- aplicação `active`;
- Nginx `active`;
- `/api/health` retornando `database: ok`;
- proxy público retornando HTTP `200`.

## 8. Checklist antes de uma demonstração

```bash
sudo systemctl is-active febraban-fraud-copilot
sudo systemctl is-active nginx
curl -fsS http://127.0.0.1:8787/api/health
curl -sS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:3500/
```

Esperado: dois serviços `active`, health com `database: ok` e proxy HTTP `200`.

No banco, validar que as tabelas da demo estão carregadas no cluster analítico
e que o modelo da aplicação está carregado antes de iniciar a simulação.

## 9. Recuperação e rotação

### Rotação do usuário da aplicação

1. Alterar a senha de `febraban` por uma conexão administrativa segura.
2. Atualizar somente `MYSQL_PASSWORD` no arquivo protegido da VM.
3. Reiniciar o serviço da aplicação.
4. Executar o checklist da seção 8.

### Após reinício do cluster HeatWave

Modelos carregados são descarregados quando o cluster reinicia. Carregar a
cópia pertencente ao `febraban` antes da demo e confirmar uma predição de
smoke test. Se o handle mudar depois de novo compartilhamento/importação,
atualizar `HEATWAVE_MODEL_HANDLE` no arquivo protegido e reiniciar o serviço.

## 10. Referências oficiais

- [Privilégios do MySQL HeatWave AutoML](https://dev.mysql.com/doc/heatwave/en/hw-automl-privileges.html)
- [Compartilhar modelos entre usuários](https://dev.mysql.com/doc/heatwave/en/mys-hwaml-model-sharing.html)
- [Roles e privilégios GenAI / Vector Store](https://dev.mysql.com/doc/heatwave/en/mys-hw-genai-privileges.html)
- [Roles padrão do MySQL](https://dev.mysql.com/doc/refman/8.0/en/create-user.html)
