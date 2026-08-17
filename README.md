# Laboratório FEBRABAN: MySQL HeatWave + IA para investigação de risco

Este é um laboratório **guiado por documentação**. Não contém aplicação pronta,
credenciais, dados privados ou artefatos do ambiente do evento. A proposta é que
você use um LLM/Codex como parceiro de implementação e reproduza cada etapa no
seu próprio MySQL HeatWave.

Revisão documental: agosto de 2026.

O resultado esperado é uma experiência com dados sintéticos, analytics no
cluster HeatWave, modelo de risco, predições, RAG documental, NL to SQL e uma
aplicação web construída no seu próprio ambiente.

> Sparkov é sintético. `is_fraud = 1` é um rótulo histórico do simulador. Um
> score é alerta de risco para investigação, nunca confirmação de fraude.

## Guia completo: do zero ao laboratório

Siga as etapas abaixo na ordem. Os documentos da pasta `docs/` aprofundam cada
tema, mas este README é suficiente para construir o laboratório inteiro.

### 1. Criar o DB System e o HeatWave Cluster

No OCI Console, abra **MySQL HeatWave > DB Systems > Create DB System**.

1. Escolha VCN e subnet com rota para seu computador ou bastion.
2. Crie a senha administrativa em um Vault; não a coloque em arquivos ou Git.
3. Após o DB System ficar ativo, adicione um **HeatWave Cluster**.
4. Dimensione o cluster para dados, features, tabelas de score, Vector Store e
   modelo carregado. Valide opções de shape na região antes de provisionar.
5. Conecte com TLS e confira a versão e os nós:

```bash
mysqlsh --sql admin@SEU_HOST:3306 --ssl-mode=REQUIRED
```

```sql
SELECT VERSION();
SELECT * FROM performance_schema.rpd_nodes;
```

Crie os schemas do laboratório e o usuário que a futura aplicação utilizará:

```sql
CREATE SCHEMA IF NOT EXISTS fraud_demo;
CREATE SCHEMA IF NOT EXISTS fraud_demo_public;
CREATE SCHEMA IF NOT EXISTS fraud_ml;
CREATE SCHEMA IF NOT EXISTS fraud_rag;

CREATE USER IF NOT EXISTS 'app_readonly'@'%' IDENTIFIED BY 'USE_UM_SECRET_DO_VAULT';
GRANT SELECT, SHOW VIEW ON fraud_demo_public.* TO 'app_readonly'@'%';
SHOW GRANTS FOR 'app_readonly'@'%';
```

### 2. Baixar e importar a base Sparkov

