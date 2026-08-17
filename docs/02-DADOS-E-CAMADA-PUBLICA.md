# 2. Dados, importação e camada pública

Baixe `fraudTrain.csv` e `fraudTest.csv` no
[Kaggle](https://www.kaggle.com/datasets/kartik2112/fraud-detection/data). São
dados sintéticos Sparkov; não há produto, SKU, IP, device, moeda, canal ou
localização de merchant.

## Tabela de origem

```sql
CREATE TABLE fraud_demo.transactions_raw (
  transaction_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  source_split ENUM('train','test') NOT NULL,
  trans_date_trans_time DATETIME NOT NULL, cc_num VARCHAR(32) NOT NULL,
  merchant VARCHAR(255) NOT NULL, category VARCHAR(64) NOT NULL,
  amt DECIMAL(14,2) NOT NULL, first_name VARCHAR(128), last_name VARCHAR(128),
  gender CHAR(1), street VARCHAR(255), city VARCHAR(128) NOT NULL,
  state CHAR(2) NOT NULL, zip VARCHAR(16), customer_lat DECIMAL(10,7) NOT NULL,
  customer_long DECIMAL(10,7) NOT NULL, city_pop INT, job VARCHAR(255), dob DATE,
  trans_num VARCHAR(64), unix_time BIGINT, merch_lat DECIMAL(10,7) NOT NULL,
  merch_long DECIMAL(10,7) NOT NULL, is_fraud TINYINT UNSIGNED NOT NULL,
  PRIMARY KEY (transaction_id),
  KEY ix_split_time (source_split, trans_date_trans_time),
  KEY ix_card_time (cc_num, trans_date_trans_time)
) ENGINE=InnoDB;
```

## Importação CSV

Use o assistente CSV do MySQL Shell for VS Code ou ferramenta equivalente. Para
`fraudTrain.csv`, inclua a constante `source_split='train'`; para
`fraudTest.csv`, `source_split='test'`. Ignore a coluna de índice inicial do
CSV e mapeie `lat` para `customer_lat`, `long` para `customer_long`, `first`
para `first_name` e `last` para `last_name`. Deixe `transaction_id` automático.

```sql
SELECT source_split, COUNT(*) AS transacoes, SUM(is_fraud) AS rotulos_1,
       MIN(trans_date_trans_time) AS inicio, MAX(trans_date_trans_time) AS fim
FROM fraud_demo.transactions_raw GROUP BY source_split;
```

Como referência, os dois arquivos somam 1.852.394 transações e 9.651 rótulos
`is_fraud=1`. Investigue diferença antes de treinar.

## View pública

Não exponha a tabela bruta. A view abaixo mascara o cartão e omite PII e
coordenadas:

```sql
CREATE OR REPLACE VIEW fraud_demo_public.v_transactions_investigation AS
SELECT transaction_id, source_split, trans_date_trans_time AS transaction_timestamp,
 CONCAT('C-',UPPER(SUBSTRING(SHA2(cc_num,256),1,10))) AS customer_id,
 REGEXP_REPLACE(merchant,'^fraud_','') AS merchant_name, category, amt AS amount,
 city, state, HOUR(trans_date_trans_time) AS transaction_hour,
 WEEKDAY(trans_date_trans_time) AS weekday_number,
 CASE WHEN WEEKDAY(trans_date_trans_time) IN (5,6) THEN 1 ELSE 0 END AS is_weekend,
 6371*2*ASIN(SQRT(POWER(SIN(RADIANS(merch_lat-customer_lat)/2),2)
 +COS(RADIANS(customer_lat))*COS(RADIANS(merch_lat))*POWER(SIN(RADIANS(merch_long-customer_long)/2),2))) AS customer_merchant_distance_km,
 is_fraud AS dataset_fraud_label
FROM fraud_demo.transactions_raw;
```

Crie views-resumo por categoria, merchant, estado, hora, cliente e dia com as
colunas: dimensão, `transaction_count`, `labeled_fraud_count`,
`labeled_fraud_pct` e `total_amount`. A camada pública melhora a segurança,
reduz custo e melhora o NL to SQL.

`dataset_fraud_label=1` é rótulo histórico sintético, não fraude confirmada.
