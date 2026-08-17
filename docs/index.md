---
layout: default
title: Laboratório FEBRABAN com MySQL HeatWave
---

# Laboratório FEBRABAN: MySQL HeatWave + IA

Trilha guiada para criar um laboratório de investigação de risco usando dados
sintéticos Sparkov, analytics, Machine Learning, RAG e NL to SQL.

> `is_fraud=1` é rótulo histórico sintético. Score é alerta de risco, não fraude
> confirmada.

1. [Visão geral e pré-requisitos](00-VISAO-GERAL.html)
2. [Criar DB System e cluster analítico](01-DBSYSTEM-E-CLUSTER.html)
3. [Importar dados e publicar a camada segura](02-DADOS-E-CAMADA-PUBLICA.html)
4. [Consolidar features, treinar e predizer](03-MODELO-E-PREDICOES.html)
5. [Analytics no cluster e NL to SQL](04-ANALYTICS-E-NL-SQL.html)
6. [Vetorizar a documentação e usar ML_RAG](05-RAG-DOCUMENTAL.html)
7. [Construir a aplicação com apoio de um LLM](06-APLICACAO-GUIADA-POR-LLM.html)
8. [Contrato de execução para Codex e outros LLMs](07-CONTRATO-DE-EXECUCAO-PARA-LLM.html)

Para RAG, use [Documento do modelo](DOCUMENTO-MODELO-PARA-RAG.html), exporte
para PDF e carregue-o no Object Storage.

[Dataset no Kaggle](https://www.kaggle.com/datasets/kartik2112/fraud-detection/data)
