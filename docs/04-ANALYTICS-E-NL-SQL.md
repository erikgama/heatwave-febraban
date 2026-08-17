---
layout: default
title: Analytics e NL to SQL
---

# 4. Cluster analítico e linguagem natural para SQL

Depois de carregar a tabela no cluster, consulte as views públicas:

```sql
SELECT category, transaction_count, labeled_fraud_count, labeled_fraud_pct
FROM fraud_demo_public.v_category_summary
ORDER BY labeled_fraud_count DESC LIMIT 10;
```

No dashboard, prefira agregações e chamadas paralelas. Em simulação ao vivo,
separe eventos por `run_id` e consulte somente a execução ativa.

## NL to SQL

`sys.NL_SQL` está disponível a partir de MySQL HeatWave 9.4.1 e gera somente
`SELECT`. Ainda assim, a saída do LLM não deve ser executada diretamente.

```sql
CALL sys.NL_SQL(
 'Qual categoria possui mais registros com rótulo histórico 1?', @generated_sql,
 JSON_OBJECT('execute',false,'schemas',JSON_ARRAY('fraud_demo_public'),
 'model_id','meta.llama-3.3-70b-instruct')
);
SELECT @generated_sql;
```

## Guardrails obrigatórios no backend

1. permitir apenas `SELECT` ou `WITH`;
2. bloquear DDL, DML, `CALL`, `LOAD`, `INTO OUTFILE`, comentários e `;`;
3. permitir apenas views de uma allowlist;
4. limitar a 100 linhas e aplicar timeout;
5. usar `app_readonly`, nunca admin;
6. exibir SQL validado e fonte da resposta.

O prompt de negócio deve esclarecer que label é histórico sintético, cidade e
estado descrevem cliente, e não existem produto, device, IP, moeda ou causa de
fraude.

| Pergunta | Rota |
| --- | --- |
| “Qual categoria tem mais rótulos?” | NL to SQL + views |
| “Qual é o threshold?” | RAG documental |
| “Quais features são usadas?” | RAG documental |
| “Simule compra de US$ 1.200 às 2h” | serviço de scoring |

Memória é apenas da sessão; dados trazem SQL e documentação traz citações.
