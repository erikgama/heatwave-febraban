# Resultados - modelo B1 V2 de risco

Data de referência: 23/08/2026  
Modelo: `febraban_fraud_manual_xgb_b1_final_v2_20260810`  
Threshold operacional único: **0,60**

## Contrato vigente

O B1 V2 é um `XGBClassifier` treinado no MySQL HeatWave com target histórico
sintético `is_fraud`. Ele recebe exatamente sete features:

`amount`, `amount_log`, `category`, `transaction_hour`, `weekday_number`,
`is_weekend` e `customer_merchant_distance_km`.

`is_fraud` nunca é enviado para uma nova predição. ID e timestamp são campos de
auditoria, não features. O score representa risco previsto, não fraude
confirmada.

## Treinamento e split

| Item | Resultado |
| --- | --- |
| Linhas de treino | 1.296.675 |
| Split de teste isolado | 555.719 transações |
| Algoritmo | `XGBClassifier` |
| Tempo de treino registrado | 4.835,99 s (aprox. 80,6 min) |
| Modelo no catálogo | `Ready` |

## Avaliação no split de teste com corte 0,60

| Métrica | Resultado |
| --- | ---: |
| Threshold | 0,60 |
| Precisão | 83,30% |
| Recall | 61,86% |
| F1 | 0,7100 |
| ROC AUC | 0,9947 |
| Alertas previstos | 1.593 |
| TP / FP / TN / FN | 1.327 / 266 / 553.308 / 818 |

O corte de 60% prioriza uma fila menor de alertas para revisão humana. A
acurácia isolada não deve ser usada como conclusão, pois a classe positiva
histórica é rara.

## Camada pública

`fraud_demo_public.v_fraud_predictions` publica exclusivamente os scores B1 V2
do split de teste. Ela possui 555.719 linhas, `decision_threshold=0.60`,
`model_risk_alert` calculado no mesmo corte e o handle do B1 V2.

## Uso na demo

- use `ML_PREDICT_ROW` para uma compra individual;
- use `ML_PREDICT_TABLE` para lotes e o fluxo ao vivo;
- comunique “alerta de risco previsto acima do threshold operacional de 60%”;
- nunca comunique fraude confirmada ou uma decisão automática sobre uma pessoa.
