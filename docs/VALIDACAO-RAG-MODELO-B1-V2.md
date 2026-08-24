# Validação RAG - modelo B1 V2

> **Histórico e substituição:** esta página preserva evidências de testes de
> 10–11/08/2026, inclusive stores CPU e versões GPU que descreviam cinco
> features. Elas não são a configuração da demo atual. Para implantação, use
> somente `database/rag/15_load_model_document_gpu_rev2.sql` e a validação
> `database/rag/16_validate_gpu_rev2.sql`.

## Configuração vigente — revisão 23/08/2026

| Item | Configuração aprovada |
| --- | --- |
| PDF | `GUIA-MODELO-E-DADOS-B1-V2-RAG-REV2-20260823.pdf` |
| Origem | `oci://demo@idi1o0a010nx/febraban/GUIA-MODELO-E-DADOS-B1-V2-RAG-REV2-20260823.pdf` |
| Vector Store | `febraban_rag.modelo_b1_v2_oci_embed_v4_rev2_20260823` |
| Embedding | `cohere.embed-v4.0`, OCI Generative AI (GPU) |
| Geração | `meta.llama-3.3-70b-instruct`, OCI Generative AI (GPU) |
| Contrato documentado | sete features; `is_fraud` não é entrada de inferência |
| Regra da simulação | alerta previsto em `fraud_probability >= 0.60` |

A revisão foi carregada e validada com o usuário `febraban` nos três DB
Systems do laboratório. As perguntas de aceite são: (1) “Qual é o threshold
operacional e como ele difere de 0,27?” e (2) “Quais são exatamente as sete
features e `is_fraud` é enviado?”. Ambas precisam retornar citações do PDF
REV2. O valor `0,27` permanece apenas como referência de validação histórica,
nunca como regra do dashboard.

---

## Evidência histórica — 10/08/2026

## Carga concluída

| Item | Evidência |
| --- | --- |
| MySQL HeatWave | `9.7.2-cloud` |
| Fonte | `oci://demo@idi1o0a010nx/febraban/GUIA-MODELO-E-DADOS-B1-V2-RAG.pdf` |
| Modelo de embedding | `cohere.embed-multilingual-v3.0` via OCI GenAI, Chicago |
| Opções de ingestão | padrões do `VECTOR_STORE_LOAD` para PDF, idioma `pt` |
| Task | `0ad03b1c-951b-11f1-9bc3-02001703da6b` |
| Status | `COMPLETED`, 100% |
| Vector Store | `febraban_rag.modelo_b1_v2_oci_chicago_pdf` |
| Segmentos | 14 |
| Tipo de vetor | `VECTOR(6000)` |

## Teste de recuperação

O documento contém corretamente o trecho B1 no segmento 7:

```text
Selecionadas na execução: amount, amount_log, category,
customer_merchant_distance_km, transaction_hour
```

Uma primeira chamada de `ML_RAG` com geração nativa, porém, recuperou trechos
menos relevantes sobre B2 e afirmou incorretamente que as features B2 foram
usadas no B1. Portanto, a ingestão e os embeddings foram validados, mas essa
geração nativa não está aprovada como resposta final da demonstração.

## Validação ponta a ponta com ML_RAG e modelo GPU

Em 11/08/2026 foram executadas quatro chamadas reais de `sys.ML_RAG`, usando
o mesmo Vector Store, recuperação semântica e por palavra-chave, oito citações
e o gerador OCI GPU `meta.llama-3.3-70b-instruct`. As respostas foram
persistidas em `febraban_rag.ml_rag_validation_gpu`.

| Caso | Resultado | Verificação |
| --- | --- | --- |
| Features efetivamente selecionadas | Aprovado | Retornou exatamente `amount`, `amount_log`, `category`, `customer_merchant_distance_km` e `transaction_hour`; não citou B2. |
| Threshold e métricas | Aprovado | Informou threshold `0,27`, desbalanceamento de aproximadamente `0,521%` e priorização de precisão, recall, F1 e ROC AUC. |
| Contrato de nova predição | Aprovado | Informou os cinco campos, excluiu `is_fraud` e explicou `amount_log = LN(1 + amount)`. |
| Limite de B2 | Aprovado | Confirmou que B2 foi preparado, não entrou no B1 e não explica o score atual. |

