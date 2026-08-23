---
layout: default
title: DB System e cluster analítico
---

# 1. Criar o DB System e o cluster analítico

No Console OCI, abra **MySQL HeatWave > DB Systems > Create DB System**. Escolha
VCN e subnet com rota para seu computador ou bastion e guarde a senha
administrativa em um vault. Crie ou adicione um **HeatWave Cluster** ao DB
System; dimensione-o para tabela de origem, features, tabelas de score, Vector
Store e modelo carregado. As telas e shapes variam por região e versão: valide
na referência oficial de [criação do DB System](https://dev.mysql.com/doc/heatwave/en/mys-hw-create-db-system.html).

Conecte-se sempre com TLS:

```bash
mysqlsh --sql admin@SEU_HOST:3306 --ssl-mode=REQUIRED
```

Valide versão e nós do cluster:

```sql
SELECT VERSION();
SELECT * FROM performance_schema.rpd_nodes;
```

Crie os schemas e a identidade visitante:

```sql
CREATE SCHEMA IF NOT EXISTS fraud_demo;
CREATE SCHEMA IF NOT EXISTS fraud_demo_public;
CREATE SCHEMA IF NOT EXISTS fraud_ml;
CREATE SCHEMA IF NOT EXISTS febraban_rag;

CREATE USER IF NOT EXISTS 'app_readonly'@'%' IDENTIFIED BY 'USE_UM_SECRET_DO_VAULT';
GRANT SELECT, SHOW VIEW ON fraud_demo_public.* TO 'app_readonly'@'%';
SHOW GRANTS FOR 'app_readonly'@'%';
```

Após importar a tabela na etapa 2, carregue-a no cluster:

```sql
ALTER TABLE fraud_demo.transactions_raw SECONDARY_LOAD;
SELECT i.SCHEMA_NAME, i.TABLE_NAME, t.NROWS, t.LOAD_STATUS, t.LOAD_PROGRESS
FROM performance_schema.rpd_table_id i
JOIN performance_schema.rpd_tables t ON t.ID=i.ID
WHERE i.SCHEMA_NAME='fraud_demo' AND i.TABLE_NAME='transactions_raw';
```

Espere a carga terminar. Use `EXPLAIN` e a observabilidade do HeatWave para
comprovar aceleração, e não apenas o fato de a consulta ser um `SELECT`.
