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
CREATE SCHEMA IF NOT EXISTS febraban_rag;
SET @options=JSON_OBJECT('schema_name','febraban_rag','table_name','modelo_b1_docs',
 'language','pt','embed_model_id','cohere.embed-v4.0',
 'formats',JSON_ARRAY('pdf'),
 'chunking',JSON_OBJECT('split_by','recursive'));
CALL sys.VECTOR_STORE_LOAD(
 'oci://SEU_BUCKET@SEU_NAMESPACE/febraban/documento-modelo-rag.pdf', @options);
```

`VECTOR_STORE_LOAD` é assíncrono e devolve uma consulta de status. Use a query
retornada pela sua execução e, ao concluir, valide:

```sql
SHOW TABLES FROM febraban_rag LIKE 'modelo_b1_docs%';
```

Em algumas versões, o carregador acrescenta um sufixo referente ao formato do
arquivo. Copie o nome realmente retornado e use-o nos comandos seguintes; não
presuma que a tabela se chama exatamente `modelo_b1_docs`.

Use o mesmo embedding para documento e consulta. Neste laboratório, o embedding
ativo é `cohere.embed-v4.0` no OCI Generative AI (GPU); não use os stores
históricos com `multilingual-e5-small` como fonte da demo.

## Consultar RAG

```sql
SET @rag_options=JSON_OBJECT(
 'vector_store',JSON_ARRAY('febraban_rag.NOME_REAL_DA_TABELA'),
 'embed_model_id','cohere.embed-v4.0',
 'n_citations',5,
 'model_options',JSON_OBJECT('model_id','meta.llama-3.3-70b-instruct')
);
CALL sys.ML_RAG('Quais features o modelo B1 usa?',@answer,@rag_options);
SELECT JSON_PRETTY(@answer);
```

Adapte opções à sua versão e confira a sintaxe de `ML_RAG` na documentação
oficial. A resposta deve ter citações/trechos, não só texto gerado. Teste
dataset, features, target, separação, métricas, threshold e limitações.