O caso anterior com o gerador nativo padrão continua reprovado e documentado
como referência. A aprovação acima é específica para a configuração GPU de
`ML_RAG`; ela não transforma uma resposta do LLM em fonte de verdade. As
citações recuperadas e a tabela de auditoria permanecem a evidência.

Script reproduzível: `database/rag/04_validate_ml_rag_gpu.sql` (caso de
features) e `database/rag/05_validate_ml_rag_gpu_cases.sql` (três casos
adicionais).

## Decisão de arquitetura

Para a demo, o MySQL HeatWave pode responder perguntas documentais diretamente
com `ML_RAG` na configuração GPU validada, desde que a aplicação:

1. mantenha o modelo, Vector Store e opções de recuperação fixados;
2. exiba as citações recuperadas e registre pergunta/resposta para auditoria;
3. envie perguntas de fatos atuais para SQL de leitura, não para o RAG;
4. mantenha o Codex no OpenCode como orquestrador: escolhe entre `ML_RAG`,
   SQL de leitura e simulação de score, e preserva o contexto da sessão.

Assim, o RAG do HeatWave fornece contexto privado e auditável; o Codex realiza
a síntese em linguagem natural com guardrails. A pergunta de regressão deve
ser: “Liste exatamente as cinco features selecionadas no B1 V2. Não cite
features B2.” A resposta esperada é:

```text
amount, amount_log, category,
customer_merchant_distance_km, transaction_hour
```

## Próximo passo

Implementar a ferramenta `consultar_documentacao_modelo` no OpenCode para
chamar `ML_RAG` com esta configuração aprovada e mostrar citações. Antes de
liberar cada nova versão do documento, modelo ou configuração, repetir os
quatro casos de regressão desta página e aprovar somente se todos mantiverem
o gabarito técnico.

## Bateria ampliada de 30 perguntas

O roteiro com 30 perguntas e respectivos gabaritos foi preparado em
`database/rag/06_run_ml_rag_gpu_regression_30.sql`. Ele cobre features,
dados, transformações, treino, validação, métricas, contrato de predição e
governança.

Em 11/08/2026 a primeira execução da bateria foi interrompida antes de gravar
qualquer resultado: a chamada ficou mais de três minutos na etapa interna
`embed_row`. A investigação confirmou duas operações B2 concorrentes no
cluster: um `ML_TRAIN` sobre `fraud_ml.features_manual_b2_dev_v2` e um
`ALTER TABLE ... SECONDARY_LOAD` para essa mesma tabela, aguardando `System
lock`. O catálogo também mostrou duas tentativas B2 ainda sem `model_type`,
consistente com treino ainda não concluído. A recuperação SQL do RAG (vetorial
e BM25) continuou rápida; a espera ocorreu antes da geração, na operação de
embedding remoto. Isso indica contenção operacional do cluster/serviço de ML,
e não defeito no PDF, nos 14 segmentos ou nos gabaritos.

As operações B2 não foram alteradas. A consulta de teste foi cancelada e a
conexão encerrada; nenhum registro parcial foi inserido em
`ml_rag_regression_results`. A bateria deve ser executada quando essa
contenção não estiver presente.

### Reteste após limpeza do B2

O `ML_TRAIN` e o `SECONDARY_LOAD` B2 foram posteriormente cancelados. O
cluster permaneceu saudável (`STATUS = AVAIL_RNSTATE`, `ML_STATUS =
AVAIL_MLSTATE`) e a configuração `rapid_ml_genai` continuou habilitada para
OCI GenAI em `us-chicago-1` por `resource_principal`. Mesmo assim, uma nova
chamada de `ML_RAG`, inclusive com `semantic_search = false` e
`keyword_search = true`, voltou a parar em `embed_row` antes de produzir
resposta. Logo, B2 era uma contenção concorrente, mas não a causa única.

Neste estado, a hipótese operacional mais consistente é falta de retorno na
chamada remota GenAI de embedding acionada internamente pelo `ML_RAG`. Não há
erro SQL ou falha de vetor registrada pelo banco; portanto não é correto
atribuir a causa a PDF, chunking ou ao modelo de geração GPU sem evidência
adicional. A bateria de 30 permanece preparada e deve ser reexecutada quando
essa chamada voltar a responder.

## Configuração aprovada: embedding CPU e geração GPU

