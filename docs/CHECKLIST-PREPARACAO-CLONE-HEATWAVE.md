# Checklist de preparação de um clone HeatWave

Use este roteiro para deixar um clone do laboratório **HeatWave Fraud Copilot**
pronto para a demonstração. Ele separa rede, dados, cluster analítico, modelo,
RAG, NL_SQL, aplicação e teste integrado.

> Nunca registre senha, chave SSH, token ou endpoint privado em Git, chat,
> print ou arquivo versionado. Use os arquivos protegidos da VM para segredos.

## Critério de pronto

O ambiente está pronto somente quando todos estes pontos forem verdadeiros:

- a VM alcança o DB System em `3306`;
- as tabelas analíticas estão em `LOAD_PROGRESS = 100`;
- a aplicação consegue pontuar com o modelo pertencente ao usuário `febraban`;
- o Vector Store responde via `ML_RAG` com citações;
- perguntas analíticas usam `NL_SQL`, e perguntas documentais usam `ML_RAG`;
- o dashboard, a simulação e o chat funcionam pela URL pública da demo.

---

## 1. Registrar o clone e testar a rede

Preencha para cada clone, sem salvar segredo:

| Item | Valor |
| --- | --- |
| Endpoint público (administração) | `<HOST_PUBLICO>` |
| Endpoint privado (VM -> banco) | `<HOST_PRIVADO>` |
| Porta MySQL | `3306` |
| VM da demo | `<IP_DA_VM>` |
| URL pública da demo | `http://<IP_DA_VM>:3500` |

### 1.1 Do computador administrativo

```bash
nc -vz -w 5 <HOST_PUBLICO> 3306
mysql --ssl-mode=REQUIRED -h <HOST_PUBLICO> -P 3306 -u admin -p -e \
  "SELECT @@version AS mysql_version, @@hostname AS dbsystem;"
```

Esperado: conexão TCP aberta e uma linha com a versão do MySQL HeatWave.

### 1.2 Da VM da aplicação

```bash
nc -vz -w 5 <HOST_PRIVADO> 3306
mysql --ssl-mode=REQUIRED -h <HOST_PRIVADO> -P 3306 -u febraban -p -e \
  "SELECT CURRENT_USER(), CURRENT_ROLE();"
```

Esperado: as duas conexões devem funcionar. Se o público funcionar e o privado
não, revise NSG/security list, rota/sub-rede e DNS privado. Se o privado
funcionar e o público não, revise a allowlist de origem do computador
administrativo. Um timeout é rede; não é um erro de senha nem de HeatWave.

---

## 2. Validar versão, schemas e views

Com o usuário `admin`, execute no clone:

```sql
SELECT @@version AS mysql_version, @@hostname AS dbsystem;

SHOW DATABASES LIKE 'fraud%';
SHOW TABLES FROM fraud_demo;
SHOW FULL TABLES FROM fraud_demo_public WHERE Table_type = 'VIEW';

SELECT COUNT(*) AS transaction_count
FROM fraud_demo_public.v_transactions_investigation;
```

Esperado para o dataset histórico: `1.852.394` transações. As views necessárias
incluem, no mínimo:

- `v_transactions_investigation`;
- `v_category_summary`;
- `v_merchant_summary`;
- `v_state_summary`;
- `v_live_transaction_events`.

Se uma view estiver ausente, aplique o bootstrap correspondente antes de
prosseguir. O catálogo público é a única camada que o NL_SQL deve receber.

---

## 3. Carregar e validar o cluster analítico

Execute com `admin`:

```sql
ALTER TABLE fraud_demo.transactions_raw SECONDARY_LOAD;
ALTER TABLE fraud_demo.live_transaction_seed SECONDARY_LOAD;
ALTER TABLE fraud_demo.live_transaction_events SECONDARY_LOAD;
ALTER TABLE fraud_ml.live_scoring_stage SECONDARY_LOAD;

SELECT i.SCHEMA_NAME, i.TABLE_NAME, t.LOAD_PROGRESS, t.LOAD_STATUS,
       t.NROWS AS table_rows
FROM performance_schema.rpd_table_id AS i
JOIN performance_schema.rpd_tables AS t ON t.ID = i.ID
WHERE i.SCHEMA_NAME IN ('fraud_demo', 'fraud_ml')
  AND i.TABLE_NAME IN (
    'transactions_raw',
    'live_transaction_seed',
    'live_transaction_events',
    'live_scoring_stage'
  )
ORDER BY i.SCHEMA_NAME, i.TABLE_NAME;
```

