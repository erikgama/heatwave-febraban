# Histórico de evolução da demonstração

## 23/08/2026 — Threshold operacional elevado para 60%

- O corte de alerta da **demonstração ao vivo** passou de `27%` para `60%`.
  A alteração reduz o volume operacional de casos e deixa a mesa de análise
  focada em sinais mais fortes. Não altera o modelo treinado, seus pesos nem a
  probabilidade calculada pelo HeatWave.
- Cards, resultado da simulação, tabela de transações, detalhe da transação e
  orientação do `NL_SQL` foram alinhados ao mesmo corte (`score >= 60%`). As
  faixas exibidas agora são `>= 60%`, `>= 85%` e `>= 95%`.
- A referência de `27%` nas documentações de avaliação histórica continua
  registrada como resultado do experimento; ela não é mais o threshold de
  alerta usado na experiência do visitante.

## 20/08/2026 — Fluxo live mais curto e mais perceptível

- Cadência de ingestão ajustada de 600 ms para 400 ms por lote: 50 mil eventos
  entram em aproximadamente 40 segundos, sem pausar a ingestão enquanto um
  checkpoint anterior é classificado.
- Mix de demonstração preserva integralmente os valores de features observadas
  na semente: 55% de perfis do quartil superior de valor, 35% de canais
  digitais e 10% da distribuição geral. Nenhum rótulo histórico é copiado ou
  usado para decidir alerta.
- Validação real na VM: 50.000 inseridas e classificadas em 43,6 s, sem falhas,
  com US$ 6.724.625,48 movimentados e 817 alertas previstos para score ≥ 27%.
- Cadência refinada posteriormente para **300 ms por lote**: a meta visual de
  inserção passa a ser aproximadamente 30 segundos; a validação ponta a ponta
  dessa nova cadência deve ser registrada antes da apresentação.
- Correção preventiva de concorrência: o `UPDATE` pós-predição passou a ficar
  restrito aos IDs do checkpoint, com índice `(run_id,event_id)`. Isso evita
  que um score bloqueie eventos novos da mesma rodada.
- Validação final da cadência de 300 ms: 50.000 inseridas e classificadas em
  **35,3 s**, sem batches com falha, com US$ 6.752.466,96 movimentados e 806
  alertas previstos (score ≥ 27%).

## 18/08/2026 — Chat: correção de rotas, contexto e estabilidade

- Corrigido o contrato do catálogo do `sys.NL_SQL`: a aplicação agora informa
  somente as quatro views que existem no schema público (`v_transactions_investigation`,
  `v_category_summary`, `v_merchant_summary` e `v_state_summary`). Views
  planejadas, porém inexistentes, foram removidas da allowlist e das instruções
  entregues ao modelo.
- Removida a segunda chamada a `ML_GENERATE` que apenas redigia o resumo de
  resultados do NL-to-SQL. Ela podia permanecer pendente e consumir todas as
  conexões do pool. O `NL_SQL` continua disponível; o resumo agora é
  determinístico e baseado na evidência SQL retornada.
- Corrigida a demonstração das sugestões: as cinco perguntas analíticas da
  interface agora passam obrigatoriamente por `sys.NL_SQL`, mostram a origem
  `MySQL HeatWave · NL_SQL` e exibem o `SELECT` gerado e validado. A pergunta
  sobre limitações do schema permanece uma resposta de governança, sem SQL,
  porque não há dado a consultar.
- Corrigida a memória: uma pergunta independente não herda mais o filtro da
  pergunta anterior. A categoria ativa só é aplicada quando o visitante pede
  explicitamente algo como “dessa categoria”.
- Padronizada a linguagem de negócio: `dataset_fraud_label = 1` aparece como
  **rótulo histórico sintético**, jamais como confirmação de fraude real.
- Validação na VM concluída com serviço `active`, health `database: ok`, os
  seis atalhos exibidos na interface e **109 testes automatizados aprovados**.