Baixe `fraudTrain.csv` e `fraudTest.csv` no
[Credit Card Transactions Fraud Detection Dataset — Kaggle](https://www.kaggle.com/datasets/kartik2112/fraud-detection/data).
São dados sintéticos. Crie a tabela de origem:

```sql
CREATE TABLE fraud_demo.transactions_raw (
  transaction_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  source_split ENUM('train','test') NOT NULL,
  trans_date_trans_time DATETIME NOT NULL,
  cc_num VARCHAR(32) NOT NULL,
  merchant VARCHAR(255) NOT NULL,
  category VARCHAR(64) NOT NULL,
  amt DECIMAL(14,2) NOT NULL,
  first_name VARCHAR(128), last_name VARCHAR(128), gender CHAR(1),
  street VARCHAR(255), city VARCHAR(128) NOT NULL, state CHAR(2) NOT NULL,
  zip VARCHAR(16), customer_lat DECIMAL(10,7) NOT NULL,
  customer_long DECIMAL(10,7) NOT NULL, city_pop INT, job VARCHAR(255),
  dob DATE, trans_num VARCHAR(64), unix_time BIGINT,
  merch_lat DECIMAL(10,7) NOT NULL, merch_long DECIMAL(10,7) NOT NULL,
  is_fraud TINYINT UNSIGNED NOT NULL,
  PRIMARY KEY (transaction_id),
  KEY ix_split_time (source_split, trans_date_trans_time),
  KEY ix_card_time (cc_num, trans_date_trans_time)
) ENGINE=InnoDB;
```

Use a importação CSV do MySQL Shell for VS Code ou ferramenta equivalente.

- Para `fraudTrain.csv`, preencha `source_split` com `train`.
- Para `fraudTest.csv`, preencha `source_split` com `test`.
- Ignore a coluna de índice inicial do CSV.
- Mapeie `lat` para `customer_lat`, `long` para `customer_long`, `first` para
  `first_name` e `last` para `last_name`.
- Deixe `transaction_id` automático.

Valide antes de seguir. A referência completa tem 1.852.394 transações e 9.651
linhas com label 1:

```sql
SELECT source_split, COUNT(*) AS transacoes, SUM(is_fraud) AS rotulos_1,
       MIN(trans_date_trans_time) AS inicio, MAX(trans_date_trans_time) AS fim
FROM fraud_demo.transactions_raw
GROUP BY source_split;
```

### 3. Carregar os dados no cluster analítico

```sql
ALTER TABLE fraud_demo.transactions_raw SECONDARY_LOAD;

SELECT i.SCHEMA_NAME, i.TABLE_NAME, t.NROWS, t.LOAD_STATUS, t.LOAD_PROGRESS
FROM performance_schema.rpd_table_id i
JOIN performance_schema.rpd_tables t ON t.ID=i.ID
WHERE i.SCHEMA_NAME='fraud_demo' AND i.TABLE_NAME='transactions_raw';
```

Espere `LOAD_STATUS` indicar carga concluída. Use `EXPLAIN` e as ferramentas de
observabilidade do HeatWave para comprovar que suas análises foram aceleradas.

### 4. Criar a camada pública de leitura

Não conecte chat ou dashboard diretamente à tabela bruta. Publique uma view sem
nome, endereço, cartão ou coordenadas:

```sql
CREATE OR REPLACE VIEW fraud_demo_public.v_transactions_investigation AS
SELECT transaction_id, source_split,
       trans_date_trans_time AS transaction_timestamp,
       CONCAT('C-',UPPER(SUBSTRING(SHA2(cc_num,256),1,10))) AS customer_id,
       REGEXP_REPLACE(merchant,'^fraud_','') AS merchant_name,
       category, amt AS amount, city, state,
       HOUR(trans_date_trans_time) AS transaction_hour,
       WEEKDAY(trans_date_trans_time) AS weekday_number,
       CASE WHEN WEEKDAY(trans_date_trans_time) IN (5,6) THEN 1 ELSE 0 END AS is_weekend,
       6371*2*ASIN(SQRT(POWER(SIN(RADIANS(merch_lat-customer_lat)/2),2)
         +COS(RADIANS(customer_lat))*COS(RADIANS(merch_lat))
         *POWER(SIN(RADIANS(merch_long-customer_long)/2),2)))
         AS customer_merchant_distance_km,
       is_fraud AS dataset_fraud_label
FROM fraud_demo.transactions_raw;
```

Também crie views-resumo por categoria, merchant, estado, hora, cliente e dia.
Cada view deve expor a dimensão, `transaction_count`, `labeled_fraud_count`,
`labeled_fraud_pct` e `total_amount` quando aplicável. Conceda à aplicação
somente `SELECT, SHOW VIEW` nesse schema público.

### 5. Consolidar features e separar treino/teste

O modelo B1 usa somente dados disponíveis no momento da compra:
`amount`, `amount_log`, `category`, `transaction_hour` e
`customer_merchant_distance_km`.

```sql
CREATE TABLE fraud_ml.features_b1 AS
SELECT transaction_id, source_split, trans_date_trans_time AS transaction_timestamp,
       CAST(amt AS DECIMAL(14,2)) AS amount,
       LN(1+CAST(amt AS DECIMAL(14,2))) AS amount_log,
       category, HOUR(trans_date_trans_time) AS transaction_hour,
       6371*2*ASIN(SQRT(POWER(SIN(RADIANS(merch_lat-customer_lat)/2),2)
         +COS(RADIANS(customer_lat))*COS(RADIANS(merch_lat))
         *POWER(SIN(RADIANS(merch_long-customer_long)/2),2)))
         AS customer_merchant_distance_km,
       is_fraud
FROM fraud_demo.transactions_raw;

CREATE TABLE fraud_ml.train_final AS
SELECT * FROM fraud_ml.features_b1 WHERE source_split='train';
CREATE TABLE fraud_ml.test_final AS
SELECT * FROM fraud_ml.features_b1 WHERE source_split='test';
```

Dentro de `train`, separe desenvolvimento e validação por tempo. Nunca escolha
threshold olhando o split `test`.

### 6. Treinar, avaliar e carregar o modelo

```sql
SET @model='fraud_xgb_b1_v1';
CALL sys.ML_TRAIN(
  'fraud_ml.train_final', 'is_fraud',
  JSON_OBJECT(
    'task','classification',
    'model_list',JSON_ARRAY('XGBClassifier'),
    'optimization_metric','f1',
    'exclude_column_list',JSON_ARRAY('transaction_id','transaction_timestamp')
  ),
  @model
);
```

Faça `ML_PREDICT_TABLE` sobre a validação e compare thresholds com precisão,
recall, F1, ROC AUC, alertas e matriz de confusão. O threshold de referência da
demo é `0.27`, mas não deve ser copiado sem validação local. Acurácia isolada
não é adequada para uma classe positiva perto de 0,5%.

Carregue o modelo antes de prever:

```sql
CALL sys.ML_MODEL_LOAD(@model,NULL);
CALL sys.ML_PREDICT_ROW(
  JSON_OBJECT(
    'amount',1200.00,
    'amount_log',LN(1201.00),
    'category','shopping_net',
    'transaction_hour',2,
    'customer_merchant_distance_km',15.8
  ),
  @model,@prediction
);
SELECT @prediction;
```

Para uma simulação ao vivo, use `ML_PREDICT_TABLE` em lotes e persista score,
faixa de risco, timestamp e `run_id` em uma tabela isolada. Score acima do
threshold é alerta previsto — não fraude confirmada.

### 7. Vetorizar o documento do modelo e testar RAG

Use [DOCUMENTO-MODELO-PARA-RAG.md](docs/DOCUMENTO-MODELO-PARA-RAG.md) como fonte
canônica. Exporte-o a PDF, envie-o a um bucket privado no Object Storage e
configure Resource Principal para o DB System lê-lo.

```sql
SET @options=JSON_OBJECT(
  'schema_name','fraud_rag',
  'table_name','modelo_b1_docs',
  'language','pt',
  'embed_model_id','multilingual-e5-small',
  'chunking',JSON_OBJECT('split_by','recursive')
);
CALL sys.VECTOR_STORE_LOAD(
  'oci://SEU_BUCKET@SEU_NAMESPACE/febraban/documento-modelo-rag.pdf', @options
);
```

`VECTOR_STORE_LOAD` é assíncrono: acompanhe a query de status devolvida pela
rotina. Quando terminar, teste `ML_RAG` e valide citações para perguntas sobre
features, dataset, threshold, métricas e limitações.

### 8. Habilitar NL to SQL com segurança

Gere SQL com execução desativada, em um schema limitado:

```sql
CALL sys.NL_SQL(
  'Qual categoria possui mais registros com rótulo histórico 1?',
  @generated_sql,
  JSON_OBJECT(
    'execute',false,
    'schemas',JSON_ARRAY('fraud_demo_public'),
    'model_id','meta.llama-3.3-70b-instruct'
  )
);
SELECT @generated_sql;
```

No backend, valide o SQL antes de executar: aceite apenas `SELECT`/`WITH`,
bloqueie DDL, DML, `CALL`, `LOAD`, comentários e múltiplas instruções; permita
somente views da allowlist; imponha `LIMIT`, timeout e pool de conexões; execute
como `app_readonly`; mostre o SQL ao visitante.

### 9. Criar e publicar a aplicação com Codex/LLM

Crie a aplicação no seu repositório privado. Ela deve ter dashboard, chat de
dados (`NL_SQL`), chat documental (`ML_RAG`), scoring em lote, tabela paginada
de transações pontuadas e memória apenas da sessão. Use este prompt inicial:

```text
Crie uma SPA React com backend Node.js para MySQL HeatWave. Use exclusivamente
o usuário app_readonly e views fraud_demo_public. Implemente dashboard com
agregações, chat de dados via NL_SQL com execute=false e validação rigorosa,
chat documental via ML_RAG com citações e scoring em lote com as cinco features
B1, persistido por run_id. Nunca exponha credenciais ou diga fraude confirmada
para label/score. Inclua reset da sessão, timeout, rate limit e SQL auditável.
```

Configure host, usuário, senha, TLS, modelos e Vector Store como segredos do
runtime. Antes de publicar, faça smoke tests de dashboard, cluster, NL to SQL,
RAG, score, reset e bloqueio de `DELETE`.

## Leitura complementar

Os documentos abaixo não são pré-requisito para seguir o README. Eles detalham
cada assunto, oferecem uma leitura navegável e fornecem o conteúdo do RAG.

| Etapa | Leitura guiada | Fonte Markdown | Resultado |
| --- | --- | --- | --- |
| 0 | [Visão geral](https://erikgama.github.io/heatwave-febraban/00-VISAO-GERAL.html) | [00-VISAO-GERAL.md](docs/00-VISAO-GERAL.md) | arquitetura e checklist |
| 1 | [DB System e cluster](https://erikgama.github.io/heatwave-febraban/01-DBSYSTEM-E-CLUSTER.html) | [01-DBSYSTEM-E-CLUSTER.md](docs/01-DBSYSTEM-E-CLUSTER.md) | HeatWave disponível |
| 2 | [Dados e camada pública](https://erikgama.github.io/heatwave-febraban/02-DADOS-E-CAMADA-PUBLICA.html) | [02-DADOS-E-CAMADA-PUBLICA.md](docs/02-DADOS-E-CAMADA-PUBLICA.md) | Sparkov importado |
| 3 | [Modelo e predições](https://erikgama.github.io/heatwave-febraban/03-MODELO-E-PREDICOES.html) | [03-MODELO-E-PREDICOES.md](docs/03-MODELO-E-PREDICOES.md) | XGBoost treinado e avaliado |
| 4 | [Analytics e NL to SQL](https://erikgama.github.io/heatwave-febraban/04-ANALYTICS-E-NL-SQL.html) | [04-ANALYTICS-E-NL-SQL.md](docs/04-ANALYTICS-E-NL-SQL.md) | consultas e chat de dados |
| 5 | [RAG documental](https://erikgama.github.io/heatwave-febraban/05-RAG-DOCUMENTAL.html) | [05-RAG-DOCUMENTAL.md](docs/05-RAG-DOCUMENTAL.md) | documento vetorizado |
| 6 | [Aplicação guiada por LLM](https://erikgama.github.io/heatwave-febraban/06-APLICACAO-GUIADA-POR-LLM.html) | [06-APLICACAO-GUIADA-POR-LLM.md](docs/06-APLICACAO-GUIADA-POR-LLM.md) | aplicação no seu ambiente |

## Dados usados

Fonte pública: [Credit Card Transactions Fraud Detection Dataset — Kaggle](https://www.kaggle.com/datasets/kartik2112/fraud-detection/data).
Baixe `fraudTrain.csv` e `fraudTest.csv` diretamente no Kaggle. A origem foi
gerada pelo [Sparkov](https://github.com/namebrandon/Sparkov_Data_Generation).

## Documento para vetorização

Use [Documento do modelo para RAG](https://erikgama.github.io/heatwave-febraban/DOCUMENTO-MODELO-PARA-RAG.html)
ou sua [fonte Markdown](docs/DOCUMENTO-MODELO-PARA-RAG.md) como conteúdo
canônico. Exporte-o para PDF, envie-o ao Object Storage e siga a etapa 5.

## O que este repositório deliberadamente não contém

- código da aplicação web do evento;
- senhas, tokens, chaves ou endpoints privados;
- CSVs do Kaggle;
- modelo exportado ou decisão automatizada.

## Referências oficiais

- [MySQL HeatWave User Guide](https://dev.mysql.com/doc/heatwave/en/)
- [Criar um DB System](https://dev.mysql.com/doc/heatwave/en/mys-hw-create-db-system.html)
- [Rotinas AutoML](https://dev.mysql.com/doc/heatwave/en/hw-routines.html)
- [NL to SQL](https://dev.mysql.com/doc/heatwave/en/mys-hw-genai-nl-sql.html)
- [Vector Store](https://dev.mysql.com/doc/heatwave/en/mys-hw-genai-vector-store-load.html)
