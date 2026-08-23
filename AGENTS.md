# Laboratório FEBRABAN — MySQL HeatWave + Codex

## Missão

Este repositório é um laboratório prático. Ajude o visitante a construir e validar experiências com dados de transações, analytics no HeatWave, modelo de risco já treinado, busca documental por vetores e linguagem natural para SQL.

O resultado pode ser uma análise, um dashboard, uma API, uma aplicação web, uma automação ou uma nova hipótese de investigação. Comece entendendo o pedido do visitante e proponha o menor caminho executável para materializá-lo.

## Contexto disponível

- Dataset público Sparkov/Fraud Detection, disponibilizado no laboratório.
- Camada de leitura: schema `fraud_demo_public` e views `v_*`.
- Dados de origem e fluxo de simulação: schema `fraud_demo`.
- Cluster analítico HeatWave para leituras analíticas.
- Modelo de classificação de risco previamente treinado no HeatWave.
- Documento do modelo e de compliance já vetorizado para `ML_RAG`.
- `sys.NL_SQL` para transformar perguntas em português em SQL auditável.

Não presuma nomes de handles, Vector Stores ou tabelas além dos que forem confirmados no ambiente. Descubra-os no primeiro diagnóstico ou use as variáveis de ambiente configuradas pelo laboratório.

## Primeiro contato: faça este diagnóstico

Antes de criar qualquer coisa, execute somente verificações curtas e reporte o resultado de forma simples:

1. Leia `README.md` e `docs/00-VISAO-GERAL.md`.
2. Verifique a conexão e a versão: `SELECT VERSION();`.
3. Liste as views de `fraud_demo_public` e descreva as colunas relevantes.
4. Confirme que uma consulta analítica funciona com `SET SESSION use_secondary_engine = FORCED` na **mesma conexão** seguida de um `SELECT` pequeno contra uma view pública.
5. Descubra o modelo no catálogo e confirme seu estado antes de prever.
6. Descubra o Vector Store configurado antes de chamar `ML_RAG`.

Se algum recurso não estiver pronto, explique qual é o bloqueio e ofereça uma alternativa segura. Não invente resultados, handles ou permissões.

## Como trabalhar com os recursos

### Dados e analytics

- Para exploração e dashboards, prefira as views de `fraud_demo_public`.
- Para um recorte de alto volume, force o cluster analítico na conexão da consulta. Não afirme que uma consulta usou HeatWave sem verificar.
- Use `EXPLAIN` e `LIMIT` durante a exploração. Só amplie o recorte depois de validar a intenção do visitante.
- Quando a pergunta citar *fraude* no dataset, diga **registro rotulado**; quando citar o modelo, diga **risco previsto**. Nunca trate score como fraude confirmada.

### Modelo de risco

- O modelo já existe: priorize `ML_PREDICT_ROW` para uma transação e `ML_PREDICT_TABLE` para lotes.
- Nunca envie o target/rótulo histórico (`is_fraud` ou equivalente) como feature de uma nova predição.
- Antes de uma predição em lote, valide o contrato de features e confirme que o modelo está carregado/pronto. Não carregue, descarregue ou treine modelos sem necessidade.
- Na demo, o threshold operacional de alerta é **60%**. O score continua sendo uma probabilidade; 60% não é confirmação de fraude.

### RAG e NL_SQL

- Use `sys.NL_SQL` para perguntas sobre fatos e agregações da base. Execute somente SQL validado, de leitura, e mostre o SQL usado.
- Use `ML_RAG` para perguntas sobre modelo, métricas, compliance, limitações e documentação. Cite os trechos recuperados e não crie fatos fora deles.
- Em perguntas híbridas, separe explicitamente: o que veio de SQL e o que veio do documento vetorizado.

## Segurança e governança

- Nunca imprima, registre no Git, cole em código ou peça que o visitante cole senhas, tokens, chaves privadas ou conteúdo de `.env`.
- Banco é **somente leitura por padrão**. Aceite `SELECT`, `SHOW`, `DESCRIBE`, `EXPLAIN` e chamadas de ML/RAG necessárias ao laboratório.
- Para criar tabelas, views, apps ou objetos novos, trabalhe no schema de sandbox destinado ao notebook. Antes de DDL/DML, informe alvo e efeito.
- Nunca execute `DROP`, `TRUNCATE`, `DELETE` amplo, `UPDATE` amplo ou `GRANT` sem pedido explícito do visitante e confirmação do alvo exato.
- Não altere objetos públicos, dataset original, modelo publicado, Vector Store existente ou políticas de acesso como parte de uma exploração comum.

## Fluxo de implementação para pedidos de criação

Quando o visitante pedir para criar uma aplicação, dashboard, consulta, automação ou agente:

1. Reescreva o objetivo em uma frase e liste os dados/recursos que serão usados.
2. Inspecione o schema e faça uma consulta mínima real antes de codificar.
3. Crie a solução no diretório de trabalho do visitante; mantenha credenciais em variáveis de ambiente, nunca no frontend ou no Git.
4. Para aplicações web, use backend para toda conexão MySQL; o browser jamais acessa o banco diretamente.
5. Exiba SQL, fonte de dados, filtros, período, limitações e o significado do score quando isso for útil ao usuário final.
6. Teste o fluxo real: conexão, consulta, tratamento de erro, visualização e, se existir, predição/RAG/NL_SQL.
7. Entregue os arquivos alterados, como executar e o que foi validado.

## Ideias que o visitante pode construir

- Dashboard executivo com vendas, categorias, estabelecimentos, cidades e comparação de períodos no cluster analítico.
- Mesa de investigação: filtros, ranking de risco, detalhe de transação, SQL auditável e acompanhamento em linguagem natural.
- Simulador de novas compras com predição em lote e alerta quando score >= 60%.
- Copiloto de dados: roteamento entre `NL_SQL` e `ML_RAG`, memória apenas da sessão e respostas com evidência.
- API de alertas ou relatório gerencial que consome scores já calculados.
- Novos experimentos de features/modelos, sempre em objetos de sandbox e sem modificar o modelo de referência.

## Prompt inicial sugerido ao visitante

> Leia `AGENTS.md`, faça o diagnóstico inicial do laboratório e me mostre os recursos que estão prontos. Depois, me ajude a construir **[minha ideia]**. Use dados reais do ambiente, mostre o SQL executado e não altere objetos compartilhados sem me avisar.

## Referências do repositório

- `README.md`: laboratório ponta a ponta e prompts de construção.
- `docs/00-VISAO-GERAL.md`: arquitetura e propósito da demonstração.
- `docs/02-DADOS-E-CAMADA-PUBLICA.md`: dataset, schema e views.
- `docs/03-MODELO-E-PREDICOES.md`: contrato do modelo e predição.
- `docs/04-ANALYTICS-E-NL-SQL.md`: cluster analítico e NL_SQL.
- `docs/05-RAG-DOCUMENTAL.md`: documentos, embeddings e ML_RAG.
- `docs/09-RUNBOOK-OPERACIONAL-E-POLITICA-DE-ACESSOS.md`: operação e guardrails.

Mantenha estas instruções enxutas. Quando precisar de detalhe técnico, abra a referência específica em vez de duplicar documentação nesta página.
