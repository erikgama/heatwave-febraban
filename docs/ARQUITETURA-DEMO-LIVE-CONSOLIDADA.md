# Arquitetura consolidada — demonstração live com HeatWave e ML

## Decisão de arquitetura

Para a demo usar **um único cluster HeatWave** de forma confiável, o dashboard
usa agregados operacionais durante cada checkpoint de ML e volta ao cluster
analítico para consolidar os gráficos entre checkpoints e ao final da rodada.

Essa decisão vem de teste real no ambiente 9.7.2-cloud: enquanto
`ML_PREDICT_TABLE` executa, o cluster pode ficar temporariamente indisponível
para consultas analíticas client-side com `use_secondary_engine=FORCED`.
Não é lock de linha, nem erro de modelagem SQL; é contenção de capacidade no
mesmo recurso de compute.

```text
Fase 1 — Ingestão + indicadores ao vivo (~30 s)
  50.000 eventos plausíveis entram em blocos de 500 a cada ~300 ms
  cards, incrementos verdes e rankings incrementais atualizam pela camada operacional

Fase 2 — Classificação progressiva de risco
  a cada 5.000 eventos confirmados: ML_PREDICT_TABLE
  barra, alertas e tabela de resultados são lidos da camada operacional
  gráficos FORCED conservam a última fotografia durante a execução ML

Fase 3 — Resultado consolidado
  refresh analítico no HeatWave
  alertas previstos, probabilidades e distribuições por risco disponíveis
```

O visitante vê uma jornada clara: **novas transações → análise do negócio →
classificação de risco → resultado investigável**. Não há congelamento ou
afirmação enganosa de que dois workloads concorrentes usam capacidade infinita.

## O que fica proibido no fluxo V1 da demo

- Não executar polling analítico `FORCED` enquanto o `ML_PREDICT_TABLE` estiver
  em curso; conservar a última fotografia e usar o snapshot operacional.
- Não fazer `TRUNCATE` na tabela de estágio entre checkpoints; ele pode exigir
  novo carregamento no HeatWave. Usar `DELETE` e change propagation.
- Não executar múltiplos polls simultâneos: uma nova consulta só começa quando
  a anterior terminou.
- Não depender de estado de execução exclusivamente em memória do Node.

## Componentes persistentes

| Componente | Finalidade |
|---|---|
| `fraud_demo.live_transaction_seed` | padrões sem rótulo usados para gerar eventos plausíveis |
| `fraud_demo.live_transaction_events` | 50 mil eventos da execução, score e probabilidade persistidos |
| `fraud_ml.live_scoring_stage` | entrada de 5 mil features para o modelo; carregada uma vez no HeatWave |
| `fraud_ml.live_scoring_result` | saída temporária da última chamada ML |
| `fraud_demo.live_demo_runs` | controle durável de status, contadores, timestamps e erros |

`live_demo_runs` deve conter, no mínimo: `run_id`, `status`, `target_events`,
`inserted_events`, `scored_events`, `predicted_alerts`, `started_at`,
`ingestion_finished_at`, `scoring_finished_at` e `last_error`.

Estados permitidos:

`READY → INGESTING → SCORING → COMPLETED`

`FAILED` é terminal e apresenta diagnóstico. `RESET` remove apenas dados da
execução corrente e retorna a `READY`.

## Responsabilidade por fase

### 1. Ingestão

- Node produz eventos sintéticos derivados da semente, sem copiar `is_fraud`.
- Um `INSERT` multi-linha de 500 eventos por conexão, cadenciado para 50 mil
  em aproximadamente 30 segundos de ingestão. A classificação em checkpoints
  ocorre em paralelo à chegada dos blocos; no teste validado com a cadência de
  300 ms, a rodada completa levou 35,3 segundos, sem falhas.
- HeatWave recebe change propagation para a tabela de eventos.
- Dashboard usa consultas `FORCED` somente nesta fase.

### 2. Classificação

- O frontend suspende o polling de gráficos analíticos enquanto um checkpoint
  está em execução, mantendo cartões e progresso pelo snapshot operacional.
- O modelo já deve estar carregado no preflight com `ML_MODEL_LOAD`.
- Para cada bloco de 5.000 IDs confirmados: `DELETE` da stage, `INSERT SELECT`
  das cinco features, `ML_PREDICT_TABLE`, `UPDATE` dos scores no evento e
  atualização de `live_demo_runs`.
- A interface consulta o progresso, alertas e transações classificadas pela
  camada operacional enquanto o ML trabalha.
- Se um checkpoint falhar por indisponibilidade transitória, espera 2,5 s e
  tenta novamente, sem criar chamadas concorrentes.

### 3. Resultado

- Depois de `scored_events = 50.000`, o dashboard volta a consultar o cluster
  e mostra o resultado consolidado.
- Alertas são sempre descritos como **previsão de risco do modelo**, não como
  fraude confirmada.

## Pré-flight antes do evento

Executar antes da apresentação, não no clique do visitante:

1. validar conexão e tabelas carregadas;
2. executar `ML_MODEL_LOAD` do modelo atual;
3. carregar `fraud_ml.live_scoring_stage` uma vez no HeatWave;
4. realizar um score técnico de 5.000 linhas e registrar tempo;
5. limpar somente tabelas de teste;
6. marcar a demo como `READY`.

## Quando usar uma arquitetura realmente simultânea

Se a exigência for gráficos analíticos atualizando **durante** cada checkpoint
de ML, a solução correta é separar recursos: um HeatWave para analytics e
outro para o worker de ML, ou capacidade dedicada compatível. Não é seguro
prometer simultaneidade plena sobre o mesmo cluster que, nos testes, entra em
estado temporariamente indisponível durante a inferência tabelar.

## Critérios de aceite

- Ingestão: 50.000/50.000 eventos confirmados em ~60 s.
- Score: 50.000/50.000 eventos classificados em 10 checkpoints de 5.000.
- Nenhuma query analítica `FORCED` disparada na fase `SCORING`.
- Reset remove apenas a execução da demo.
- Recarga do navegador recupera status da execução no banco.
- UI nunca fica em loading infinito; mostra estado e último resultado válido.