- A paridade entre fonte local, build e publicação na VM está detalhada em
  [10-PARIDADE-LOCAL-E-VM-CHAT.md](10-PARIDADE-LOCAL-E-VM-CHAT.md).
- Validação adicional sob carga concluída: após uma simulação de 50.000
  eventos, todos classificados, a bateria das seis perguntas foi repetida na
  mesma sessão da interface, sem erro e com respostas renderizadas entre
  553 ms e 595 ms.
- Corrigido o ranking visual após o término da simulação: a interface usava o
  top incremental de merchants/cidades para recompor a base histórica, o que
  podia omitir incrementos de entidades fora desse top. Em `COMPLETED`, ela
  passa a usar a consolidação integral do backend; cards, gráficos e faixas de
  risco foram reconciliados visualmente com o HeatWave.

## 17/08/2026 — Operação na VM e correção do contrato de predição

- Rotacionada a senha do usuário restrito `febraban` e atualizada apenas no
  arquivo protegido de ambiente da VM. A aplicação permanece sem credencial
  administrativa e o health check retornou `database: ok`.
- Validado o modelo atual no HeatWave com `ML_MODEL_LOAD` e
  `ML_PREDICT_ROW`: carga observada de **953 ms**, predição observada de
  **422 ms**, score da classe `1` de **61,07%** para a transação de smoke test.
- **Correção documentada:** uma instrução anterior dizia que este modelo usava
  cinco features. O schema efetivamente registrado exige sete:
  `amount`, `amount_log`, `category`,
  `customer_merchant_distance_km`, `is_weekend`, `transaction_hour` e
  `weekday_number`.
- A tentativa com cinco campos foi rejeitada corretamente pelo HeatWave com
  `ML003011`; o teste foi repetido com o contrato correto e concluído com
  sucesso. Nenhuma alteração foi feita no modelo ou na base histórica.

Detalhes: [TESTE-PREDICAO-VM-2026-08-17.md](TESTE-PREDICAO-VM-2026-08-17.md) e
[08-OPERACAO-VM-DEMO.md](08-OPERACAO-VM-DEMO.md).

## 17/08/2026 — Correção de tela branca por acesso HTTP público

- **Causa identificada:** ao acessar a aplicação pelo IP público em HTTP, o
  navegador não disponibilizava `crypto.randomUUID()`. A inicialização do
  React falhava antes da primeira renderização e a página ficava em branco.
- Corrigida a geração do identificador de sessão efêmera: usa
  `crypto.randomUUID()` quando disponível e um identificador compatível como
  fallback em contexto HTTP. O fallback não é usado para autenticação nem para
  decisão de segurança.
- Gerada e publicada uma nova build na VM. A versão anterior foi preservada
  como backup antes da troca.
- Validação externa concluída: o dashboard renderizou, exibiu os indicadores e
  não registrou novo erro JavaScript de `randomUUID`; health e dashboard
  responderam com `database: ok` e HTTP 200.

## 17/08/2026 — Validação da simulação na VM e dependência de catálogo ML

- Rodada reproduzida pela interface pública: ingestão, contadores e gráficos
  incrementais funcionaram até 10.000 eventos, sem erro JavaScript ou queda do
  serviço Node.
- A classificação foi interrompida no primeiro checkpoint de 5.000 linhas.
  O modelo estava carregado no preflight administrativo; a causa não foi carga
  de modelo, mas a exigência do `ML_PREDICT_TABLE` de ler
  `ML_SCHEMA_admin.MODEL_CATALOG` com o usuário invocador.
- `febraban` recebeu privilégios completos apenas em `fraud_demo` e
  `fraud_ml`, além de `EXECUTE` para `sys.ML_PREDICT_TABLE`. A liberação mínima
  ainda pendente é `SELECT` exclusivamente em `ML_SCHEMA_admin.MODEL_CATALOG`.
- Corrigido o backend para que falhas assíncronas de ingestão não encerrem o
  processo Node. A UI agora mantém status e os gráficos enquanto o erro de
  classificação é reportado.

