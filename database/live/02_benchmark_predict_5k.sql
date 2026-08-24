-- Benchmark controlado para decidir o tamanho do checkpoint de score ao vivo.
-- HeatWave / modelo de risco canônico. Não altera a base histórica.
-- A entrada vem de 5.000 linhas já transformadas para o mesmo schema do treino.

DROP TABLE IF EXISTS fraud_ml.live_prediction_benchmark_5k_output;
DROP TABLE IF EXISTS fraud_ml.live_prediction_benchmark_5k_input;

CREATE TABLE fraud_ml.live_prediction_benchmark_5k_input AS
SELECT
  transaction_id AS event_id,
  amount,
  amount_log,
  category,
  transaction_hour,
  weekday_number,
  is_weekend,
  customer_merchant_distance_km
FROM fraud_ml.features_manual_b1_train_full_v2
LIMIT 5000;

ALTER TABLE fraud_ml.live_prediction_benchmark_5k_input
  ADD PRIMARY KEY (event_id);

CALL sys.ML_MODEL_LOAD('fraud_risk_model', NULL);

CALL sys.ML_PREDICT_TABLE(
  'fraud_ml.live_prediction_benchmark_5k_input',
  'fraud_risk_model',
  'fraud_ml.live_prediction_benchmark_5k_output',
  NULL
);

SELECT
  COUNT(*) AS scored_rows,
  SUM(CAST(JSON_UNQUOTE(JSON_EXTRACT(ml_results, '$.predictions.is_fraud')) AS UNSIGNED)) AS predicted_alerts_at_model_threshold,
  ROUND(AVG(CAST(JSON_UNQUOTE(JSON_EXTRACT(ml_results, '$.probabilities."1"')) AS DECIMAL(12,8))), 6) AS avg_fraud_probability,
  ROUND(MAX(CAST(JSON_UNQUOTE(JSON_EXTRACT(ml_results, '$.probabilities."1"')) AS DECIMAL(12,8))), 6) AS max_fraud_probability
FROM fraud_ml.live_prediction_benchmark_5k_output;
