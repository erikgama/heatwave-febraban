---
layout: default
title: Contrato de execução para LLM
---

# 7. Contrato de execução para Codex e outros LLMs

Este capítulo remove a ambiguidade entre a documentação e um ambiente já
preparado. Um LLM não deve começar criando a aplicação pelo texto da demo: deve
primeiro executar o inventário, registrar o contrato encontrado e parar se o
ambiente divergir.

## Prompt de partida

Copie este prompt junto com o link do repositório:

```text
Implemente a aplicação descrita em https://github.com/erikgama/heatwave-febraban.
Se a interface do GitHub não abrir os arquivos, use também
https://erikgama.github.io/heatwave-febraban/. O DB System MySQL HeatWave, o
cluster, a VM, os dados, o modelo e o Vector Store já existem. Leia primeiro
README.md e docs/07-CONTRATO-DE-EXECUCAO-PARA-LLM.md.

Antes de escrever qualquer código, leia o arquivo local temporário
`ACESSO-LABORATORIO.md` (não versionado) e execute o preflight do capítulo 7.
Crie IMPLEMENTATION-CONTRACT.md
no repositório da aplicação com os nomes reais encontrados, versão, permissões,
model handle, tabela do Vector Store, views permitidas e resultado de cada teste.
Não use mocks, não adivinhe nomes, não exponha segredos nem altere tabelas
históricas, modelo ou Vector Store. O pré-flight pode inspecionar
`fraud_demo`, `fraud_ml` e `febraban_rag` somente em leitura. Se algum
pré-requisito falhar, pare e reporte a divergência.
Depois da aprovação do contrato, implemente os prompts 1 a 6 do README em ordem,
executando os testes de aceite de cada etapa.
```

## Preflight obrigatório

O operador fornece a credencial temporária no arquivo local
`ACESSO-LABORATORIO.md`; o LLM nunca a coloca no código, no Git, em logs ou em
uma resposta. Com um cliente SQL usando o usuário **`febraban`**, execute e
registre somente o resultado sanitizado:

```sql
SELECT VERSION() AS mysql_version;
SELECT * FROM performance_schema.rpd_nodes;

SELECT TABLE_SCHEMA, TABLE_NAME, TABLE_TYPE
FROM information_schema.tables
WHERE TABLE_SCHEMA IN ('fraud_demo','fraud_demo_public','fraud_ml','febraban_rag')
ORDER BY TABLE_SCHEMA, TABLE_NAME;

SHOW FULL TABLES FROM fraud_demo_public;
SHOW TABLES FROM febraban_rag;

SELECT model_handle, model_owner, model_type, task, target_column_name,
       train_table_name, column_names, model_object_size
FROM ML_SCHEMA_febraban.MODEL_CATALOG
WHERE model_handle = 'febraban_fraud_manual_xgb_b1_final_v2_20260810';
```

O contrato só está aprovado se todos estes itens forem verdadeiros:

| Item | Condição de aceite |
| --- | --- |
| HeatWave | há nós disponíveis em `performance_schema.rpd_nodes` |
| dados | `fraud_demo.transactions_raw` existe e a camada pública existe |
| acesso do chat | `fraud_demo_public.v_transactions_investigation` existe e não expõe cartão, nome, endereço ou coordenadas |
| modelo | B1 V2 existe em `ML_SCHEMA_febraban`; o LLM registra owner e features e só prevê após autorização |
| RAG | há uma tabela de Vector Store em `febraban_rag`; registrar o nome exato |
| isolamento | `fraud_demo.live_transaction_events` existe; nunca reutilizar tabelas brutas |
| segurança | não há segredo, PII ou saída de `SHOW GRANTS` integral no log da aplicação |

Se o modelo, o Vector Store ou uma view tiverem nome diferente, o LLM deve usar
o nome real no `IMPLEMENTATION-CONTRACT.md` e em variáveis de ambiente. Se não
existirem, ele deve parar; não pode treinar, vetorizar ou conceder privilégios
por conta própria.

## Contrato de acesso local temporário

No notebook do laboratório, crie `ACESSO-LABORATORIO.md` na raiz do projeto
local e mantenha-o fora do Git. Ele contém host, porta, usuário `febraban`,
senha temporária, schema padrão e modo SSL. O agente pode lê-lo para configurar
o runtime, mas nunca deve mostrá-lo, copiá-lo para código ou enviá-lo ao Git.

O modelo ativo e o threshold devem ser configuráveis, mas seus valores de
referência são:

```text
HEATWAVE_MODEL_HANDLE=febraban_fraud_manual_xgb_b1_final_v2_20260810
HEATWAVE_VECTOR_STORE=febraban_rag.modelo_b1_v2_cpu_e5_pdf
HEATWAVE_NL_SQL_MODEL=meta.llama-3.3-70b-instruct
HEATWAVE_RAG_MODEL=meta.llama-3.3-70b-instruct
RISK_THRESHOLD=0.60
```

O LLM deve validar que os valores necessários existem no runtime sem imprimir
segredos. A aplicação falha rapidamente, com mensagem operacional genérica, se
o acesso ou o contrato do modelo estiver ausente.

## Limites de acesso e tabelas de live-run

Há dois pools de conexões no backend, nunca no frontend:

| Pool | Pode fazer | Não pode fazer |
| --- | --- | --- |
| `readPool` (`febraban`) | `SELECT` em views públicas; chamar NL_SQL e ML_RAG autorizados | tabela bruta em UI/chat, DDL/DML gerado pelo usuário |
| `livePool` (`febraban`) | ler/escrever apenas `fraud_demo.live_transaction_events` e estágio ML autorizado; chamar a predição B1 aprovada | tabela bruta, treino, alteração de views públicas ou RAG fora do necessário |

O worker atual usa `fraud_demo.live_transaction_events`, isolando cada rodada
com `run_id`, e pode reutilizar as tabelas técnicas de estágio/resultado em
`fraud_ml`. Não crie o schema fictício `fraud_demo_live` nem novas tabelas de
controle sem solicitação explícita: os objetos provisionados são:

```text
fraud_demo.live_transaction_seed
fraud_demo.live_transaction_events
fraud_demo_public.v_live_transaction_events
```
```

O LLM deve gerar transações plausíveis a partir de distribuições agregadas da
camada pública ou de um conjunto permitido pelo operador. Não pode copiar PII,
coordenadas, cartão ou uma linha inteira da tabela bruta para a tabela live.

## Contrato de API

Todas as respostas usam JSON; `runId` é validado como UUID e nenhum endpoint
aceita SQL fornecido pelo navegador.

| Rota | Entrada mínima | Saída / aceite |
| --- | --- | --- |
| `GET /api/dashboard` | `runId` opcional | cards e séries; com run, retorna baseline e delta acumulado |
| `POST /api/live-runs` | nenhuma ou parâmetros allowlisted | cria um `runId`, agenda 50.000 eventos e retorna `queued` |
| `GET /api/live-runs/:runId` | UUID | status, inseridos, classificados, progresso e erro sanitizado |
| `POST /api/live-runs/:runId/reset` | UUID | remove somente scores/eventos daquele run e marca `reset` |
| `GET /api/live-runs/:runId/events` | UUID, `page`, `pageSize` | paginação estável, score/estado e máximo de 100 linhas |
| `GET /api/live-runs/:runId/events/:eventId` | UUIDs | detalhe sem PII e sem consulta à tabela bruta |
| `POST /api/chat` | pergunta, `sessionId` | resposta, SQL validado **ou** citações RAG; memória apenas da sessão |

## Regras que o LLM não pode flexibilizar

1. Não usar `DELETE`, `UPDATE`, `DROP`, `TRUNCATE`, `CALL`, comentários ou SQL
   em múltiplas instruções produzido por NL_SQL. O backend valida antes de
   executar e aceita apenas `SELECT`/`WITH` sobre a allowlist pública.
2. Não carregar, treinar ou descarregar o modelo em cada requisição. Um único
   worker coordena a carga; a cópia do B1 deve ser lida de
   `ML_SCHEMA_febraban.MODEL_CATALOG`. Dashboard e chat continuam disponíveis
   se scoring falhar.
3. Não declarar fraude confirmada. O rótulo é histórico sintético e o score é
   risco previsto.
4. Não gravar credencial, PII, resultado de `SHOW GRANTS` ou conteúdo integral
   da tabela bruta em repositório, logs ou resposta HTTP.
5. Não avançar para a próxima etapa se os testes de aceite da atual falharem.

## Teste final que o LLM deve entregar

O agente só declara a implementação pronta quando apresentar evidência de:

1. dashboard inicial sem dados mockados;
2. um live-run de 50.000 eventos, com `inserted = scored = 50000`, zero falhas
   de lote/classificação e tempos de ingestão e total registrados;
3. dashboard acumulando baseline + delta sem flicker;
4. classificação por janela de 5.000, com sublotes de até 1.000 quando
   necessário, sem reloading concorrente do modelo;
5. tabela paginada, spinner pendente e modal de detalhe funcionando durante o
   live-run;
6. 20 perguntas NL_SQL e 20 perguntas RAG aprovadas;
7. tentativa de DDL/DML, SQL multi-instrução e prompt injection bloqueadas;
8. reset removendo apenas o `run_id` atual e restaurando o baseline.
