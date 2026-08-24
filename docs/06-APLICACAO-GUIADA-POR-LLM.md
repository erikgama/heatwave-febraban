---
layout: default
title: Aplicação guiada por LLM
---

# 6. Construir e publicar a aplicação com apoio de um LLM

Este repositório não entrega código de aplicação. A proposta do laboratório é
justamente criar a aplicação **por prompts**, usando Codex, OpenCode ou outro
assistente no seu repositório privado. Execute os prompts abaixo em ordem. Ao
final de cada um, peça testes automatizados e só siga quando os critérios de
aceite forem satisfeitos.

Antes do Prompt 0, execute o [contrato de execução para LLM](07-CONTRATO-DE-EXECUCAO-PARA-LLM.html).
Ele descobre os objetos reais do ambiente e impede que o agente invente nomes,
permissões ou tabelas.

## Prompt 0 — contrato e estrutura

```text
Você é o engenheiro responsável por uma demo de fraude com MySQL HeatWave.
Leia o README deste laboratório e proponha a estrutura de uma SPA React com
backend Node.js. Não implemente ainda. Liste rotas, tabelas auxiliares,
variáveis de ambiente, limites, testes e riscos. A aplicação deve usar o
usuário app_readonly para consultas públicas; qualquer escrita de simulação
deve ser feita por um usuário separado e com privilégio apenas nas tabelas de
live-run. Não exponha credenciais nem PII. Aguarde minha aprovação.
```

## Prompt 1 — dashboard analítico

```text
Implemente a SPA React e o backend Node.js aprovados. Crie uma única página
com dashboard corporativo. Consulte somente views permitidas de
fraud_demo_public, sempre no HeatWave, para mostrar valor movimentado, número
de transações, ticket médio, registros rotulados historicamente, série de
vendas e recortes por categoria, estabelecimento e cidade. Não use dados mock
quando o banco estiver disponível. Faça as consultas agregadas em paralelo,
tenha estado de carregamento inicial, tratamento de indisponibilidade e testes
de integração. Não mostre tempo interno de query ao visitante.
```

## Prompt 2 — simulação ao vivo

```text
Adicione ao dashboard um menu "Simular transações". Cada execução cria um
run_id isolado e insere 50.000 eventos sintéticos coerentes com a distribuição
do dataset (categorias, valores, horários e distâncias plausíveis), em cerca de
60 segundos. Use lotes multi-linha controlados e uma tabela separada de eventos
da demonstração. Atualize os gráficos a cada 1,5 segundo com baseline + delta
do run_id, sem apagar ou piscar valores já exibidos. Exiba apenas uma barra de
progresso simples durante o fluxo. Resetar demo deve remover exclusivamente os
eventos e scores daquele run_id; jamais alterar a tabela bruta. Implemente teste
que comprove que 50.000 eventos são inseridos e que o reset restaura o baseline.
```

## Prompt 3 — classificação no fluxo

```text
Acople ao live-run a classificação pelo modelo fraud_xgb_b1_v1 já treinado.
Não treine nem recarregue o modelo a cada clique. Antes de iniciar, confirme
que o modelo está ativo; se não estiver, carregue-o uma única vez, com lock de
aplicação para impedir cargas concorrentes. A cada janela lógica de 5.000
eventos inseridos, faça ML_PREDICT_TABLE em sublotes de no máximo 1.000 linhas
quando a versão do HeatWave recomendar este limite. Grave em tabela de scores:
run_id, transaction_id, score/probabilidade, faixa, scored_at e estado. Enquanto
um lote estiver pendente, retorne estado "classificando" ao frontend. Score
acima do threshold é alerta previsto, nunca fraude confirmada. Faça testes de
concorrência, erro do modelo e recuperação sem bloquear o dashboard.
```

## Prompt 4 — resultados e detalhe investigável

```text
Na mesma página, inclua uma seção "Transações classificadas no fluxo". Mostre
cards consolidados para classificadas e para faixas score >=60%, >=85% e >=95%,
sem duplicar indicadores. Adicione tabela paginada de todas as transações do
run_id, spinner por item enquanto a predição estiver pendente e modal de detalhe
ao clicar: data/hora, valor, cliente pseudonimizado, estabelecimento, categoria,
local, distância, score e explicação de que a probabilidade vem de ml_results
do modelo. Use linguagem de risco previsto. Garanta que o modal continue
funcionando enquanto a simulação atualiza e escreva testes de interface.
```

## Prompt 5 — chat de dados e chat documental

```text
Adicione um único chat com memória somente na sessão atual e um roteador de
intenções. Perguntas sobre números da base devem chamar sys.NL_SQL com
execute=false, schemas limitados a fraud_demo_public; valide o SQL gerado
aceitando apenas SELECT/WITH de views em allowlist, sem comentários, CALL, DDL,
DML, múltiplas instruções, e impondo LIMIT <=100 e timeout. Execute somente
depois da validação e mostre o SQL usado. Perguntas sobre modelo, dataset,
threshold, métricas ou limitações devem chamar sys.ML_RAG na Vector Store do
documento e devolver citações. O roteador deve manter contexto de follow-up,
mas não enviar credenciais, PII ou SQL anterior sem necessidade. Crie 20 testes
para NL to SQL, 20 para RAG e testes de bloqueio de prompt injection/DELETE.
```

## Prompt 6 — prontidão para demo e deploy

```text
Prepare a aplicação para uma demonstração presencial. Configure segredos por
variáveis de runtime/Vault, TLS, pool separado para leitura e simulação, CORS
restrito, rate limit, logs sem PII e endpoints de health que não executem
ML_PREDICT_TABLE. Crie um roteiro de smoke test: dashboard inicial, live-run de
60 segundos, classificação progressiva, detalhe de transação, reset, NL to SQL,
RAG e tentativa de DELETE bloqueada. Documente comandos de execução, variáveis
necessárias e como reverter somente um run_id de demo.
```

## Contratos sugeridos

| Rota | Entrada | Saída |
| --- | --- | --- |
| `GET /api/dashboard` | filtros permitidos | cards e séries |
| `POST /api/chat` | pergunta e sessão | resposta + SQL ou citações |
| `POST /api/live-runs` | parâmetros seguros | `runId` |
| `GET /api/live-runs/:runId` | paginação | progresso e scores |
| `GET /api/events/:id` | id validado | detalhe sem PII |

## Checklist de deploy

- segredos em Vault ou variáveis de runtime;
- TLS, pool mínimo e CORS restrito;
- input validation, rate limit e timeout;
- logs sem PII ou segredos;
- testes para DDL/DML, SQL multi-instrução e relações fora da allowlist;
- smoke tests de dashboard, NL SQL, RAG, scoring e reset;
- conectividade privada/controlada ao DB System.
