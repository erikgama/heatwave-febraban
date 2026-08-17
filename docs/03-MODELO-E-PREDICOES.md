---
layout: default
title: Modelo e predições
---

# 3. Consolidar dados, treinar e usar o modelo

## Features B1

Para a primeira versão demonstrável, use apenas dados disponíveis no instante da
compra: `amount`, `amount_log = LN(1+amount)`, `category`,
`transaction_hour` e `customer_merchant_distance_km`. `is_fraud` é o target,
não feature. ID e timestamp servem para auditoria; não entram no treinamento.

```sql
CREATE TABLE fraud_ml.features_b1 AS
SELECT transaction_id, source_split, trans_date_trans_time AS transaction_timestamp,
 CAST(amt AS DECIMAL(14,2)) AS amount, LN(1+CAST(amt AS DECIMAL(14,2))) AS amount_log,
 category, HOUR(trans_date_trans_time) AS transaction_hour,
 6371*2*ASIN(SQRT(POWER(SIN(RADIANS(merch_lat-customer_lat)/2),2)
 +COS(RADIANS(customer_lat))*COS(RADIANS(merch_lat))*POWER(SIN(RADIANS(merch_long-customer_long)/2),2))) AS customer_merchant_distance_km,
 is_fraud
FROM fraud_demo.transactions_raw;
```

## Separação temporal

Preserve `source_split='test'` até a avaliação final. Dentro de `train`, use a
parte anterior para desenvolvimento e posterior para validação.

```sql
CREATE TABLE fraud_ml.train_final AS SELECT * FROM fraud_ml.features_b1 WHERE source_split='train';
CREATE TABLE fraud_ml.test_final AS SELECT * FROM fraud_ml.features_b1 WHERE source_split='test';
CREATE TABLE fraud_ml.train_development AS
SELECT * FROM fraud_ml.features_b1
WHERE source_split='train' AND transaction_timestamp < '2020-03-06 07:16:43';
CREATE TABLE fraud_ml.train_validation AS
SELECT * FROM fraud_ml.features_b1
WHERE source_split='train' AND transaction_timestamp >= '2020-03-06 07:16:43';
```

Crie desenvolvimento/validação usando um timestamp de corte documentado. A
separação temporal evita que a seleção de threshold use observações futuras.

## Treinar XGBoost

```sql
SET @model_dev='fraud_xgb_b1_dev_v1';
CALL sys.ML_TRAIN('fraud_ml.train_development','is_fraud',
 JSON_OBJECT('task','classification','model_list',JSON_ARRAY('XGBClassifier'),
 'optimization_metric','f1',
 'exclude_column_list',JSON_ARRAY('transaction_id','transaction_timestamp','source_split')),
 @model_dev);
```

O tempo depende da shape, dados e carga. Em uma referência de 1,3 milhão de
linhas, o treino final levou cerca de 81 minutos; não o trate como interação de
palco.

## Avaliar

Rode `ML_PREDICT_TABLE` sobre validação e extraia a probabilidade da classe `1`
do JSON `ml_results`. Compare thresholds com precisão, recall, F1, ROC AUC,
volume de alertas e matriz de confusão. Congele o threshold na validação e só
então avalie uma vez no split de teste. `0.27` foi uma referência deste
laboratório, não uma regra universal. Acurácia sozinha é inadequada para uma
classe positiva próxima de 0,5%.

```sql
DROP TABLE IF EXISTS fraud_ml.validation_predictions;
CALL sys.ML_PREDICT_TABLE(
  'fraud_ml.train_validation', @model_dev,
  'fraud_ml.validation_predictions', NULL
);

SELECT transaction_id, is_fraud AS actual_is_fraud,
       CAST(JSON_UNQUOTE(JSON_EXTRACT(ml_results,'$.probabilities."1"')) AS DECIMAL(12,10))
         AS fraud_probability
FROM fraud_ml.validation_predictions
LIMIT 10;
```

Para scoring operacional, use filas e lotes pequenos. Em versões recentes que
recomendam limitar entradas longas, uma janela lógica de 5 mil eventos pode ser
dividida em chamadas de no máximo mil linhas, mantendo a mesma `run_id`.

Após escolher o threshold, treine `fraud_xgb_b1_v1` em `train_final` com as
mesmas opções e avalie-o uma única vez em `test_final`. Não volte ao teste para
ajustar o threshold ou features.

## Carregar e predizer

```sql
CALL sys.ML_MODEL_LOAD(@model,NULL);
SELECT sys.ML_PREDICT_ROW(JSON_OBJECT(
 'amount',1200.00,'amount_log',LN(1201.00),'category','shopping_net',
 'transaction_hour',2,'customer_merchant_distance_km',15.8), @model,NULL) AS prediction;
```

Para eventos ao vivo, pontue lotes com `ML_PREDICT_TABLE` e persista score,
faixa de risco, timestamp e `run_id` em tabela isolada. O modelo precisa estar
carregado e fica ativo até unload ou reinício do cluster; monitore com
`ML_MODEL_ACTIVE` e não dispare cargas duplicadas.