## 12/08/2026 — NL to SQL nativo do MySQL HeatWave

- O Copiloto passou a usar `sys.NL_SQL` para perguntas sobre a base: a rotina
  recebe somente as oito views públicas permitidas e gera SQL sem executá-lo.
- O gateway Node.js continua sendo a fronteira de segurança: rejeita escrita,
  schema bruto, comentários, múltiplas instruções, relações fora da allowlist e
  resultados acima de 100 linhas; aplica também timeout de 10 segundos.
- Somente após essa validação o `SELECT` é executado. `sys.ML_GENERATE` recebe
  a pergunta e até 12 linhas retornadas para redigir a resposta em português.
- Validação real no DB System `9.7.2-cloud`: NL_SQL gerou um `SELECT` sobre
  `v_category_summary`, retornou 14 categorias e o SQL validado executou em
  2.870 ms. A resposta final foi gerada pelo modelo
  `llama3.2-3b-instruct-v1`.
- Adicionada a configuração `USE_HEATWAVE_NL_SQL` e
  `HEATWAVE_NL_SQL_MODEL`. O usuário de demonstração ainda requer os dois
  grants mínimos de `EXECUTE`, documentados no runbook.

Detalhes: [NL-SQL-HEATWAVE.md](NL-SQL-HEATWAVE.md).

## 11/08/2026 — Simulação ao vivo com predição em checkpoints

- Eventos da simulação passaram a ser gerados a partir de uma amostra sem rótulo
  da base, preservando distribuição de categoria, praça, estabelecimento,
  valor, hora e distância.
- Implementados dez checkpoints de `ML_PREDICT_TABLE` de 5.000 eventos para
  cada execução de 50.000 transações.
- Resultado é persistido nos campos `model_prediction`, `fraud_probability` e
  `risk_band`; a interface apresenta **alertas de risco previstos**.
- Teste final: 50.000 eventos inseridos, 50.000 classificados, 214 alertas
  previstos e zero falhas de ingestão ou score.
- Corrigido isolamento de sessão: apenas os SELECTs do dashboard usam
  `use_secondary_engine=FORCED`; operações ML e DML usam `OFF`.
- Corrigida abertura da interface: o menu só aparece após o dashboard receber
  a primeira resposta (ou erro), eliminando a tela de loading presa com menu.

Detalhes e medições: [SIMULACAO-LIVE-COM-PREDICAO.md](SIMULACAO-LIVE-COM-PREDICAO.md).

## 11/08/2026 — Fluxo consolidado de ingestão, analytics e ML

- O fluxo foi separado em `INGESTING → SCORING → COMPLETED` para evitar que
  `ML_PREDICT_TABLE` e dashboards com `use_secondary_engine=FORCED` disputem o
  mesmo cluster simultaneamente.
- Durante `INGESTING`, somente o dashboard incremental é atualizado; durante
  `SCORING`, a interface acompanha contadores operacionais e preserva a última
  visão analítica; ao final, executa refresh consolidado.
- Corrigido polling: uma consulta não inicia enquanto a anterior estiver ativa.
- Substituído `TRUNCATE` da stage por `DELETE`, preservando a cópia HeatWave.
- Validação final: **50.000 inseridas, 50.000 classificadas, 247 alertas
  previstos, zero falhas**. Refresh analítico final: **703 ms**.

Decisão e runbook: [ARQUITETURA-DEMO-LIVE-CONSOLIDADA.md](ARQUITETURA-DEMO-LIVE-CONSOLIDADA.md).

## 11/08/2026 — Mesa de transações classificadas no dashboard

- Incluída seção operacional após os gráficos analíticos.
- Exibe transação, estabelecimento, categoria, praça, valor, probabilidade de
  risco e faixa de risco em linguagem de negócio.
- Ordenação prioriza os maiores scores previstos; mostra até 12 registros para
  leitura rápida na demonstração.
