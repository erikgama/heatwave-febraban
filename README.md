# Laboratório FEBRABAN: MySQL HeatWave + IA para investigação de risco

Este é um laboratório **guiado por documentação**. Não contém aplicação pronta,
credenciais, dados privados ou artefatos do ambiente do evento. A proposta é que
você use um LLM/Codex como parceiro de implementação e reproduza cada etapa no
seu próprio MySQL HeatWave.

Revisão documental: agosto de 2026.

O resultado esperado é uma experiência com dados sintéticos, analytics no
cluster HeatWave, modelo de risco, predições, RAG documental, NL to SQL e uma
aplicação web construída no seu próprio ambiente.

> Sparkov é sintético. `is_fraud = 1` é um rótulo histórico do simulador. Um
> score é alerta de risco para investigação, nunca confirmação de fraude.

## Trilha do laboratório

| Etapa | Documento | Resultado |
| --- | --- | --- |
| 0 | [Visão geral e pré-requisitos](docs/00-VISAO-GERAL.md) | arquitetura e checklist |
| 1 | [DB System e cluster](docs/01-DBSYSTEM-E-CLUSTER.md) | HeatWave disponível |
| 2 | [Dados e camada pública](docs/02-DADOS-E-CAMADA-PUBLICA.md) | Sparkov importado |
| 3 | [Modelo e predições](docs/03-MODELO-E-PREDICOES.md) | XGBoost treinado e avaliado |
| 4 | [Analytics e NL to SQL](docs/04-ANALYTICS-E-NL-SQL.md) | consultas e chat de dados |
| 5 | [RAG documental](docs/05-RAG-DOCUMENTAL.md) | documento vetorizado |
| 6 | [Aplicação guiada por LLM](docs/06-APLICACAO-GUIADA-POR-LLM.md) | aplicação no seu ambiente |

## Dados usados

Fonte pública: [Credit Card Transactions Fraud Detection Dataset — Kaggle](https://www.kaggle.com/datasets/kartik2112/fraud-detection/data).
Baixe `fraudTrain.csv` e `fraudTest.csv` diretamente no Kaggle. A origem foi
gerada pelo [Sparkov](https://github.com/namebrandon/Sparkov_Data_Generation).

## Documento para vetorização

Use [Documento do modelo para RAG](docs/DOCUMENTO-MODELO-PARA-RAG.md) como fonte
canônica. Exporte-o para PDF, envie-o ao Object Storage e siga a etapa 5.

## O que este repositório deliberadamente não contém

- código da aplicação web do evento;
- senhas, tokens, chaves ou endpoints privados;
- CSVs do Kaggle;
- modelo exportado ou decisão automatizada.

## Referências oficiais

- [MySQL HeatWave User Guide](https://dev.mysql.com/doc/heatwave/en/)
- [Criar um DB System](https://dev.mysql.com/doc/heatwave/en/mys-hw-create-db-system.html)
- [Rotinas AutoML](https://dev.mysql.com/doc/heatwave/en/hw-routines.html)
- [NL to SQL](https://dev.mysql.com/doc/heatwave/en/mys-hw-genai-nl-sql.html)
- [Vector Store](https://dev.mysql.com/doc/heatwave/en/mys-hw-genai-vector-store-load.html)
