-- Publicação da camada de predições B1 V2 para a demonstração FEBRABAN.
--
-- Objetivo: publicar os scores do modelo B1 V2 na view pública com um único
-- threshold operacional de 0.60.
--
-- Pré-requisitos validados para cada clone:
--   * fraud_ml.test_scores_b1_v2 contém 555.719 scores (split test);
--   * fraud_demo_public.v_transactions_investigation contém as transações;
--   * modelo B1 V2: febraban_fraud_manual_xgb_b1_final_v2_20260810.
--
-- Execute como administrador. Depois, valide como o usuário febraban.

SELECT
  COUNT(*) AS b1_test_scores,
  SUM(fraud_probability >= 0.60) AS alerts_at_060
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
  'febraban_fraud_manual_xgb_b1_final_v2_20260810' AS model_handle,
  NULL AS predicted_at
FROM fraud_demo_public.v_transactions_investigation AS t
INNER JOIN fraud_ml.test_scores_b1_v2 AS p
  ON p.transaction_id = t.transaction_id;

-- Resultado esperado: 555.719 linhas, threshold 0.60, 1.593 alertas.
SELECT
  model_handle,
  decision_threshold,
  COUNT(*) AS scored_transactions,
  SUM(model_risk_alert = 1) AS predicted_alerts
FROM fraud_demo_public.v_fraud_predictions
GROUP BY model_handle, decision_threshold;