- A seção acompanha os checkpoints de score e explica seu estado durante
  ingestão e classificação. Resultados são explicitamente apresentados como
  previsão de risco, não fraude confirmada.

## 11/08/2026 - pendência de linguagem para negócio

Decisão: o identificador interno `B1` não deve aparecer para visitantes. Ele
significa a primeira versão técnica do modelo, e não “base 1”; fora do contexto
de engenharia, é ambíguo e não agrega valor.

Na próxima revisão de documentação, RAG, interface e prompts, substituir a
linguagem visível por **“Modelo de risco de fraude - versão atual”**. Manter
`febraban_fraud_manual_xgb_b1_final_v2_20260810` e demais identificadores B1
somente em scripts, metadados e documentação técnica de operação. Esta decisão
não altera o modelo, as métricas, os Vector Stores nem os testes aprovados.

Este documento registra mudanças funcionais, decisões de arquitetura, correções e validações do HeatWave Fraud Copilot.

## 11/08/2026 — Validação de carga e latência de predição do modelo atual

- Modelo carregado no HeatWave com `sys.ML_MODEL_LOAD` e validado com
  `sys.ML_PREDICT_ROW`.
- A transação sintética de teste não foi persistida no banco.
- Latência ponta a ponta medida no cliente MySQL: **1,88 s**. A medida inclui
  conexão de rede, serialização do resultado e a inferência; não deve ser lida
  como tempo exclusivo do algoritmo.
- Entrada efetivamente aceita pelo modelo: `amount`, `amount_log`, `category`,
  `customer_merchant_distance_km`, `transaction_hour`, `weekday_number` e
  `is_weekend`. O rótulo `is_fraud` não é enviado.
- Resultado da simulação: probabilidade de rótulo histórico sintético `1` de
  **61,07%**; com threshold operacional `0,27`, o caso gera **alerta de risco**.
- Benchmark separado de `ML_PREDICT_TABLE`: **100.000 linhas preditas em
  12,34 s** ponta a ponta, incluindo a escrita da tabela de saída. Isso equivale
  a aproximadamente **8.104 linhas/s** nesse ensaio; não é uma garantia de SLA.

> Esta validação confirma a operação técnica. O rótulo e a previsão não
> confirmam fraude real.

## 10/08/2026 — Plano V2 de features manuais e XGBoost fixo

- definido plano para modelo dirigido por especialista, mantendo treinamento e
  inferência nativos no HeatWave;
- incluídos controles de leakage temporal, experimentos de ablação e gates de
  aprovação antes do retreino;
- proposta inicial evita `merchant_name` bruto e prioriza comportamento anterior
  do cartão, janelas temporais e deslocamento entre transações.

Plano: [PLANO-MODELO-MANUAL-XGB-V2.md](PLANO-MODELO-MANUAL-XGB-V2.md).

## 10/08/2026 — Predição real de uma nova transação

### Resultado

- executado `sys.ML_PREDICT_ROW` com o modelo final;
- entrada composta apenas pelas features, sem enviar o alvo `is_fraud`;
- transação sintética de `1.000,00`, categoria `shopping_net`, às 23h;
- classe prevista `1`, com probabilidade de risco de `89,77%`;
- alerta gerado pelo threshold persistido de `0,33`;
- nenhuma transação inserida ou alterada no banco.

Evidência completa: [TESTE-PREDICAO-NOVA-TRANSACAO.md](TESTE-PREDICAO-NOVA-TRANSACAO.md).

## 10/08/2026 — Documentação da demonstração agêntica com AutoML

### Entregas

- guia mestre criado com arquitetura, responsabilidades, memória de sessão,
  ferramentas do agente, contrato de resposta, guardrails, visualizações,
  roteiro da apresentação e contingência;
- cartão do modelo e métricas finais documentados em linguagem de negócio;
- catálogo criado com 80 perguntas de avaliação e quatro cadeias multi-turno;
- caso curado `1320907` definido para demonstrar score e explicabilidade;
- distinção obrigatória estabelecida entre rótulo histórico, probabilidade,
  alerta do modelo e fraude confirmada;
