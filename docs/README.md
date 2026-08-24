# Índice da documentação — HeatWave Fraud Copilot

Este diretório reúne o projeto funcional, a validação e o material operacional
da demonstração para a FEBRABAN.

## Comece por aqui

1. [Guia mestre da demonstração agêntica](DEMO-AGENTE-HEATWAVE-AUTOML.md) —
   arquitetura, modelo, contrato do agente, memória, guardrails, interface,
   roteiro e checklist de liberação.
2. [Matriz de avaliações de linguagem natural](EVALS-LINGUAGEM-NATURAL-AUTOML.md)
   — 80 perguntas e quatro cadeias multi-turno para validar o agente.
3. [Histórico de evolução](CHANGELOG-DEMO.md) — decisões, correções e estado da
   demonstração ao longo do projeto.
4. [Runbook operacional e política de acessos](09-RUNBOOK-OPERACIONAL-E-POLITICA-DE-ACESSOS.md)
   — VM, serviços, roles, grants, modelo, recuperação e regras para segredos.
5. [Checklist de preparação de clone HeatWave](CHECKLIST-PREPARACAO-CLONE-HEATWAVE.md)
   — roteiro completo de rede, cluster, modelo, RAG, NL_SQL, VM e aceite final.

## Machine Learning

- [Runbook do HeatWave AutoML](HEATWAVE-AUTOML-FRAUDE-RUNBOOK.md) — preparação,
  treino, seleção, avaliação final, predição e explicabilidade.
- [Checkpoint do passo 3](AUTOML-CHECKPOINT-STEP-3.md) — ponto de continuidade
  operacional do pipeline.
- [Teste de uma nova transação](TESTE-PREDICAO-NOVA-TRANSACAO.md) — chamada real
  de `ML_PREDICT_ROW`, entrada enviada, retorno e interpretação do score.
- [Plano do modelo manual XGBoost V2](PLANO-MODELO-MANUAL-XGB-V2.md) —
  preparação da base, features comportamentais, controle de leakage, treino e
  avaliação temporal. A execução já materializou as bases B1/B2; as métricas
  V2 só devem ser publicadas após a validação temporal.
- [Checkpoint de execução do XGBoost V2](AUTOML-V2-EXECUCAO-CHECKPOINT.md) —
  evidências da materialização e ponto seguro para retomar o treino.
- [Resultados do modelo B1 V2](RESULTADOS-MODELO-B1-V2.md) — treinamento,
  validação temporal, teste independente e simulação do modelo XGBoost.
- [Guia do laboratório FEBRABAN](GUIA-MODELO-E-DADOS-B1-V2-RAG.md) — base
  Kaggle/Sparkov, colunas, MySQL HeatWave, cluster analítico, AutoML, banco
  vetorial, RAG, OpenCode/Codex, sugestões da demo e guardrails.
- [Plano V2 de OpenCode + Codex via OpenRouter](PLANO-V2-OPENCODE-OPENROUTER.md)
  — contrato de ferramentas, segurança, memória de sessão e roteiro para o
  evento.

## Agente e linguagem natural

- [Validação geral de linguagem natural](validacao-linguagem-natural.md) —
  intenções e comportamento da versão transacional.
- [Validação dos casos agênticos](VALIDACAO-CASOS-AGENTICOS.md) — viabilidade e
  lacunas dos fluxos de investigação.
- [Matriz AutoML do agente](EVALS-LINGUAGEM-NATURAL-AUTOML.md) — regressão futura
  para score, alertas, métricas, erros do modelo e follow-ups.
- [NL to SQL nativo do HeatWave](NL-SQL-HEATWAVE.md) — fluxo `NL_SQL` +
  `ML_GENERATE`, configuração, guardrails e validação real.

## Compliance e RAG

- [Guia de compliance para fraude](guia-compliance-fraude-rag.md) — fonte
  documental preparada para recuperação semântica e respostas de compliance.
- [Carga RAG GPU ativa](../database/rag/15_load_model_document_gpu_rev2.sql)
  — PDF REV2, `cohere.embed-v4.0` no OCI Generative AI (GPU) e Vector Store
  novo, sem sobrescrever evidências históricas.
- [Validação RAG GPU ativa](../database/rag/16_validate_gpu_rev2.sql)
  — aceite das sete features e do threshold operacional de 60% pelo usuário
  `febraban`.
- [Validação do RAG do modelo B1 V2](VALIDACAO-RAG-MODELO-B1-V2.md) — evidência
  da carga concluída, avaliação da resposta e arquitetura de recuperação
  fundamentada pelo Codex.
- Stores e scripts CPU ou de versões anteriores permanecem como evidência
  histórica; não devem ser usados para configurar a demo atual.
- Versões para apresentação: `guia-compliance-fraude-rag.pdf` e
  `guia-compliance-fraude-rag.docx`.

## Estado em 10/08/2026

- aplicação SPA transacional: implementada e testada;
- memória por sessão e reset: implementados;
- modelo HeatWave AutoML e predições: concluídos;
- view pública de predições: criada;
- integração do score e da explicabilidade ao chat: pendente;
- automação dos 80 novos casos de avaliação: pendente.

O guia mestre é a fonte principal para decidir se a versão agêntica está pronta
para o evento.
