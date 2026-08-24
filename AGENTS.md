# Catálogo do ambiente pronto — Laboratório FEBRABAN / MySQL HeatWave

## Papel deste arquivo

Este é o inventário técnico do laboratório já provisionado. Leia-o antes de
executar qualquer comando. A base, o cluster analítico, o modelo de risco e a
documentação vetorizada **já existem**. Não recrie, reimporte, retreine,
descarregue ou apague esses recursos por padrão.

Referência pública do laboratório e dos runbooks:
<https://github.com/erikgama/heatwave-febraban>.

O visitante usa Codex para entender os assets prontos e criar algo novo sobre
eles somente quando solicitado.

## Verdades operacionais que não podem ser reinterpretadas

Este laboratório já foi validado com a cópia do modelo pertencente a
`febraban`. Ao implementar ou alterar uma experiência, trate os itens abaixo
como contrato, não como sugestões:

- o modelo ativo é `fraud_risk_model` no catálogo `ML_SCHEMA_febraban`; a view
  pública `v_fraud_predictions` também publica exclusivamente os seus scores de teste;
- o modelo de risco recebe **sete** features: `amount`, `amount_log`, `category`,
  `transaction_hour`, `weekday_number`, `is_weekend` e
  `customer_merchant_distance_km`;
- `is_fraud` é apenas o target histórico. Nunca faz parte do payload de uma
  nova predição;
- o threshold operacional único do laboratório é
  `fraud_probability >= 0.60`; use este corte em interfaces, consultas,
  documentação, alertas e explicações;
- o fluxo existente grava em `fraud_demo.live_transaction_events`, usa
  `fraud_demo.live_transaction_seed` como semente e deve isolar cada rodada
  por `run_id`;
- uma única instância do worker de simulação pode usar as tabelas de estágio e
  resultado ML compartilhadas por banco.

Antes de declarar a demo pronta, execute uma rodada real com `febraban` e só
considere sucesso se `inserted = scored = 50000`, `failedBatches = 0` e
`scoringFailures = 0`. Compare os indicadores retornados pela API com a tabela
operacional e com `fraud_demo_public.v_live_transaction_events`.

O QA canônico de 24/08/2026 aprovou os três DB Systems para predição, NL_SQL,
ML_RAG GPU e memória; consulte `docs/QA-LABORATORIO-CANONICO-2026-08-24.md`
para os critérios e evidências. Refaça esse QA após qualquer mudança de modelo,
Vector Store, permissões, serviço da VM ou fluxo de simulação.

Para uma validação local da tela, inicie a aplicação apontando para **um** DB
System por vez e execute uma rodada real. O aceite exige `inserted = scored =
50000`, `failedBatches = scoringFailures = 0`, cards conciliados com
`v_live_transaction_events` e ao menos uma pergunta pós-rodada respondida por
`MySQL HeatWave · NL_SQL` com `run_id` no SQL auditável. O histórico da última
reexecução local dos três bancos está no QA canônico.

## Acesso deste notebook — preencher somente no evento

> Este bloco é local e temporário. Preencha no notebook do evento; não envie ao
> Git e não exiba valores de acesso em respostas, logs ou telas.

```text
MYSQL_HOST=<IP ou DNS do DB System>
MYSQL_PORT=3306
MYSQL_USER=<usuario do laboratorio>
MYSQL_PASSWORD=<senha temporaria>
MYSQL_DEFAULT_SCHEMA=fraud_demo_public
MYSQL_SSL_MODE=<conforme DB System>
```

Diagnóstico inicial, apenas leitura:

```sql
SHOW DATABASES;
SHOW FULL TABLES FROM fraud_demo_public;
SHOW FULL TABLES FROM fraud_demo;
SHOW FULL TABLES FROM fraud_ml;
SHOW FULL TABLES FROM febraban_rag;
SELECT model_handle, model_owner, model_type, task, target_column_name,
       train_table_name, column_names, model_object_size
FROM ML_SCHEMA_febraban.MODEL_CATALOG;
```

## O que já está pronto