Só avance quando todas as tabelas necessárias estiverem com
`LOAD_PROGRESS = 100` e estado disponível.

Smoke test do cluster:

```sql
SET SESSION use_secondary_engine = FORCED;
SELECT COUNT(*) AS transaction_count, ROUND(SUM(amount), 2) AS total_amount
FROM fraud_demo_public.v_transactions_investigation;
```

Esperado: consulta concluída sem erro de secondary engine. Não use a mesma
sessão forçada para `ML_RAG`; o procedimento consulta metadados de sessão.

---

## 4. Confirmar o modelo de risco

O modelo que a aplicação usa precisa ser propriedade do usuário `febraban` em
`ML_SCHEMA_febraban`; não aponte o backend para um catálogo pertencente apenas
ao administrador. Confirme as features pelo próprio `ML_PREDICT_ROW`: o
contrato pode ser diferente entre versões de modelo.

```sql
SELECT model_handle, model_owner, model_type, model_object
FROM ML_SCHEMA_febraban.MODEL_CATALOG
ORDER BY model_handle;
```

Anote o `model_handle` escolhido somente no arquivo protegido da VM.

### 4.1 Carregar e testar como usuário da aplicação

Conecte como `febraban` e execute:

```sql
CALL sys.ML_MODEL_LOAD('<MODEL_HANDLE_DA_APLICACAO>', NULL);

SELECT JSON_PRETTY(
  sys.ML_PREDICT_ROW(
    JSON_OBJECT(
      'amount', 1200.00,
      'amount_log', LN(1201.00),
      'category', 'shopping_net',
      'customer_merchant_distance_km', 15.8,
      'weekday_number', 2,
      'is_weekend', 0,
      'transaction_hour', 2
    ),
    '<MODEL_HANDLE_DA_APLICACAO>',
    NULL
  )
) AS prediction;
```

Esperado: JSON com a previsão e probabilidades. No clone validado em
22/08/2026, a cópia do modelo pertencente a `febraban` exige as sete features
acima. `is_fraud` é o target histórico e **não** entra em uma nova predição.

Use este `ML_PREDICT_ROW` apenas como smoke test de uma compra. Para o fluxo de
maior volume — validação, scoring em produção ou a simulação da demo — carregue
o modelo uma vez e execute `ML_PREDICT_TABLE` sobre uma tabela de estágio/lote.
Não implemente uma fila grande como loop de chamadas `ML_PREDICT_ROW`; a
estratégia operacional da demo classifica janelas de 5.000 eventos com
`ML_PREDICT_TABLE` e persiste os resultados por `run_id`.

O PDF e Vector Store ativos já estão alinhados ao contrato de sete features:
`GUIA-MODELO-E-DADOS-B1-V2-RAG-REV3-20260823.pdf` e
`febraban_rag.modelo_b1_v2_oci_embed_v4_rev3_20260823`. Não reutilize os stores
históricos com cinco features.

Se `ML_PREDICT_TABLE` ou `ML_MODEL_LOAD` retornar erro de catálogo, faça o
compartilhamento oficial: exporte como proprietário e importe como `febraban`.
Veja [09-RUNBOOK-OPERACIONAL-E-POLITICA-DE-ACESSOS.md](09-RUNBOOK-OPERACIONAL-E-POLITICA-DE-ACESSOS.md).

---

## 5. Validar privilégios do usuário `febraban`

No ambiente de laboratório, o usuário da aplicação precisa das roles e grants
especializados já descritos no runbook. Confirme sem expor o resultado em logs
do navegador:

```sql
SELECT CURRENT_USER(), CURRENT_ROLE();
SELECT model_handle, model_owner FROM ML_SCHEMA_febraban.MODEL_CATALOG;
SELECT COUNT(*) FROM fraud_demo_public.v_transactions_investigation;
```

O conjunto operacional vigente está documentado em
[09-RUNBOOK-OPERACIONAL-E-POLITICA-DE-ACESSOS.md](09-RUNBOOK-OPERACIONAL-E-POLITICA-DE-ACESSOS.md):

- role `administrator` como padrão no laboratório;
- roles `mysql_task_user` e `mysql_task_admin`;
- acesso a `fraud_demo`, `fraud_ml`, `fraud_demo_public`,
  `ML_SCHEMA_febraban` e rotinas `sys` necessárias;
- permissões GenAI/Vector Store.

Em produção, substitua a role ampla por privilégios mínimos e uma conta de
serviço dedicada. Para a demonstração, mantenha o navegador sem qualquer
credencial e as consultas do chat restritas a `SELECT`/`WITH`.

---

