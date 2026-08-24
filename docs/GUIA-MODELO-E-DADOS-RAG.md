# Guia do modelo de risco e RAG

## Contrato do laboratório

- Fonte: [Credit Card Transactions Fraud Detection - Kaggle](https://www.kaggle.com/datasets/kartik2112/fraud-detection/data), dados sintéticos Sparkov.
- Universo: 1.852.394 transações; 9.651 rótulos históricos positivos (0,521%).
- Modelo: `fraud_risk_model`, proprietário `febraban` em `ML_SCHEMA_febraban.MODEL_CATALOG`.
- Algoritmo: `XGBClassifier` de classificação binária; target histórico `is_fraud`.
- Threshold operacional único: `fraud_probability >= 0.60`.

## Features de inferência

O payload possui exatamente sete features: `amount`, `amount_log`, `category`,
`transaction_hour`, `weekday_number`, `is_weekend` e
`customer_merchant_distance_km`. Calcule `amount_log` com `LN(1 + amount)`.
Não envie `is_fraud`, IDs ou timestamps: o primeiro é o target e os demais são
de auditoria.

## Predição

Use `ML_PREDICT_ROW` para uma inspeção pontual. Para lotes e para a simulação
da demo, o padrão é `ML_PREDICT_TABLE`, que persiste o resultado e evita uma
chamada por linha. O modelo deve estar carregado antes da inferência.

## RAG GPU

- PDF canônico: `GUIA-FRAUDE-HEATWAVE.pdf`, no Object Storage em
  `oci://demo@idi1o0a010nx/febraban/GUIA-FRAUDE-HEATWAVE.pdf`.
- Vector Store: `febraban_rag.fraud_risk_knowledge_base`.
- Embedding: `cohere.embed-v4.0` no OCI Generative AI (GPU).
- Geração: `meta.llama-3.3-70b-instruct` no OCI Generative AI (GPU).

Use `ML_RAG` para método, métricas, limitações, compliance e significado do
score. Use SQL/NL_SQL nas views públicas para fatos atuais. Score e alerta
representam risco previsto; não confirmam fraude.
