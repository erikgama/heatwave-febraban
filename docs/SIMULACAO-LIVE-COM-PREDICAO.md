# Simulação ao vivo com predição de risco

## Objetivo

Demonstrar uma jornada completa no MySQL HeatWave: novas transações sintéticas
plausíveis entram no MySQL, são
classificadas pelo modelo de risco e aparecem imediatamente nas consultas
analíticas que alimentam o dashboard.

O resultado é um **alerta de risco previsto**, jamais uma confirmação de fraude.

## Desenho implementado

```text
amostra sem rótulo da base histórica
  -> gera 50.000 novas transações sintéticas plausíveis
  -> INSERT multi-linha de 500 eventos com cadência de UX de ~300 ms
  -> a cada 5.000 eventos confirmados: ML_PREDICT_TABLE
  -> probabilidade, classe e faixa de risco gravadas no evento
  -> consultas analíticas FORCED no HeatWave atualizam o dashboard
```

### Realismo sem reutilizar o rótulo

`fraud_demo.live_transaction_seed` contém cerca de 20,8 mil padrões obtidos
por amostra determinística da view de investigação. Ela carrega somente:

- estabelecimento, categoria, cidade e estado;
- valor, hora, dia da semana e fim de semana;
- distância cliente–estabelecimento.

O campo histórico `is_fraud` **não é copiado** para a semente nem para o evento
simulado. Cada novo evento recebe identificador sintético, mas preserva sem
alteração a combinação observada de categoria, valor, distância, hora, dia da
semana e fim de semana da linha-semente. O horário exibido é reconstruído para
ser compatível com essas features.

Para tornar os incrementos visíveis em uma apresentação, o gerador usa um
**mix de demonstração**: 55% dos perfis vêm do quartil superior de valores da
semente, 35% de categorias de canal digital (`*_net`) e 10% da distribuição
geral. Esse mix não altera nenhuma feature, não copia `is_fraud` e não decide
o resultado: toda probabilidade e todo alerta continuam sendo calculados pelo
`ML_PREDICT_TABLE`. Ele apenas torna o fluxo financeiro e os casos que merecem
análise mais perceptíveis no dashboard.

Antes de aceitar a semente, o backend compara os campos usados pelo modelo com
o conjunto final de treino: categoria deve existir no treino; valor e distância
devem estar dentro dos limites observados; hora, dia da semana e indicador de
fim de semana devem ser consistentes. Uma semente fora desse contrato bloqueia
a simulação, em vez de produzir uma previsão fora de suporte.

## Predição em checkpoints de 5.000

O modelo utilizado é:

`febraban_fraud_manual_xgb_b1_final_v2_20260810` (`XGBClassifier`)

Features consumidas pelo modelo:

`amount`, `amount_log`, `category`, `transaction_hour`, `weekday_number`,
`is_weekend` e `customer_merchant_distance_km`.

A tabela de estágio deve levar exatamente essas sete features, além das chaves
técnicas necessárias para reconciliar o resultado. `is_fraud` não é enviado:
é o target histórico que o modelo tenta estimar.

Para cada checkpoint, o backend grava exatamente os IDs das 5.000 linhas
confirmadas em `fraud_ml.live_scoring_stage`, executa `ML_PREDICT_TABLE` e
atualiza a tabela de eventos com:

- `model_prediction` — classe prevista;
- `fraud_probability` — probabilidade da classe positiva;
- `risk_band` — baixo, atenção, alto ou crítico.

O threshold operacional da simulação é `0,60`: um evento só entra no contador
de alertas quando `fraud_probability >= 0.60`. As faixas `0,85` e `0,95`
apenas priorizam alertas altos e críticos. O valor `0,27` pertence ao
experimento de validação B1 e não pode ser apresentado como regra da demo.

## Evidência de desempenho

Ambiente validado: **HeatWave 9.7.2-cloud**.

| Medição | Resultado |
|---|---:|
| Primeiro `ML_PREDICT_TABLE` de 5.000 linhas (incluindo carga) | 5,82 s |
| Segundo lote de 5.000 com modelo já em memória | 3,86 s |
| Rodada acelerada validada em 20/08/2026 | 50.000 inseridas / 50.000 classificadas |
| Tempo ponta a ponta da rodada acelerada | 43,6 s |
| Falhas na rodada acelerada | 0 |
| Volume movimentado na rodada acelerada | US$ 6.724.625,48 |
| Alertas previstos (score ≥ 27%) | 817 |
| Rodada com cadência de 300 ms (20/08/2026) | Registro histórico; não usar como SLA atual sem repetir o teste |
| Rodada E2E como `febraban` (23/08/2026) | 50.000 inseridas / 50.000 classificadas |
| Tempo de ingestão E2E (23/08/2026) | 121,45 s |
| Tempo total E2E, incluindo classificação final | 126,85 s |
| Falhas de inserção ou classificação E2E | 0 / 0 |
| Alertas E2E (score ≥ 60%) | 612 |
| Alertas E2E (score ≥ 85% / ≥ 95%) | 441 / 257 |

Os checkpoints são serializados para não disputar a tabela de estágio, mas a
ingestão não fica parada enquanto o modelo avalia um bloco anterior. A cadência
de 300 ms é uma meta de UX, não garantia de duração: em 23/08/2026 a rodada
E2E medida levou 121,45 s para inserir e 126,85 s até a classificação final.
A interface só pode indicar conclusão quando os 50 mil eventos estiverem
classificados; enquanto isso, deve mostrar quantos já receberam score e
atualizar o card **Alertas de risco previstos**.

## Isolamento de sessões

Os SELECTs do dashboard usam `use_secondary_engine=FORCED`; se o cluster não
puder atender, a consulta falha em vez de retornar silenciosamente pelo
InnoDB. As operações de DML e ML definem explicitamente
`use_secondary_engine=OFF`, pois `ML_PREDICT_TABLE` usa internamente o catálogo
de modelos, que não é uma tabela do cluster analítico. Essa separação evita que
uma conexão reutilizada pela pool transfira o modo `FORCED` para a rotina ML.

## Referência de produto

A documentação atual descreve `ML_PREDICT_TABLE` como predição paralela para
uma tabela inteira, registra `ml_results` com classe e probabilidades e permite
colunas adicionais. Para MySQL 9.4.1+, caso uma execução se torne longa, ela
recomenda limitar manualmente a entrada a até 1.000 linhas. Nesta demonstração,
o teste medido de 5.000 foi estável; caso o volume/modelo futuro altere essa
latência, o checkpoint visual pode permanecer em 5.000 enquanto a implementação
o divide internamente.

Fonte: [MySQL HeatWave — ML_PREDICT_TABLE](https://dev.mysql.com/doc/heatwave/en/mys-hwaml-ml-predict-table.html).
