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

## Reexecução local da tela — três DB Systems

Em 24/08/2026, a mesma aplicação foi iniciada localmente, um DB System por
vez, usando exclusivamente o usuário `febraban`. O teste acionou a rota da
interface para iniciar uma rodada real, acompanhou os checkpoints de
`ML_PREDICT_TABLE`, confirmou o carregamento da tela (`/` HTTP 200), a saúde
da API e conciliou os cards com SQL direto na view pública. Após a conclusão,
a pergunta “Quantos alertas foram gerados na simulação atual?” retornou por
`MySQL HeatWave · NL_SQL`, com `SELECT` auditável filtrado pelo `run_id` da
rodada e exatamente o mesmo total do card.

| DB System | Run ID validado | Inseridas / classificadas | Alertas `>= 0,60` | Valor conciliado | Falhas de lote / score |
| --- | --- | ---: | ---: | ---: | --- |
| `207.211.189.43` | `657df9fd-f7c5-4254-adad-b7373350865f` | 50.000 / 50.000 | 632 | US$ 6.768.455,03 | 0 / 0 |
| `207.211.177.73` | `88a6375e-4057-4f52-af46-d547f91f84a2` | 50.000 / 50.000 | 627 | US$ 6.739.176,92 | 0 / 0 |
| `164.152.31.115` | `f70111df-cc5c-4cb5-a5f4-f2ac85420fa9` | 50.000 / 50.000 | 661 | US$ 6.808.944,70 | 0 / 0 |

Uma primeira tentativa preliminar no banco primário registrou uma falha TLS
transitória de conexão e reexecutou o lote com sucesso. Ela não foi usada como
aceite: a rodada listada na tabela foi repetida integralmente e passou com zero
falhas. A aplicação também limpa `lastError` quando um retry de ingestão é
recuperado, evitando que a interface apresente um erro técnico antigo como se a
rodada concluída estivesse em falha.

## Decisão de nomenclatura

O laboratório passa a expor apenas nomes canônicos. Artefatos físicos antigos
de experimentos foram preservados somente como histórico/auditoria e não são
referenciados pela app, views públicas, configuração da VM ou documentação
operacional.