- tarefas P0 registradas para conectar a view de predições ao chat com segurança.

Documentos:

- [DEMO-AGENTE-HEATWAVE-AUTOML.md](DEMO-AGENTE-HEATWAVE-AUTOML.md)
- [EVALS-LINGUAGEM-NATURAL-AUTOML.md](EVALS-LINGUAGEM-NATURAL-AUTOML.md)
- [Índice da documentação](README.md)

## 10/08/2026 — Pipeline HeatWave AutoML concluído

### Resultado

- Busca de desenvolvimento concluída com `XGBClassifier` como vencedor.
- Retreino final executado sobre 1.296.675 transações de `fraudTrain`.
- Holdout temporal `fraudTest` avaliado uma única vez, com threshold `0,33` congelado na validação.
- 555.719 predições persistidas em `fraud_ml.fraud_predictions_v1`.
- Métricas finais: F1 `0,7180`, precision `0,7149`, recall `0,7212`, balanced accuracy `0,86005` e ROC AUC `0,99454706`.
- Explicações locais geradas para os dez maiores scores.
- View somente leitura criada: `fraud_demo_public.v_fraud_predictions`.

Runbook: [HEATWAVE-AUTOML-FRAUDE-RUNBOOK.md](HEATWAVE-AUTOML-FRAUDE-RUNBOOK.md).

## 08/08/2026 — Validação dos casos agênticos no HeatWave real

### Escopo

- investigação de caso;
- triagem por regras transparentes;
- descoberta de padrões;
- dossiê analítico;
- compliance por RAG;
- governança de AutoML;
- cadeia de follow-up e memória da sessão.

### Resultado

- Dados e agregações principais reconfirmados ao vivo no MySQL HeatWave.
- 96 testes automatizados continuam aprovados.
- Investigação assistida, triagem por regras e descoberta de padrões são viáveis com a base atual.
- Foram encontradas quatro falhas prioritárias antes do modo ao vivo: views públicas ausentes, narrativa fixa no histórico do cliente, interrupção da cadeia estabelecimento para caso e similaridade fixa na transação `75466`.
- Na data desta validação, RAG e AutoML ainda eram extensões futuras. Esse estado
  foi superado pelo pipeline AutoML concluído em 10/08/2026; a integração do
  score ao chat, porém, continua pendente.

Relatório detalhado: [VALIDACAO-CASOS-AGENTICOS.md](VALIDACAO-CASOS-AGENTICOS.md).

## 08/08/2026 — Linguagem orientada ao público de negócio

### Objetivo

Remover da experiência principal termos técnicos como `label 1` e `registros rotulados`, que não comunicavam claramente o significado dos dados para visitantes de negócio.

### Alterações

- KPI `Rotuladas` alterado para `Fraudes`.
- KPI `Taxa geral` alterado para `Taxa de fraude`.
- KPI `Merchants` alterado para `Estabelecimentos`.
- Resposta de total alterada para: `A base possui 9.651 transações fraudulentas em um total de 1.852.394 transações. A taxa de fraude é de 0,521%.`
- Comparações passaram a usar `transações legítimas` e `transações fraudulentas`.
- Tabelas agora exibem `Fraudes` e `Taxa de fraude`.
- O cartão de transação exibe `Fraudulenta` ou `Legítima`, em vez do valor numérico do label.
- Rankings passaram a falar diretamente em fraude por categoria, estabelecimento, cliente, estado e horário.
- A Mesa de Análise ganhou indicadores para total de transações, fraudes e taxa de fraude.
- A transparência sobre o dataset foi simplificada: a base é sintética e não contém clientes ou estabelecimentos reais.

## 17/08/2026 — Correção definitiva de permissões e propriedade do modelo na VM

### Diagnóstico