## 6. Preparar documentação vetorial e testar ML_RAG

Um clone pode preservar a tabela física de embeddings, mas não preservar o
registro funcional do Vector Store. Por isso, valide por uma chamada real de
`ML_RAG`, não apenas com `SHOW TABLES`.

### 6.1 Se ainda não existir Vector Store funcional

Use o PDF canônico já publicado no Object Storage e crie um store com nome
novo, sem sobrescrever stores anteriores:

```sql
CALL sys.VECTOR_STORE_LOAD(
  'oci://<BUCKET>@<NAMESPACE>/febraban/GUIA-MODELO-E-DADOS-B1-V2-RAG-REV3-20260823.pdf',
  JSON_OBJECT(
    'schema_name', 'febraban_rag',
    'table_name', 'modelo_b1_v2_oci_embed_v4_rev3_<IDENTIFICADOR_DO_CLONE>',
    'task_name', 'febraban_rag_gpu_rev3_<IDENTIFICADOR_DO_CLONE>',
    'language', 'pt',
    'embed_model_id', 'cohere.embed-v4.0',
    'description', 'Guia B1 V2 revisado: sete features e threshold operacional 0.60; embedding OCI GPU.'
  )
);
```

Espere a tarefa assíncrona finalizar em `100%` antes de testar. Consulte o
status devolvido pela própria chamada `VECTOR_STORE_LOAD`.

### 6.2 Teste funcional

```sql
CALL sys.ML_RAG(
  'Qual é o threshold operacional do modelo B1 V2 e por que ele não confirma fraude?',
  @rag_output,
  JSON_OBJECT(
    'vector_store', JSON_ARRAY('febraban_rag.<NOME_REAL_DO_STORE>'),
    'embed_model_id', 'cohere.embed-v4.0',
    'n_citations', 6,
    'model_options', JSON_OBJECT(
      'model_id', 'meta.llama-3.3-70b-instruct',
      'language', 'pt'
    )
  )
);
SELECT JSON_PRETTY(@rag_output);
```

Esperado: texto que informa `0,60` como threshold operacional único, sempre
com citações. Registre o
nome real do store em `HEATWAVE_RAG_VECTOR_STORE` e
`cohere.embed-v4.0` em `HEATWAVE_RAG_EMBED_MODEL` na VM.

> Importante: antes de `ML_RAG`, a sessão deve usar
> `SET SESSION use_secondary_engine = OFF`. A sessão `FORCED` é exclusiva das
> consultas analíticas do dashboard e pode falhar dentro do procedimento RAG.

---

## 7. Validar NL_SQL nativo

Rode como usuário da aplicação, sempre restringindo a geração ao catálogo de
views públicas:

```sql
CALL sys.NL_SQL(
  'Gere somente um SELECT que mostre a categoria com mais registros rotulados do dataset.',
  @nl_output,
  JSON_OBJECT(
    'execute', false,
    'tables', JSON_ARRAY(
      JSON_OBJECT('schema_name', 'fraud_demo_public', 'table_name', 'v_category_summary')
    ),
    'model_id', 'meta.llama-3.3-70b-instruct',
    'verbose', 0,
    'include_comments', false,
    'use_retry', true
  )
);
SELECT JSON_PRETTY(@nl_output);
```

Esperado: `is_sql_valid = 1` e somente um `SELECT`. O backend deve validar o
SQL gerado antes de executar e nunca entregar schemas internos ao modelo.

---

## 8. Configurar a VM e iniciar automaticamente

Na VM, mantenha somente os valores no arquivo protegido:

```dotenv
PORT=8787
MYSQL_HOST=<ENDPOINT_PRIVADO_DO_CLONE>
MYSQL_PORT=3306
MYSQL_USER=febraban
MYSQL_PASSWORD=<SEGREDO>
MYSQL_DATABASE=fraud_demo_public
MYSQL_SSL=true
USE_MOCK_DATA=false
USE_HEATWAVE_NL_SQL=true
HEATWAVE_NL_SQL_MODEL=meta.llama-3.3-70b-instruct
USE_HEATWAVE_RAG=true
HEATWAVE_RAG_VECTOR_STORE=febraban_rag.<NOME_REAL_DO_STORE>
HEATWAVE_RAG_EMBED_MODEL=cohere.embed-v4.0
HEATWAVE_MODEL_HANDLE=<HANDLE_DO_MODELO_DO_FEBRABAN>
```

Depois:

```bash
sudo systemctl daemon-reload
sudo systemctl restart febraban-fraud-copilot nginx
sudo systemctl enable febraban-fraud-copilot nginx
sudo systemctl is-active febraban-fraud-copilot nginx
curl -fsS http://127.0.0.1:8787/api/health
curl -sS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:3500/
```

