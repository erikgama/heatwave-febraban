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

## Comece aqui

Siga esta ordem. Cada etapa tem duas formas de leitura: **site** para uma
experiência navegável e **Markdown** para consultar, versionar ou entregar como
contexto a um LLM.

1. Crie o DB System e adicione o cluster HeatWave.
2. Baixe o Sparkov no Kaggle, importe `train` e `test` e publique as views
   seguras.
3. Consolide as features, separe temporalmente os dados, treine o XGBoost,
   avalie e carregue o modelo.
4. Crie as análises do cluster e aplique NL to SQL com guardrails.
5. Exporte o documento do modelo como PDF, envie ao Object Storage e crie o
   Vector Store para `ML_RAG`.
6. Use a especificação para pedir a um LLM que construa e publique sua própria
   aplicação.

## Trilha detalhada

| Etapa | Leitura guiada | Fonte Markdown | Resultado |
| --- | --- | --- | --- |
| 0 | [Visão geral](https://erikgama.github.io/heatwave-febraban/00-VISAO-GERAL.html) | [00-VISAO-GERAL.md](docs/00-VISAO-GERAL.md) | arquitetura e checklist |
| 1 | [DB System e cluster](https://erikgama.github.io/heatwave-febraban/01-DBSYSTEM-E-CLUSTER.html) | [01-DBSYSTEM-E-CLUSTER.md](docs/01-DBSYSTEM-E-CLUSTER.md) | HeatWave disponível |
| 2 | [Dados e camada pública](https://erikgama.github.io/heatwave-febraban/02-DADOS-E-CAMADA-PUBLICA.html) | [02-DADOS-E-CAMADA-PUBLICA.md](docs/02-DADOS-E-CAMADA-PUBLICA.md) | Sparkov importado |
| 3 | [Modelo e predições](https://erikgama.github.io/heatwave-febraban/03-MODELO-E-PREDICOES.html) | [03-MODELO-E-PREDICOES.md](docs/03-MODELO-E-PREDICOES.md) | XGBoost treinado e avaliado |
| 4 | [Analytics e NL to SQL](https://erikgama.github.io/heatwave-febraban/04-ANALYTICS-E-NL-SQL.html) | [04-ANALYTICS-E-NL-SQL.md](docs/04-ANALYTICS-E-NL-SQL.md) | consultas e chat de dados |
| 5 | [RAG documental](https://erikgama.github.io/heatwave-febraban/05-RAG-DOCUMENTAL.html) | [05-RAG-DOCUMENTAL.md](docs/05-RAG-DOCUMENTAL.md) | documento vetorizado |
| 6 | [Aplicação guiada por LLM](https://erikgama.github.io/heatwave-febraban/06-APLICACAO-GUIADA-POR-LLM.html) | [06-APLICACAO-GUIADA-POR-LLM.md](docs/06-APLICACAO-GUIADA-POR-LLM.md) | aplicação no seu ambiente |

## Dados usados

Fonte pública: [Credit Card Transactions Fraud Detection Dataset — Kaggle](https://www.kaggle.com/datasets/kartik2112/fraud-detection/data).
Baixe `fraudTrain.csv` e `fraudTest.csv` diretamente no Kaggle. A origem foi
gerada pelo [Sparkov](https://github.com/namebrandon/Sparkov_Data_Generation).

## Documento para vetorização

Use [Documento do modelo para RAG](https://erikgama.github.io/heatwave-febraban/DOCUMENTO-MODELO-PARA-RAG.html)
ou sua [fonte Markdown](docs/DOCUMENTO-MODELO-PARA-RAG.md) como conteúdo
canônico. Exporte-o para PDF, envie-o ao Object Storage e siga a etapa 5.

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