- A aplicação usava o usuário `febraban`, enquanto o modelo final havia sido
  treinado pelo usuário `admin` e estava no catálogo `ML_SCHEMA_admin`.
- Mesmo após acesso de leitura ao catálogo, `ML_PREDICT_TABLE` falhava no
  contexto do usuário da aplicação com `SELECT command denied ... MODEL_CATALOG`.
- A causa não era a UI nem um lock do cluster: era a propriedade do modelo.

### Correção aplicada

- Concedidos ao usuário `febraban` os privilégios oficiais de AutoML para os
  catálogos `ML_SCHEMA_admin` e `ML_SCHEMA_febraban`, além de `SELECT, EXECUTE`
  em `sys`.
- Concedidas as permissões documentadas de GenAI/Vector Store, incluindo as
  roles `mysql_task_user` e `mysql_task_admin`, `VECTOR_STORE_LOAD_EXEC` e as
  permissões de observabilidade e procedimentos de carga vetorial.
- O modelo final foi exportado pelo proprietário e importado no catálogo de
  `febraban`; a aplicação agora usa o handle da cópia pertencente ao usuário de
  serviço, definido somente no arquivo protegido da VM.
- O modelo permanece carregado no cluster sob o usuário `febraban`.

### Limite do serviço gerenciado

- A role `administrator` existe neste DB System e foi concedida ao usuário
  `febraban` como `DEFAULT ROLE`. A validação da conexão da aplicação retornou
  `CURRENT_ROLE() = administrator`.
- O usuário `admin` continua sendo a conta administradora inicial do DB System;
  para tarefas assíncronas, `mysql_task_admin` também permanece atribuída.
- A tentativa explícita de `GRANT ALL PRIVILEGES ON *.* ... WITH GRANT OPTION`
  foi recusada pela conta administradora do DB System gerenciado. Portanto, a
  role `administrator`, os grants por schema, catálogo e as roles documentadas
  constituem a elevação efetiva disponível para o usuário da aplicação.

### Validação

- `ML_PREDICT_TABLE` executado pelo usuário da aplicação: 10 linhas
  classificadas com sucesso em 1,16 s.
- API de saúde da aplicação: `database: ok` após o deploy.
- Nenhuma senha, endpoint privado ou handle operacional foi incluído nesta
  documentação.

### Referências oficiais

