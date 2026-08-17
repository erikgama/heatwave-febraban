---
layout: default
title: RAG documental
---

# 5. Vetorizar documentação e usar ML_RAG

Use [DOCUMENTO-MODELO-PARA-RAG.md](DOCUMENTO-MODELO-PARA-RAG.md) como fonte
canônica. Exporte-o para PDF com seu editor e envie ao Object Storage:

```text
oci://SEU_BUCKET@SEU_NAMESPACE/febraban/documento-modelo-rag.pdf
```

Configure Resource Principal ou mecanismo autorizado para o DB System acessar
o bucket. Não torne o bucket público por conveniência.

## Criar Vector Store

```sql
CREATE SCHEMA IF NOT EXISTS fraud_rag;
SET @options=JSON_OBJECT('schema_name','fraud_rag','table_name','modelo_b1_docs',
 'language','pt','embed_model_id','multilingual-e5-small',
 'chunking',JSON_OBJECT('split_by','recursive'));
CALL sys.VECTOR_STORE_LOAD(
 'oci://SEU_BUCKET@SEU_NAMESPACE/febraban/documento-modelo-rag.pdf', @options);
```

`VECTOR_STORE_LOAD` é assíncrono e devolve uma consulta de status. Use a query
retornada pela sua execução e, ao concluir, valide:

```sql
SELECT COUNT(*) AS segmentos FROM fraud_rag.modelo_b1_docs;
DESCRIBE fraud_rag.modelo_b1_docs;
```

Use o mesmo embedding para documento e consulta. Confirme modelos suportados na
sua região antes de escolher opções OCI/GPU.

## Consultar RAG

```sql
CALL sys.ML_RAG('Quais features o modelo B1 usa?',@answer,
 JSON_OBJECT('vector_store','fraud_rag.modelo_b1_docs',
 'model_id','meta.llama-3.3-70b-instruct','n_citations',5));
SELECT @answer;
```

Adapte opções à sua versão e confira a sintaxe de `ML_RAG` na documentação
oficial. A resposta deve ter citações/trechos, não só texto gerado. Teste
dataset, features, target, separação, métricas, threshold e limitações.
