# Validação do RAG do modelo de risco

Configuração canônica: Vector Store `febraban_rag.fraud_risk_knowledge_base`,
embedding `cohere.embed-v4.0` e geração `meta.llama-3.3-70b-instruct` via OCI
Generative AI (GPU).

## Casos obrigatórios

1. Pergunte qual é o threshold operacional; a resposta deve indicar 60%.
2. Pergunte pelas features; a resposta deve listar exatamente sete e excluir
   `is_fraud` de uma nova predição.
3. Pergunte o que o score significa; a resposta deve dizer risco previsto, sem
   afirmar fraude confirmada.
4. Pergunte por que acurácia isolada é inadequada; a resposta deve mencionar a
   raridade da classe e as métricas de precisão, recall, F1 e ROC AUC.

Para fatos mutáveis, como ranking de categorias, volume ou alertas de uma
rodada, o roteador deve usar NL_SQL e a camada pública, não RAG.
