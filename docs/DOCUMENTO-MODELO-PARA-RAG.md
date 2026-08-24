---
layout: default
title: Documento do modelo para RAG
---

# Documento do modelo: laboratório de investigação de risco

> Revisão de contrato: 23/08/2026. Esta versão substitui definições anteriores
> que descreviam cinco features ou um único threshold operacional.

## Finalidade

Esta é a fonte canônica de RAG. Ela explica base, modelo, métricas, threshold,
limites e governança. Fatos e rankings atuais devem vir de SQL nas views públicas.

## Dataset

O laboratório usa o **Credit Card Transactions Fraud Detection Dataset** do
Kaggle, gerado pelo Sparkov. Há `fraudTrain.csv` e `fraudTest.csv`. A referência
tem 1.852.394 transações sintéticas entre 2019 e 2020; 9.651 têm `is_fraud=1`,
aproximadamente 0,521%.

Há transação, cliente sintético, merchant sintético, categoria, valor, data/hora
e geografia sintética. Não há produto, SKU, IP, device, canal, moeda, causa de
fraude ou localização do merchant. `is_fraud=1` não comprova fraude real.

## Modelo B1

O B1 é um classificador binário `XGBClassifier` treinado no MySQL HeatWave com
`sys.ML_TRAIN`. Ele estima a probabilidade da classe histórica `is_fraud=1` para
priorizar revisão humana.

As sete features confirmadas em `ML_SCHEMA_febraban.MODEL_CATALOG` são:
`amount`, `amount_log=LN(1+amount)`, `category`, `transaction_hour`,
`weekday_number`, `is_weekend` e `customer_merchant_distance_km`.
`amount_log=LN(1+amount)`. `is_fraud` não é enviado para uma nova predição,
pois é o target. ID e timestamp são auditoria e não entram como features B1.

## Separação e métricas

O split `test` fica isolado até o fim. Dentro de `train`, a parte anterior no
tempo é desenvolvimento e a posterior é validação. O threshold é escolhido na
validação e avaliado uma vez no teste final.

Use precisão, recall, F1, ROC AUC, volume de alertas e matriz de confusão.
Acurácia isolada não basta porque a classe positiva é muito rara; prever sempre
a classe majoritária pode dar acurácia alta e ser inútil para investigar risco.

O threshold de **0,27** é uma referência do experimento de validação B1. Ele
não é universal. A operação atual da simulação utiliza o threshold de **0,60**
para abrir um alerta previsto; faixas de 0,85 e 0,95 priorizam alertas altos e
críticos. A view histórica `v_fraud_predictions` usa outro modelo (V1) e traz
o threshold próprio de 0,33; ela não é a evidência de produção do B1 V2.

## Comunicação do score

Na simulação, se `fraud_probability >= 0,60`, diga “alerta de risco previsto
acima do threshold operacional”. Não diga “fraude confirmada”. As faixas de
0,85 e 0,95 podem priorizar visualmente a revisão.

## HeatWave, SQL e RAG

O HeatWave armazena dados, acelera agregações, treina e carrega o modelo, pontua
eventos e hospeda Vector Store. Um modelo é carregado por `ML_MODEL_LOAD` antes
de `ML_PREDICT_ROW` ou `ML_PREDICT_TABLE` e permanece ativo até unload ou restart.

O original B1 pertence a `admin`, mas a aplicação conecta como `febraban`.
Por isso, o B1 foi compartilhado oficialmente com `ML_MODEL_EXPORT` pelo
proprietário e `ML_MODEL_IMPORT` para `ML_SCHEMA_febraban`. A aplicação deve
usar a cópia pertencente a `febraban`, nunca tentar carregar apenas o handle do
catálogo de `admin`.

Perguntas de dados usam `NL_SQL` com SQL validado; perguntas deste documento
usam `ML_RAG` e citações. O visitante usa views públicas somente leitura, o
backend bloqueia DDL/DML, SQL multi-instrução e relações fora da allowlist, e a
memória do chat dura apenas a sessão.

## Publicação vetorial aprovada para a demo

Esta fonte foi revisada e publicada como
`GUIA-MODELO-E-DADOS-B1-V2-RAG-REV2-20260823.pdf`. O Vector Store ativo é
`febraban_rag.modelo_b1_v2_oci_embed_v4_rev2_20260823`, carregado com
`cohere.embed-v4.0` no OCI Generative AI (GPU). As respostas usam
`meta.llama-3.3-70b-instruct` e devem informar citações. O embedding da
consulta precisa ser o mesmo da carga: `cohere.embed-v4.0`.

## Governança

O laboratório é educacional e demonstrativo. Produção exige validação de dados
reais, aprovação de negócio, segurança, privacidade, monitoramento, avaliação
de vieses, gestão de drift, contestação e revisão humana.
