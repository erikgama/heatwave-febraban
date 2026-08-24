# QA do laboratório canônico - 24/08/2026

## Escopo e configuração validada

O QA foi executado como usuário `febraban` nos três DB Systems do laboratório.
O contrato ativo é:

- modelo: `fraud_risk_model`;
- camada de predição: `fraud_demo_public.v_fraud_predictions`;
- threshold operacional: `0,60`;
- Vector Store: `febraban_rag.fraud_risk_knowledge_base`;
- embedding GPU: `cohere.embed-v4.0`;
- geração GPU: `meta.llama-3.3-70b-instruct`.

## Resultado por banco

| DB System | Modelo carregado e predição | ML_PREDICT_TABLE | NL_SQL | ML_RAG | Memória |
| --- | --- | --- | --- | --- | --- |
| `207.211.189.43` | aprovado | 10 linhas aprovadas | aprovado | aprovado, threshold 60% | aprovado |
| `207.211.177.73` | aprovado | 10 linhas aprovadas | aprovado | aprovado, threshold 60% | aprovado |
| `164.152.31.115` | aprovado | 10 linhas aprovadas | aprovado | aprovado, threshold 60% | aprovado |

O smoke test de `ML_PREDICT_TABLE` cria duas tabelas temporárias controladas,
pontua dez linhas e as remove ao final. O fluxo recomendado para alto volume
continua sendo `ML_PREDICT_TABLE`; `ML_PREDICT_ROW` é apenas diagnóstico de um
payload isolado.

## QA ponta a ponta da aplicação na VM

Uma rodada real da interface foi executada no DB System principal:

- 50.000 eventos inseridos;
- 50.000 eventos classificados em lotes;
- 0 falhas de ingestão e 0 falhas de classificação;
- 558 alertas previstos no threshold de 60%;
- duração de ingestão e classificação: aproximadamente 42 segundos;
- valor movimentado conciliado: `6.784.159,41`;
- as perguntas sobre valor, quantidade, alertas, categoria, estabelecimento e
  cidade usaram NL_SQL e retornaram o mesmo resultado dos cards e gráficos.

A memória da sessão respondeu ao acompanhamento sem executar SQL adicional.
O RAG retornou citações e afirmou corretamente que score representa risco
previsto, não fraude confirmada.

## Decisão de nomenclatura

O laboratório passa a expor apenas nomes canônicos. Artefatos físicos antigos
de experimentos foram preservados somente como histórico/auditoria e não são
referenciados pela app, views públicas, configuração da VM ou documentação
operacional.
