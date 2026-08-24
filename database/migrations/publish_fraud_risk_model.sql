-- Camada canônica da demonstração FEBRABAN.
--
-- Publica o modelo de risco e seus scores históricos sem expor identificadores
-- de experimentos. Execute como admin em cada DB System e valide como febraban.

SELECT
  COUNT(*) AS scored_transactions,
  SUM(fraud_probability >= 0.60) AS alerts_at_060
FROM fraud_ml.test_scores_b1_v2;

-- Alias estável para a tabela histórica de avaliação. A tabela física de
-- experimento é preservada por rastreabilidade; consumidores usam só este nome.
CREATE OR REPLACE
  ALGORITHM = MERGE
  SQL SECURITY INVOKER
VIEW fraud_ml.fraud_risk_test_scores AS
SELECT *
FROM fraud_ml.test_scores_b1_v2;

CREATE OR REPLACE
  ALGORITHM = MERGE
  DEFINER = `admin`@`%`
  SQL SECURITY DEFINER
VIEW fraud_demo_public.v_fraud_predictions AS
SELECT
  t.transaction_id,
  t.source_split,
  t.transaction_timestamp,
  t.transaction_date,
  t.transaction_hour,
  t.weekday_name,
  t.customer_id,
  t.merchant_name,
  t.category,
  t.amount,
  t.gender,
  t.age_band,
  t.city,
  t.state,
  t.city_pop,
  t.job,
  t.customer_merchant_distance_km,
  t.dataset_fraud_label,
  t.dataset_label_description,
  p.fraud_probability,
  CAST(p.fraud_probability >= 0.60 AS UNSIGNED) AS model_risk_alert,
  CAST(0.60 AS DECIMAL(4,2)) AS decision_threshold,
  'fraud_risk_model' AS model_handle,
  NULL AS predicted_at
FROM fraud_demo_public.v_transactions_investigation AS t
INNER JOIN fraud_ml.fraud_risk_test_scores AS p
  ON p.transaction_id = t.transaction_id;

SELECT
  model_handle,
  decision_threshold,
  COUNT(*) AS scored_transactions,
  SUM(model_risk_alert = 1) AS predicted_alerts
FROM fraud_demo_public.v_fraud_predictions
GROUP BY model_handle, decision_threshold;