Esperado: dois serviços `active`, health com `database: ok` e HTTP `200`.
Os detalhes de operação e reboot estão em
[08-OPERACAO-VM-DEMO.md](08-OPERACAO-VM-DEMO.md).

---

## 9. Validação integrada do agente

No repositório, execute a bateria não destrutiva contra o clone. Ela valida
cluster por health check, NL_SQL, ML_RAG e memória de sessão:

```bash
MYSQL_HOST=<HOST_PUBLICO_OU_PRIVADO_ACESSIVEL> \
MYSQL_PORT=3306 \
MYSQL_USER=<USUARIO_DE_VALIDACAO> \
MYSQL_PASSWORD='<SEGREDO>' \
MYSQL_DATABASE=fraud_demo_public \
MYSQL_SSL=true \
USE_MOCK_DATA=false \
USE_HEATWAVE_NL_SQL=true \
HEATWAVE_NL_SQL_MODEL=meta.llama-3.3-70b-instruct \
USE_HEATWAVE_RAG=true \
HEATWAVE_RAG_VECTOR_STORE='febraban_rag.<NOME_REAL_DO_STORE>' \
HEATWAVE_RAG_EMBED_MODEL='cohere.embed-v4.0' \
HEATWAVE_RAG_TIMEOUT_MS=30000 \
./node_modules/.bin/tsx scripts/validate-clone-agent.ts
```

Esperado:

```json
{
  "status": "ok",
  "health": "ok",
  "nlSql": { "source": "MySQL HeatWave · NL_SQL" },
  "memory": { "sql": null },
  "rag": { "source": "MySQL HeatWave · ML_RAG" }
}
```

Por fim, execute a regressão local:

```bash
npm test
npm run build
```

---

## 10. Teste final de demonstração no navegador

1. Abra `http://<IP_DA_VM>:3500`.
2. Confirme que dashboard e cards carregam após a tela inicial.
3. Inicie a simulação e espere a rodada terminar.
4. Confira que os indicadores e gráficos aumentaram sem substituírem o valor
   histórico por apenas o valor da rodada.
5. Confirme que a tabela de transações previstas apresenta paginação, score,
   faixas de risco e detalhe ao clicar em uma linha.
6. Faça as perguntas abaixo, uma por vez:

   - `Qual categoria tem mais fraudes?` — deve indicar origem **NL_SQL** e
     exibir o SQL auditável.
   - `Quais estabelecimentos têm maior taxa de fraude?` — deve usar NL_SQL.
   - `Qual é o threshold operacional do modelo B1 V2?` — deve indicar
     **ML_RAG** e trazer citações.
   - `Qual categoria você mencionou na resposta anterior?` — deve usar memória
     da sessão, sem executar SQL.

7. Compare o total retornado no chat com cards e tabela quando a pergunta se
   referir à simulação atual.
8. Atualize a página ou use reset; confirme que a memória do chat foi apagada
   e que a base histórica não foi alterada de forma permanente.

---

## Diagnóstico rápido

| Sintoma | Causa mais provável | Ação segura |
| --- | --- | --- |
| `ERROR 2003` / timeout | porta, NSG, rota ou allowlist | testar `nc` a partir da origem real; não redefinir senha |
| `LOAD_PROGRESS` abaixo de 100 | carga no cluster pendente | aguardar ou executar `SECONDARY_LOAD` e monitorar |
| erro de `MODEL_CATALOG` | modelo pertence a outro usuário | exportar/importar o modelo para `febraban` |
| `ML_RAG` sem Vector Store | clone trouxe tabela, mas não o registro funcional | criar novo store com `VECTOR_STORE_LOAD` e atualizar a variável |
| `performance_schema.session_variables` no RAG | sessão herdou `FORCED` | executar RAG com `use_secondary_engine = OFF` |
| NL_SQL indisponível | serviço GenAI ainda não está ready | manter analytics disponíveis, aguardar e repetir uma vez |
| dashboard não abre após reboot | serviço ou Nginx inativo | checar `systemctl`, logs e `/api/health` |

## Evidência a registrar ao concluir

Registre apenas evidência não sensível:

- data/hora, hostname do DB System e versão;
- tabelas HeatWave com progresso 100%;
- handle do modelo da aplicação (sem senha);
- nome do Vector Store funcional;
- resultado resumido da bateria do item 9;
- URL pública e HTTP 200;
- resultado do teste de simulação e perguntas do item 10.
