# Documento do modelo: laboratório de investigação de risco

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

As cinco features são: `amount`, `amount_log=LN(1+amount)`, `category`,
`transaction_hour` e `customer_merchant_distance_km`. `is_fraud` não é enviado
para uma nova predição, pois é o target. ID e timestamp são auditoria e não
entram como features B1.

## Separação e métricas

O split `test` fica isolado até o fim. Dentro de `train`, a parte anterior no
tempo é desenvolvimento e a posterior é validação. O threshold é escolhido na
validação e avaliado uma vez no teste final.

Use precisão, recall, F1, ROC AUC, volume de alertas e matriz de confusão.
Acurácia isolada não basta porque a classe positiva é muito rara; prever sempre
a classe majoritária pode dar acurácia alta e ser inútil para investigar risco.

O threshold de referência é **0,27**. Ele não é universal: cada operação deve
considerar capacidade de análise, custo de falsos positivos, risco de falsos
negativos e validação local.

## Comunicação do score

Se `fraud_probability >= 0,27`, diga “alerta de risco previsto acima do
threshold operacional”. Não diga “fraude confirmada”. Faixas de 50% e 85% podem
priorizar visualmente, mas a regra de operação é o threshold validado.

## HeatWave, SQL e RAG

O HeatWave armazena dados, acelera agregações, treina e carrega o modelo, pontua
eventos e hospeda Vector Store. Um modelo é carregado por `ML_MODEL_LOAD` antes
de `ML_PREDICT_ROW` ou `ML_PREDICT_TABLE` e permanece ativo até unload ou restart.

Perguntas de dados usam `NL_SQL` com SQL validado; perguntas deste documento
usam `ML_RAG` e citações. O visitante usa views públicas somente leitura, o
backend bloqueia DDL/DML, SQL multi-instrução e relações fora da allowlist, e a
memória do chat dura apenas a sessão.

## Governança

O laboratório é educacional e demonstrativo. Produção exige validação de dados
reais, aprovação de negócio, segurança, privacidade, monitoramento, avaliação
de vieses, gestão de drift, contestação e revisão humana.
