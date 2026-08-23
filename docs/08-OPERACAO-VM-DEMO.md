# Operação da VM da demonstração

Este guia registra a configuração operacional da aplicação de demonstração
HeatWave Fraud Copilot. Ele não contém senha, chave privada, IP privado ou
outro segredo.

## Arquitetura aplicada

```text
Navegador -> porta pública 3500 -> Nginx -> Node.js (127.0.0.1:8787)
                                            |
                                            +-> MySQL HeatWave por rede privada
```

- Aplicação: `/opt/febraban-fraud-copilot`
- Serviço: `febraban-fraud-copilot.service`
- Proxy reverso: Nginx na porta pública `3500`
- Processo Node.js: porta local `8787`
- Usuário de banco da aplicação: `febraban`
- Banco administrativo: usado apenas para tarefas administrativas; nunca é
  configurado no processo web.

## Credenciais da aplicação

A aplicação lê suas variáveis somente de:

```text
/etc/febraban-fraud-copilot.env
```

O arquivo deve pertencer a `root`, ter grupo do processo da aplicação e modo
`640`. A senha do usuário `febraban` foi rotacionada em 17/08/2026 e a nova
senha foi gerada diretamente na VM. Não copiar essa senha para código, Git,
documentação, chat ou arquivo `.env` local.

Campos esperados no arquivo:

```dotenv
PORT=8787
MYSQL_HOST=<endpoint privado do DB System>
MYSQL_PORT=3306
MYSQL_USER=febraban
MYSQL_PASSWORD=<segredo>
MYSQL_DATABASE=fraud_demo_public
MYSQL_SSL=true
HEATWAVE_MODEL_PRELOADED=true
HEATWAVE_MODEL_HANDLE=<handle da cópia pertencente ao usuário febraban>
```

## Procedimento seguro para rotacionar a senha

1. Conectar ao DB System com uma conta administrativa, por canal seguro.
2. Executar `ALTER USER` somente para `febraban`.
3. Atualizar `MYSQL_PASSWORD` no arquivo protegido da VM.
4. Reiniciar a aplicação:

```bash
sudo systemctl restart febraban-fraud-copilot
sudo systemctl is-active febraban-fraud-copilot
curl -fsS http://127.0.0.1:8787/api/health
```

5. Confirmar que a resposta contém `"database":"ok"`.

Se qualquer etapa falhar, não use uma credencial administrativa como solução
permanente. Corrija a credencial do usuário de aplicação e repita a validação.

## Verificação antes de uma demo

```bash
sudo systemctl is-active febraban-fraud-copilot
curl -fsS http://127.0.0.1:8787/api/health
curl -sS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8787/api/dashboard
```

Esperado:

- serviço `active`;
- health com `database: ok`;
- dashboard com HTTP `200`.

## Inicialização automática após reinício da VM

Em 17/08/2026, os dois serviços foram habilitados para iniciar no boot:

```bash
sudo systemctl enable febraban-fraud-copilot nginx
```

A unidade `febraban-fraud-copilot` usa `WantedBy=multi-user.target`, aguarda
`network-online.target` e está configurada com `Restart=on-failure` e espera
de 5 segundos entre tentativas. Assim, após o boot, ela só inicia depois que a
rede estiver disponível e volta automaticamente caso o processo Node falhe.

Validação feita após reinício controlado dos serviços:

- `febraban-fraud-copilot`: `active`;
- `nginx`: `active`;
- API de saúde: `database: ok`;
- proxy na porta pública: HTTP `200`.

## HeatWave

As tabelas usadas pela demo precisam estar disponíveis no cluster analítico.
Antes do evento, confirme `LOAD_PROGRESS = 100` em
`performance_schema.rpd_tables` e faça uma consulta controlada com
`SET SESSION use_secondary_engine = FORCED`.

A validação realizada em 17/08/2026 está em
[`VALIDACAO-VM-HEATWAVE-2026-08-17.md`](VALIDACAO-VM-HEATWAVE-2026-08-17.md).

### Modelo de ML usado pela aplicação

O modelo não deve ser consumido diretamente do catálogo de outro usuário. O
modelo de produção desta demo foi importado para `ML_SCHEMA_febraban`, tornando
`febraban` o proprietário da cópia utilizada pela aplicação. Isso evita falhas
internas de acesso a `MODEL_CATALOG` durante `ML_PREDICT_TABLE`.

Caso o modelo seja retreinado pelo administrador, repita o fluxo oficial
`ML_MODEL_EXPORT` (proprietário) + `ML_MODEL_IMPORT` (usuário da aplicação),
carregue a cópia e atualize apenas `HEATWAVE_MODEL_HANDLE` no arquivo protegido.
Não colocar o handle, a senha ou qualquer endpoint privado no repositório.

### Papéis administrativos

Neste DB System existe a role `administrator`. Ela foi atribuída ao usuário
`febraban` e definida como `DEFAULT ROLE`, de modo que é ativada em cada nova
conexão. O usuário `admin` permanece a conta administradora inicial do DB
System. Para administração de tarefas assíncronas, `mysql_task_admin` também
está atribuída ao usuário `febraban`, junto com `mysql_task_user` para
operações de vetorização.

O serviço pode restringir a delegação de privilégios globais, mesmo para a
conta `admin`. A operação usa a role `administrator` e os grants de AutoML,
GenAI e schemas necessários, em vez de depender de `GRANT ALL ON *.*`.

## Diagnóstico rápido

| Sintoma | Verificação | Ação segura |
| --- | --- | --- |
| `database: degraded` | health local e variáveis no arquivo protegido | Validar o usuário `febraban`, senha e rota privada; reiniciar o serviço. |
| Dashboard não abre | `systemctl status` e log do Nginx | Confirmar Nginx, serviço Node e porta 3500. |
| Consulta forçada falha | `performance_schema.rpd_tables` | Confirmar o estado de carga no HeatWave antes de alterar a aplicação. |

Nunca inclua credenciais no log, no retorno de APIs, no repositório ou em
capturas de tela.
