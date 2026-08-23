# QA — contrato do modelo e usuário `febraban`

## Objetivo

Registrar a validação que garante que a simulação usa o modelo B1 com o mesmo
usuário de banco da aplicação: `febraban`. Este registro não contém IPs, senhas
ou outros segredos.

## Resultado aprovado nos três clones

| Verificação | Resultado |
| --- | --- |
| Conexão com `febraban` | Aprovada |
| Catálogo original | B1 presente em `ML_SCHEMA_admin`, proprietário `admin` |
| Catálogo da aplicação | B1 importado para `ML_SCHEMA_febraban`, proprietário `febraban` |
| Handle compartilhado | `febraban_fraud_manual_xgb_b1_final_v2_20260810` |
| Algoritmo | `XGBClassifier` para classificação |
| Tamanho do objeto importado | 952.050 bytes |
| `ML_MODEL_LOAD` como `febraban` | Aprovado nos três clones, entre 1,30 e 1,39 s |
| `ML_PREDICT_ROW` como `febraban` | Aprovado nos três clones, entre 0,74 e 0,82 s |
| `ML_PREDICT_TABLE` como `febraban` | Aprovado em 1.000 linhas nos três clones, entre 1,53 e 1,54 s |

O teste em lote retornou 1.000 previsões em cada clone. As tabelas temporárias
de QA foram removidas ao final de cada execução.

## Por que o compartilhamento é necessário

O modelo original foi criado pelo usuário `admin`. Quando `febraban` tentava
executar `ML_MODEL_LOAD(handle, NULL)`, o HeatWave procurava o handle em
`ML_SCHEMA_febraban.MODEL_CATALOG` e retornava `ML006009`.

Uma role administrativa não muda o catálogo ML que a rotina usa. A solução é
seguir o compartilhamento oficial do HeatWave:

1. Como `admin`, executar `ML_MODEL_EXPORT` para uma tabela compartilhável.
2. Como `febraban`, executar `ML_MODEL_IMPORT` dessa tabela para o próprio
   `ML_SCHEMA_febraban`.
3. Como `febraban`, executar `ML_MODEL_LOAD` e as rotinas de predição.

O modelo original não é alterado nem removido. A cópia compartilhada pode usar
o mesmo handle porque cada usuário possui catálogo independente.

Referência oficial: [Share a Model](https://dev.mysql.com/doc/heatwave/en/mys-hwaml-model-sharing.html).

## Contrato das features do B1 V2

As features registradas no catálogo do modelo são:

1. `amount`
2. `amount_log`
3. `category`
4. `transaction_hour`
5. `weekday_number`
6. `is_weekend`
7. `customer_merchant_distance_km`

`is_fraud` é o target histórico e não pode ser enviado em uma nova transação.

## Contrato operacional da simulação

- Meta visual: 50.000 eventos em 100 blocos de 500, a cada 300 ms.
- Classificação: checkpoints seriais de 5.000 eventos via `ML_PREDICT_TABLE`.
- A tabela de estágio recebe exatamente as sete features do B1.
- `amount_log` é calculado no `INSERT` como `LN(1 + amount)`; não pode ser
  nulo.
- O threshold operacional de alerta é `fraud_probability >= 0.60`.
- 0,85 e 0,95 são faixas visuais de priorização.
- Cada rodada usa `run_id`; a limpeza só pode afetar o `run_id` encerrado.

## Itens que continuam obrigatórios antes do evento

1. Executar o fluxo completo de 50.000 eventos com a aplicação configurada
   para `MYSQL_USER=febraban` e o handle acima.
2. Confirmar que os 10 checkpoints de 5.000 foram classificados, sem misturar
   rodadas e sem apresentar sucesso antes de `scored = 50.000`.
3. Registrar separadamente o tempo de ingestão e o tempo final de classificação.
4. Executar a simulação com uma única instância do backend por banco. A tabela
   de estágio e a tabela de resultado são reutilizadas; duas instâncias podem
   disputar `DELETE`/`DROP` e corromper a cadência.
5. Quando o B1 for retreinado, repetir exportação/importação em cada clone e
   testar com `febraban` antes de apontar a aplicação para o novo handle.

## Divergências documentais ainda a resolver no RAG

O catálogo do B1 atual confirma sete features e threshold operacional de 0,60,
mas o Vector Store já existente pode recuperar uma versão antiga que cita cinco
features e o threshold experimental de 0,27. Antes de usar RAG para explicar o
modelo ativo, criar um documento revisado, carregá-lo em novo Vector Store e
executar regressão de perguntas sobre features e thresholds.
