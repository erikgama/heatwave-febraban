# Inventário ativo do laboratório FEBRABAN

Este documento é o contrato de dados para quem usa Codex, OpenCode ou outra
ferramenta para criar experiências sobre o laboratório. Ele descreve somente
os objetos **ativos e suportados**; tabelas antigas de benchmark, treino e
experimentos continuam no banco como histórico técnico, mas não devem ser
usadas como fonte de uma nova aplicação.

## Como este inventário foi validado

Em 24/08/2026, o inventário abaixo foi consultado com o usuário `febraban` nos
três DB Systems do laboratório. Os nomes, tipos e ordem das colunas dos 12
objetos ativos apresentaram o mesmo hash de contrato nos três ambientes.

- `207.211.189.43`
- `207.211.177.73`
- `164.152.31.115`

Para validar novamente, sem alterar dados:

```sql
SHOW FULL TABLES FROM fraud_demo;
SHOW FULL TABLES FROM fraud_demo_public;
SHOW FULL TABLES FROM fraud_ml;
SHOW FULL TABLES FROM febraban_rag;

SELECT table_schema, table_name, ordinal_position, column_name, column_type
FROM information_schema.columns
WHERE (table_schema = 'fraud_demo' AND table_name IN
         ('transactions_raw', 'live_transaction_seed', 'live_transaction_events'))
   OR (table_schema = 'fraud_demo_public' AND table_name IN
         ('v_transactions_investigation', 'v_category_summary',
          'v_merchant_summary', 'v_state_summary', 'v_fraud_predictions',
          'v_live_transaction_events'))
   OR (table_schema = 'fraud_ml' AND table_name IN
         ('live_scoring_stage', 'live_scoring_result'))
   OR (table_schema = 'febraban_rag' AND table_name = 'fraud_risk_knowledge_base')
ORDER BY table_schema, table_name, ordinal_position;
```

## Regra de uso por camada

| Necessidade | Fonte certa |
| --- | --- |
| Investigação histórica, dashboard e NL_SQL | Views de `fraud_demo_public` |
| Origem completa do dataset, inclusive dados sintéticos sensíveis | `fraud_demo.transactions_raw` — não expor em UI/chat público |
| Simulação de eventos e scores da rodada | `fraud_demo.live_transaction_*` e `fraud_demo_public.v_live_transaction_events` |
| Staging/resultados temporários de classificação em lote | `fraud_ml.live_scoring_*` |
| Documento vetorizado para ML_RAG | `febraban_rag.fraud_risk_knowledge_base` |

## `fraud_demo` — dados de origem e simulação

### `transactions_raw` — tabela de origem Sparkov

Não é fonte pública de chat ou dashboard: contém identificadores e PII
sintéticos. É usada como origem técnica da camada pública.

`transaction_id`, `source_split`, `trans_date_trans_time`, `cc_num`,
`merchant`, `category`, `amt`, `first_name`, `last_name`, `gender`, `street`,
`city`, `state`, `zip`, `customer_lat`, `customer_long`, `city_pop`, `job`,
`dob`, `trans_num`, `unix_time`, `merch_lat`, `merch_long`, `is_fraud`.

Mapeamentos relevantes: `amt` vira `amount` nas views; `merchant` vira
`merchant_name`; `is_fraud` vira `dataset_fraud_label`. O campo `is_fraud` é
um rótulo histórico sintético, não uma confirmação de fraude real.

### `live_transaction_seed` — tabela de sementes coerentes

É a fonte recomendada para criar novos eventos de simulação sem inventar
combinações fora do contrato do modelo.

`source_transaction_id`, `merchant_name`, `category`, `city`, `state`,
`amount`, `amount_log`, `transaction_hour`, `weekday_number`, `is_weekend`,
`customer_merchant_distance_km`.

### `live_transaction_events` — tabela de eventos da rodada

Cada execução deve ter um `run_id` novo. Esta tabela armazena o evento
simulado e, após o scoring, o resultado do modelo.

`event_id`, `run_id`, `event_timestamp`, `customer_id`, `merchant_name`,
`category`, `city`, `state`, `amount`, `amount_log`, `transaction_hour`,
`weekday_number`, `is_weekend`, `customer_merchant_distance_km`,
`model_prediction`, `fraud_probability`, `risk_band`, `created_at`.

## `fraud_demo_public` — views seguras para aplicações

Estas são as fontes preferenciais para NL_SQL, dashboards e investigação. Elas
não expõem número de cartão, nome, endereço, CEP, data de nascimento ou
coordenadas da origem.

### `v_transactions_investigation`

Granularidade: uma transação histórica.

`transaction_id`, `source_split`, `transaction_timestamp`, `transaction_date`,
`transaction_hour`, `weekday_name`, `customer_id`, `merchant_name`,
`category`, `amount`, `gender`, `age_band`, `city`, `state`, `city_pop`, `job`,
`customer_merchant_distance_km`, `dataset_fraud_label`,
`dataset_label_description`.

### `v_category_summary`

Granularidade: categoria.