- [Privilégios do HeatWave AutoML](https://dev.mysql.com/doc/heatwave/en/hw-automl-privileges.html)
- [Compartilhar um modelo entre usuários](https://dev.mysql.com/doc/heatwave/en/mys-hwaml-model-sharing.html)
- [Roles e privilégios GenAI](https://dev.mysql.com/doc/heatwave/en/mys-hw-genai-privileges.html)

## 11/08/2026 — Resultados do modelo na simulação ao vivo

### Alterações

- Incluída a mesa **Transações classificadas** no dashboard, com cada evento que já recebeu predição do modelo.
- A tabela é ordenada pela maior probabilidade de fraude e exibe estabelecimento, categoria, praça, valor, score, faixa de risco e resultado da classificação.
- Implementada paginação no backend com `LIMIT`/`OFFSET` e 20 registros por página, evitando transferir dezenas de milhares de linhas para o navegador.
- Adicionados indicadores de classificação: transações pontuadas, alertas previstos, taxa de alerta e maior score observado.
- O painel de simulação agora sinaliza, durante a etapa de scoring, quantas transações já foram classificadas e oferece atalho direto para a mesa de resultados.
- Mantida a separação de carga: o dashboard atualiza durante a ingestão e a classificação é executada em blocos de 5.000 registros, sem bombardear o cluster com consultas concorrentes.

### Validação

- Build de TypeScript e Vite concluído com sucesso.
- API `/api/live?page=1` validada na versão atual, retornando o contrato de paginação (`page`, `pageSize`, `total`, `totalPages`).
- A execução anterior processou 50.000 transações sintéticas: 50.000 classificadas, 216 alertas previstos e 0 falhas de pontuação.

## 11/08/2026 — Medição ponta a ponta: ingestão e predição em lote

### Rodada controlada

- Meta: 50.000 transações sintéticas realistas.
- Ingestão: 100 lotes de 500 eventos, um lote por conexão, em cadência de aproximadamente um minuto.
- Predição: 10 checkpoints de 5.000 registros com `ML_PREDICT_TABLE`.

### Resultado medido no HeatWave

| Etapa | Duração |
| --- | ---: |
| Ingestão de 50.000 eventos | 60,466 s |
| Predição das 50.000 transações | 49,445 s |
| Fluxo total | 109,911 s |

- Registros inseridos: 50.000.
- Registros classificados: 50.000.
- Alertas previstos nesta rodada: 252.
- Falhas de inserção: 0.
- Falhas de scoring: 0.

Os tempos são específicos deste cluster e desta carga de demonstração; devem ser apresentados como evidência do laboratório, não como SLA de produção.

### Decisão técnica

O campo `dataset_fraud_label` permanece no schema e no SQL auditável. A tradução para linguagem de negócio acontece somente na camada de apresentação.

### Validação

- 96 testes aprovados de 96.
- Pergunta validada na interface: `No total, qual total de fraudes que ocorreram?`
- Resultado visual validado: `1.852.394` transações, `9.651` fraudes e taxa de `0,521%`.

## 08/08/2026 — Correção da intenção de total geral

### Problema

A pergunta `No total, qual total de fraudes que ocorreram?` era direcionada incorretamente para o ranking por categoria.

### Correção

- Criada intenção específica para totais gerais.
- Adicionada consulta agregada com `COUNT(*)`, `SUM(dataset_fraud_label)` e taxa percentual.
- Incluídas cinco formulações equivalentes na regressão automatizada.
- Corrigido suporte às variações `quantas` e `quantos`.

## 08/08/2026 — Validação aprofundada de linguagem natural

### Cobertura

- Perguntas analíticas simples e complexas.
- Erros de digitação e linguagem informal.
- Follow-ups dependentes do contexto da sessão.
- Perguntas sobre dados inexistentes.
- Perguntas fora do escopo.
- Tentativas de escrita e prompt injection.
- Relações SQL não autorizadas, subqueries, joins e unions.

### Resultado

- 86 avaliações de linguagem natural e comportamento.
- 7 testes do gateway SQL.
- 3 testes de memória e reset.
- 96 testes aprovados no total.

Relatório detalhado: [validacao-linguagem-natural.md](validacao-linguagem-natural.md).

## 08/08/2026 — Memória completa por sessão

### Alterações

- Histórico completo mantido em RAM por `sessionId`.
- Preservação de transação, cliente, estabelecimento, categoria, período e último SQL.
- Resolução de referências como `esse cliente`, `essa categoria` e `esse caso`.
- Resumo de toda a investigação da sessão.
- Contador visual de perguntas lembradas.
- Botão `Resetar demo` limpa chat, resultados e contexto.
- Sessões inativas expiram após 30 minutos.
- Nenhuma memória é persistida em banco.

## 07/08/2026 — Documento de compliance e preparação para RAG

### Artefatos

- Guia de compliance em Markdown, TXT, DOCX e PDF.
- Contrato semântico da base Sparkov.
- Política corporativa ilustrativa.
- Playbooks de investigação.
- Perguntas de regressão para RAG.
- Metadados e estratégia de segmentação documental.

### Estado atual

O documento está pronto para ingestão, mas o HeatWave Vector Store ainda não está conectado ao backend do chat. Até essa integração existir, o agente informa explicitamente que a base documental não está disponível.

## Limitações abertas

- O app está sendo executado em modo de demonstração.
- Consultas complexas novas precisam ser revalidadas no MySQL HeatWave real.
- HeatWave AutoML ainda não foi treinado.
- Ainda não há score, probabilidade ou explicabilidade de modelo.
- O RAG de compliance ainda não está integrado ao chat.