A revisão da sintaxe oficial mostrou que o erro operacional vinha de forçar
`cohere.embed-multilingual-v3.0` para gerar o embedding de cada pergunta. Foi
criado um Vector Store separado, sem alterar o store OCI existente:

| Componente | Configuração aprovada |
| --- | --- |
| Fonte | `GUIA-MODELO-E-DADOS-B1-V2-RAG.pdf` no Object Storage |
| Vector Store | `febraban_rag.modelo_b1_v2_cpu_e5_pdf` |
| Embedding da consulta e dos segmentos | `multilingual-e5-small` embarcado no HeatWave |
| Gerador | `meta.llama-3.3-70b-instruct` em GPU OCI |
| Recuperação | 8 citações, com a configuração padrão de busca semântica |

O carregamento CPU foi concluído pela task
`497c9005-9529-11f1-9bc3-02001703da6b` (100%). A chamada mínima, somente com
`vector_store`, funcionou, mas o gerador padrão retornou features incorretas.
Com o gerador GPU maior e o mesmo store CPU, a resposta passou a recuperar e
responder corretamente.

## Regressão de 30 perguntas: aprovada

Em 11/08/2026 foram executadas 30 chamadas **independentes** de `ML_RAG`, uma
por conexão, com batch `a276bd3a-2ae7-40b0-9a90-1b002021f21a`. Cada resultado
foi persistido em `febraban_rag.ml_rag_regression_results` com pergunta,
gabarito, resposta e oito citações.

| Escopo | Casos | Resultado |
| --- | ---: | --- |
| Features e limites B2 | 1–4 | 4/4 corretos |
| Base e splits | 5–11 | 7/7 corretos |
| Transformações | 12–15 | 4/4 corretos |
| Treinamento e validação temporal | 16–20 | 5/5 corretos |
| Métricas | 21–27 | 7/7 corretos |
| Predição e arquitetura do agente | 28–30 | 3/3 corretos |
| **Total** | **30** | **30/30 corretos** |

O resultado valida a configuração para perguntas documentais da demo. Ela não
substitui SQL para fatos atuais e não autoriza chamar um rótulo sintético de
fraude confirmada.

## Experimento OCI Embed 4 (não aprovado para a demo)

Foi criado um terceiro Vector Store para testar um modelo de embedding da OCI
Generative AI: `febraban_rag.modelo_b1_v2_oci_embed_v4_gpu_pdf`, usando
`cohere.embed-v4.0`. A carga foi concluída em 100% pela task
`b34ea979-952b-11f1-9bc3-02001703da6b`.

O modelo é compatível com HeatWave, está disponível no catálogo do DB System,
é multilíngue e é atendido pela OCI Generative AI em Chicago. A infraestrutura
de execução da OCI é gerenciada pelo serviço; o HeatWave não expõe a GPU física
ou um indicador de GPU por chamada.

No primeiro caso de regressão (as cinco features B1), tanto a recuperação
semântica quanto a híbrida recuperaram trechos B2 e não retornaram o segmento
7 com a lista correta. A geração Llama 70B respondeu incorretamente no teste
semântico e respondeu que a lista não foi encontrada no híbrido. Portanto:

| Store | Embedding | Resultado no caso 1 |
| --- | --- | --- |
| `modelo_b1_v2_cpu_e5_pdf` | `multilingual-e5-small` embarcado | Aprovado |
| `modelo_b1_v2_oci_embed_v4_gpu_pdf` | `cohere.embed-v4.0` via OCI GenAI | Reprovado |

O store OCI Embed 4 foi preservado apenas para comparação. A demo continua
apontando para o store CPU/e5, que passou nos 30 casos.

## Fonte documental corrigida para a demo

O guia RAG foi revisado para remover referências a uma evolução B2 que não faz
parte do case apresentado. A versão PDF corrigida foi publicada no Object
Storage como `febraban/GUIA-LABORATORIO-FEBRABAN-HEATWAVE-RAG-v2.pdf` e
ingerida no store `febraban_rag.guia_laboratorio_febraban_cpu_e5_v2` pela task
`c7e60f16-952d-11f1-9bc3-02001703da6b` (100%).

Um teste `ML_RAG` sobre esse novo store retornou corretamente as cinco features
B1: `amount`, `amount_log`, `category`,
`customer_merchant_distance_km` e `transaction_hour`.