`category`, `transaction_count`, `total_amount`, `avg_amount`,
`labeled_fraud_count`, `labeled_fraud_pct`.

### `v_merchant_summary`

Granularidade: estabelecimento e categoria.

`merchant_name`, `category`, `transaction_count`, `total_amount`, `avg_amount`,
`labeled_fraud_count`, `labeled_fraud_pct`.

### `v_state_summary`

Granularidade: estado.

`state`, `transaction_count`, `total_amount`, `avg_amount`,
`labeled_fraud_count`, `labeled_fraud_pct`.

### `v_fraud_predictions`

Granularidade: transação do split histórico de teste, com predição do modelo
canônico.

`transaction_id`, `source_split`, `transaction_timestamp`, `transaction_date`,
`transaction_hour`, `weekday_name`, `customer_id`, `merchant_name`,
`category`, `amount`, `gender`, `age_band`, `city`, `state`, `city_pop`, `job`,
`customer_merchant_distance_km`, `dataset_fraud_label`,
`dataset_label_description`, `fraud_probability`, `model_risk_alert`,
`decision_threshold`, `model_handle`, `predicted_at`.

### `v_live_transaction_events`

Granularidade: evento da simulação corrente. Tem as mesmas colunas de
`fraud_demo.live_transaction_events`:

`event_id`, `run_id`, `event_timestamp`, `customer_id`, `merchant_name`,
`category`, `city`, `state`, `amount`, `amount_log`, `transaction_hour`,
`weekday_number`, `is_weekend`, `customer_merchant_distance_km`,
`model_prediction`, `fraud_probability`, `risk_band`, `created_at`.

Sempre filtre por `run_id` ao consultar uma rodada específica. O alerta
operacional é `fraud_probability >= 0.60`.

## `fraud_ml` — classificação em lote

### `live_scoring_stage`

Tabela temporária de entrada para `sys.ML_PREDICT_TABLE`.

`event_id`, `amount`, `amount_log`, `category`, `transaction_hour`,
`weekday_number`, `is_weekend`, `customer_merchant_distance_km`.

As sete últimas colunas são exatamente as features do modelo;
`event_id` serve somente para reconciliar o resultado com o evento original.

### `live_scoring_result`

Saída de `sys.ML_PREDICT_TABLE` para o lote em processamento.

`event_id`, `amount`, `amount_log`, `category`, `transaction_hour`,
`weekday_number`, `is_weekend`, `customer_merchant_distance_km`, `Prediction`,
`ml_results`.

`ml_results` contém o JSON nativo com a classe e as probabilidades. A aplicação
extrai a probabilidade da classe positiva, grava em `fraud_probability` e
deriva `risk_band` no evento persistido.

## `febraban_rag` — Vector Store canônico

### `fraud_risk_knowledge_base`

É o único Vector Store a usar em ML_RAG neste laboratório. As colunas são:

`document_name`, `metadata`, `document_id`, `segment_number`, `segment`,
`segment_embedding`, `segment_metadata`.

O `segment_embedding` é `VECTOR(6000)`, gerado com
`cohere.embed-v4.0` (OCI Generative AI/GPU). Não misture stores históricos de
teste com este store canônico.

## Modelo ativo

Consulte `ML_SCHEMA_febraban.MODEL_CATALOG`, não um nome histórico de tabela.
O catálogo confirmou nos três DB Systems:

- handle: `fraud_risk_model`;
- proprietário: `febraban`;
- algoritmo: `XGBClassifier`;
- tarefa: `classification`;
- target histórico: `is_fraud`;
- dataset de treino registrado: `fraud_ml.features_manual_b1_train_full_v2`;
- features: `amount`, `amount_log`, `category`, `transaction_hour`,
  `weekday_number`, `is_weekend`, `customer_merchant_distance_km`.

## Sugestão simples: criar uma simulação de transações

Se alguém quiser criar uma experiência de transações chegando em tempo real,
não precisa recriar a base nem retreinar o modelo.

1. Leia linhas de `fraud_demo.live_transaction_seed` para preservar combinações
   de categoria, valor, horário, dia da semana e distância já compatíveis com
   o modelo.
2. Crie um `run_id` novo e grave eventos em
   `fraud_demo.live_transaction_events`; mantenha `amount_log = LN(1 + amount)`
   e faça `is_weekend` coerente com `weekday_number`.
3. Em lote — não por linha — copie as oito colunas de
   `fraud_ml.live_scoring_stage` e execute `sys.ML_PREDICT_TABLE` com o handle
   `fraud_risk_model`.
4. Leia `fraud_ml.live_scoring_result`, persista a probabilidade no evento e
   considere alerta quando `fraud_probability >= 0.60`.
5. Exiba e consulte a rodada pela view
   `fraud_demo_public.v_live_transaction_events`, sempre filtrada pelo
   `run_id` atual.

Use apenas um worker para as tabelas de staging e resultado compartilhadas, ou
crie staging/resultados isolados por execução. Nunca use `ML_PREDICT_ROW` em
loop para milhares de eventos: o fluxo de alto volume do laboratório é
`ML_PREDICT_TABLE`.
