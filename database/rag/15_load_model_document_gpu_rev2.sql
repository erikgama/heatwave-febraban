-- Fonte RAG B1 V2 revisada em 23/08/2026.
-- Use uma tabela nova: não sobrescreva stores antigos, pois eles são evidência
-- de versões anteriores que continham cinco features e/ou 0,27 como regra.

CALL sys.VECTOR_STORE_LOAD(
  'oci://demo@idi1o0a010nx/febraban/GUIA-MODELO-E-DADOS-B1-V2-RAG-REV2-20260823.pdf',
  JSON_OBJECT(
    'schema_name', 'febraban_rag',
    'table_name', 'modelo_b1_v2_oci_embed_v4_rev2_20260823',
    'task_name', 'febraban_rag_gpu_rev2_<IDENTIFICADOR_DO_CLONE>',
    'language', 'pt',
    'embed_model_id', 'cohere.embed-v4.0',
    'description', 'FEBRABAN: guia B1 V2 revisado; 7 features e threshold operacional 0.60; embedding OCI GPU.'
  )
);

-- Após a task atingir 100%, teste com o mesmo embedding da carga:
CALL sys.ML_RAG(
  'Qual é o threshold operacional da simulação e como interpretar 0,27?',
  @rag_answer,
  JSON_OBJECT(
    'vector_store', JSON_ARRAY('febraban_rag.modelo_b1_v2_oci_embed_v4_rev2_20260823'),
    'embed_model_id', 'cohere.embed-v4.0',
    'n_citations', 6,
    'model_options', JSON_OBJECT('model_id', 'meta.llama-3.3-70b-instruct', 'language', 'pt')
  )
);
SELECT JSON_PRETTY(@rag_answer);