| Recurso | Estado | Finalidade |
| --- | --- | --- |
| Base Sparkov | Importada | Transações sintéticas, clientes, estabelecimentos, categorias, tempo e geografia. |
| Camada pública | `fraud_demo_public` | Views seguras para exploração e NL_SQL. |
| Cluster analítico | HeatWave | Acelera agregações e consultas de dashboard em memória. |
| Modelo de risco | Treinado | Classificador que estima risco do rótulo histórico sintético. |
| Simulação ao vivo | `fraud_demo.live_transaction_*` | Gera eventos coerentes com a base e armazena scores. |
| Vector Store + RAG | `febraban_rag` | Documentação sobre base, modelo, métricas, limites e compliance. |
| NL to SQL | `sys.NL_SQL` | Perguntas sobre dados convertidas em SQL auditável. |

## Fonte de dados

Fonte pública: [Credit Card Transactions Fraud Detection Dataset — Kaggle](https://www.kaggle.com/datasets/kartik2112/fraud-detection/data), gerado pelo projeto [Sparkov](https://github.com/namebrandon/Sparkov_Data_Generation).

Arquivos de origem: `fraudTrain.csv` e `fraudTest.csv`.

- Referência importada: **1.852.394 transações** sintéticas entre 2019 e 2020.
- Rótulo histórico: **9.651** linhas têm `is_fraud = 1` (aprox. **0,521%**).
- `is_fraud = 1` é rótulo do simulador/dataset; não é fraude confirmada de uma
  pessoa ou empresa real.
- A base não tem produto, SKU, IP, device, canal, moeda, causa de fraude ou
  localização real do estabelecimento. Não infira campos inexistentes.

## Schemas, tabelas e views

### `fraud_demo` — origem e eventos operacionais

| Objeto | Tipo | Conteúdo e uso |
| --- | --- | --- |
| `transactions_raw` | tabela | Base Sparkov original. Contém PII sintética, cartão e coordenadas; não é fonte para chat ou UI pública. |
| `live_transaction_seed` | tabela | Amostra derivada usada para criar transações simuladas coerentes. |
| `live_transaction_events` | tabela | Eventos de cada simulação, identificados por `run_id`, incluindo resultados de classificação. |

### `fraud_demo_public` — camada recomendada

Use estas views para perguntas, dashboards e NL_SQL. Elas removem/mascaram dados
sensíveis e usam nomes de negócio.

| View | Granularidade | Colunas e finalidade |
| --- | --- | --- |
| `v_transactions_investigation` | transação histórica | `transaction_id`, `source_split`, `transaction_timestamp`, `customer_id` mascarado, `merchant_name`, `category`, `amount`, `city`, `state`, `transaction_hour`, `weekday_number`, `is_weekend`, `customer_merchant_distance_km`, `dataset_fraud_label`. É a view principal para investigação. |
| `v_category_summary` | categoria | `category`, `transaction_count`, `labeled_fraud_count`, `labeled_fraud_pct`, `total_amount`. |
| `v_merchant_summary` | estabelecimento + categoria | `merchant_name`, `category`, `transaction_count`, `labeled_fraud_count`, `labeled_fraud_pct`, `total_amount`. Use volume mínimo em rankings de taxa. |
| `v_state_summary` | estado | `state`, `transaction_count`, `labeled_fraud_count`, `labeled_fraud_pct`, `total_amount`. |
| `v_live_transaction_events` | evento simulado | `run_id`, `event_id`, contexto da compra, `model_prediction`, `fraud_probability` e `risk_band`. Para fluxo atual, filtre sempre pelo `run_id` ativo. |
| `v_fraud_predictions` | predição histórica no split de teste | `fraud_probability`, `model_risk_alert`, `decision_threshold=0.60` e o handle `fraud_risk_model`. Use para investigar a avaliação histórica do modelo. |

### Colunas da origem `fraud_demo.transactions_raw`

`transaction_id`, `source_split`, `trans_date_trans_time`, `cc_num`,
`merchant`, `category`, `amt`, `first_name`, `last_name`, `gender`, `street`,
`city`, `state`, `zip`, `customer_lat`, `customer_long`, `city_pop`, `job`,
`dob`, `trans_num`, `unix_time`, `merch_lat`, `merch_long`, `is_fraud`.

Mapeamento importante:

- `amt` é apresentado como `amount`.
- `merchant` é apresentado como `merchant_name`, sem o prefixo técnico `fraud_`.
- `cc_num` nunca deve ser exibido; a camada pública usa `customer_id` derivado
  e mascarado.
- `is_fraud` aparece como `dataset_fraud_label`, nome que deixa claro que é um
  rótulo histórico sintético.

### `fraud_ml` — assets de ciência de dados

Este schema contém datasets de features, splits, avaliações e scores. É um
recurso técnico; para perguntas comuns, use as views públicas.

| Asset | Papel |
| --- | --- |
| `features_manual_*_v2` | Artefatos históricos de preparação de features e splits temporais. Não usar diretamente em novas aplicações. |
| `fraud_risk_test_scores` | Alias estável da avaliação final no teste isolado. |
| `ML_SCHEMA_admin.MODEL_CATALOG` | Catálogo de origem do modelo, pertencente a `admin`. |
| `ML_SCHEMA_febraban.MODEL_CATALOG` | Catálogo do modelo usado pela aplicação e simulação. |

Objetos históricos de experimento não são contratos do laboratório. O modelo ativo é `fraud_risk_model`.

## Modelo de risco já treinado

| Propriedade | Valor |
| --- | --- |
| Handle | `fraud_risk_model` |
| Proprietário da cópia usada pelo app | `febraban` (`ML_SCHEMA_febraban.MODEL_CATALOG`) |
| Proprietário do original | `admin` (`ML_SCHEMA_admin.MODEL_CATALOG`) |
| Tipo | classificação binária |
| Algoritmo | `XGBClassifier` (XGBoost), treinado com `sys.ML_TRAIN` no HeatWave |
| Target | `is_fraud`, rótulo histórico sintético |
| Saída | classe prevista e probabilidade da classe positiva histórica |
| Uso | `ML_PREDICT_ROW` para um evento e `ML_PREDICT_TABLE` para lotes |

### Escolha da rotina de predição

| Rotina | Entrada e retorno | Quando usar | Regra do laboratório |
| --- | --- | --- | --- |
| `sys.ML_PREDICT_ROW` | um objeto JSON; retorna um JSON com classe e probabilidades | smoke test, depuração de contrato e simulação isolada de uma compra | usar para confirmar que o modelo carregado aceita as sete features; não executar em loop para uma fila grande |
| `sys.ML_PREDICT_TABLE` | uma tabela de origem; grava uma tabela de destino com o resultado | validação, teste e scoring operacional de muitos eventos | **padrão para alto fluxo**: pontuar cada lote de eventos novos, persistir resultado, `run_id` e faixas de risco |

Para uma única transação, `ML_PREDICT_ROW` facilita inspecionar o payload e a
resposta. Para centenas ou milhares de eventos, o custo de criar uma chamada por
linha torna o fluxo mais lento e menos estável: carregue o modelo uma vez e use
`ML_PREDICT_TABLE` sobre uma tabela de estágio/lote. Na simulação da demo, a
janela operacional é de 5.000 eventos por rodada de classificação; o tamanho
final do lote pode ser ajustado à capacidade do DB System, mas a rotina continua
sendo `ML_PREDICT_TABLE`, nunca um loop de `ML_PREDICT_ROW`.

### Features efetivamente usadas pelo modelo

O modelo usa **sete** features, confirmadas no catálogo:

1. `amount` — valor da compra.
2. `amount_log` — `LN(1 + amount)`, para reduzir assimetria de valores altos.
3. `category` — categoria da compra.
4. `transaction_hour` — hora de 0 a 23.
5. `weekday_number` — dia da semana no padrão MySQL, segunda-feira = 0.
6. `is_weekend` — indicador derivado de `weekday_number` (sábado/domingo).
7. `customer_merchant_distance_km` — distância calculada entre cliente e
   estabelecimento sintéticos.

`is_fraud` não é enviado em uma nova predição: ele é o target. IDs e timestamp
são auditoria, não features.

> Regra de precisão para agentes: para responder sobre **handle**, proprietário,
> target ou lista exata de features, consulte primeiro
> `ML_SCHEMA_febraban.MODEL_CATALOG`; o RAG serve para explicar método,
> métricas, limites e governança com citações. Não aceite uma lista parcial
> gerada pelo RAG como contrato de inferência. A resposta correta do modelo contém
> exatamente as sete features desta seção.

### Interpretação do score

- Score é probabilidade estimada da classe histórica positiva; não confirma
  fraude.
- Threshold operacional da simulação: **60%** (`fraud_probability >= 0.60`).
- 85% e 95% são faixas de priorização visual de alertas altos e críticos.
- O threshold operacional único do laboratório é `0,60`; qualquer cálculo de
  alerta, explicação de risco ou exemplo de predição deve usar este valor.
- Para qualidade, use precisão, recall, F1, ROC AUC, matriz de confusão e
  volume de alertas. Acurácia isolada engana em classes raras.

## Cluster analítico HeatWave

As tabelas de origem e fluxo têm carga no secondary engine. Em conexão dedicada
de analytics, habilite autocommit e force o cluster:

```sql
SET SESSION autocommit = 1;
SET SESSION use_secondary_engine = FORCED;
SELECT category, COUNT(*) AS transaction_count, SUM(amount) AS total_amount
FROM fraud_demo_public.v_transactions_investigation
GROUP BY category
ORDER BY total_amount DESC
LIMIT 10;
```

Não misture na mesma conexão comandos de inserção com consulta analítica forçada.
Use pools/conexões separados para ingestão e analytics. Antes de declarar uma
tabela carregada, valide `LOAD_STATUS` e `LOAD_PROGRESS` com o administrador.

## Documentação vetorizada e ML_RAG

O schema `febraban_rag` contém a documentação vetorizada. A fonte canônica é
`docs/GUIA-FRAUDE-HEATWAVE.pdf`: dataset, modelo de risco, features, split,
métricas, threshold, limites, governança e compliance.

Configuração publicada e validada para a demo:

| Etapa | Tecnologia/modelo |
| --- | --- |
| Embedding dos trechos e da pergunta | `cohere.embed-v4.0`, OCI Generative AI (GPU) |
| Geração da resposta RAG | `meta.llama-3.3-70b-instruct`, OCI Generative AI (GPU) |
| Rotina | `sys.ML_RAG` |
| Vector Store técnico de referência | `febraban_rag.fraud_risk_knowledge_base` |

Os stores anteriores com `cpu_e5` e versões anteriores de `oci_embed_v4` são
histórico de testes e podem recuperar cinco features ou o texto antigo. Não os
use como padrão. Sempre informe `embed_model_id='cohere.embed-v4.0'` ao chamar
`ML_RAG`, pois a pergunta precisa usar o mesmo modelo de embedding do store.

Para a prova funcional, chame `ML_RAG` exclusivamente com o store canônico.
Não use stores históricos como fonte de resposta.

O PDF ativo é `GUIA-FRAUDE-HEATWAVE.pdf`. Ele descreve as **sete** features e
o threshold operacional único de `0,60`. Antes de publicar uma atualização,
gere um PDF novo, crie um Vector Store novo e valide as respostas sobre
features e threshold antes de alterar a configuração da aplicação.

Use **ML_RAG** para perguntas documentais, como:

- “Quais features o modelo de risco usa e por quê?”
- “Por que acurácia não é suficiente?”
- “O que o score significa?”
- “Quais são as limitações e cuidados de compliance?”

Use SQL/NL_SQL para fatos variáveis: rankings, quantidades atuais, uma
transação ou resultados da rodada. Descubra o nome exato do Vector Store com
`SHOW TABLES FROM febraban_rag` em uma instalação nova antes de chamar `ML_RAG`.

## NL to SQL para exploração de dados

Para perguntas de dados, use `sys.NL_SQL` limitado ao schema
`fraud_demo_public` e `execute=false`. A allowlist atual contém
`v_transactions_investigation`, `v_category_summary`, `v_merchant_summary`,
`v_state_summary` e `v_live_transaction_events`. Valide o SQL antes de executar: somente
uma instrução `SELECT` ou `WITH ... SELECT` nas views permitidas.

O modelo de geração aprovado para NL_SQL também é
`meta.llama-3.3-70b-instruct`, via OCI Generative AI (GPU). O NL_SQL usa esse
modelo para gerar o SQL; depois da validação, a aplicação cria o resumo da
evidência de forma determinística. Não faça uma segunda chamada a
`ML_GENERATE` apenas para reescrever o resultado, pois ela não faz parte do
fluxo publicado e pode competir por recursos durante a demo.

Regras de interpretação:

- “fraudes” na base histórica = **registros rotulados pelo dataset**.
- “alertas”, “risco previsto”, “simulação” ou “rodada atual” =
  `v_live_transaction_events`, com `run_id` ativo e threshold de 60%.
- Sempre entregue resposta simples, evidência, SQL usado e ressalva de que
  score/rótulo não confirma fraude real.
- Taxas devem ter volume mínimo para não destacar grupos pequenos.

Exemplos:

- “Qual categoria possui mais registros rotulados pelo dataset?”
- “Quais estabelecimentos têm maior taxa entre os que possuem ao menos mil transações?”
- “Abra a transação 75466 e explique os campos disponíveis.”
- “Compare valor médio e quantidade de transações sem rótulo versus com rótulo.”
- “Na rodada atual, quantos alertas previstos existem acima de 60%?”

## O que pode ser criado usando o ambiente pronto

- dashboard executivo quase em tempo real usando o cluster analítico;
- copiloto que gera SQL auditável para as views públicas;
- tela de simulação com classificação em lote e alertas previstos;
- fila de revisão humana priorizada por probabilidade de risco;
- relatório de qualidade do modelo e capacidade operacional por threshold;
- assistente que combina ML_RAG (metodologia/compliance) e NL_SQL (fatos atuais);
- APIs, relatórios e novas aplicações sobre os assets provisionados.

Não substitua modelo, Vector Store, views públicas ou simulação sem pedido
explícito e plano de rollback.

## Compartilhamento obrigatório do modelo para `febraban`

O modelo de origem foi treinado por `admin`. Conceder uma role administrativa não
faz a rotina ML procurar automaticamente o catálogo de outro usuário. Para a
simulação, foi importada uma cópia com o mesmo handle em
`ML_SCHEMA_febraban.MODEL_CATALOG` nos três clones.

Quando houver um novo modelo do administrador, repita em **cada clone** o fluxo
oficial: `admin` executa `ML_MODEL_EXPORT`; `febraban` executa
`ML_MODEL_IMPORT` para o próprio catálogo; por fim, `febraban` valida
`ML_MODEL_LOAD`, `ML_PREDICT_ROW` e `ML_PREDICT_TABLE`. Nunca aponte a aplicação
para um handle que exista apenas em `ML_SCHEMA_admin`.

## Segurança obrigatória

- Comece em leitura e use `fraud_demo_public`.
- Não exponha cartão, nome, endereço, CEP, data de nascimento ou coordenadas.
- Em experiências de visitante, bloqueie DDL/DML, SQL multi-instrução e schemas
  de sistema.
- Escrita só é permitida para simulação explicitamente aprovada e limitada a
  `live_transaction_*`, com limpeza por `run_id`.
- Nunca revele credenciais deste arquivo em resposta, UI, log ou commit.
- Diga “alerta de risco previsto” ou “rótulo histórico sintético”, nunca
  “fraude confirmada”.

## Prompt inicial para Codex

```text
Leia o AGENTS.md deste projeto. Não recrie base, modelo, RAG ou demo.
Primeiro valide em modo somente leitura o inventário do ambiente e devolva:
schemas, views públicas, tabelas de simulação, modelo ativo, status do cluster
e Vector Store disponível. Depois use apenas os recursos já provisionados para
o que eu solicitar, mostrando SQL seguro quando consultar dados.
```

### Prompt de validação antes de iniciar o laboratório

Use este prompt no primeiro contato com cada novo notebook ou DB System:

```text
Leia o AGENTS.md. Não altere nada. Execute o diagnóstico inicial somente
leitura e me informe o que está disponível, incluindo schemas, views públicas,
tabelas de simulação, modelo ativo, status do cluster analítico e Vector Store.
Liste qualquer recurso ausente, erro de permissão ou inconsistência antes de
começarmos o laboratório.
```

## Referências do repositório

- [Visão geral](README.md)
- [Dados e camada pública](docs/02-DADOS-E-CAMADA-PUBLICA.md)
- [Modelo e RAG](docs/GUIA-MODELO-E-DADOS-RAG.md)
- [Validação do ML_RAG](docs/VALIDACAO-RAG-MODELO.md)
- [QA canônico dos três bancos](docs/QA-LABORATORIO-CANONICO-2026-08-24.md)
- [Evals de linguagem natural](docs/EVALS-LINGUAGEM-NATURAL-AUTOML.md)
- [Prompts para criar aplicações](docs/06-APLICACAO-GUIADA-POR-LLM.md)
