-- Fonte RAG vigente: B1 V2 com threshold operacional único de 0.60.
-- Carregue o PDF REV3 no Object Storage antes de executar.

CALL sys.VECTOR_STORE_LOAD(
  'oci://demo@idi1o0a010nx/febraban/GUIA-MODELO-E-DADOS-B1-V2-RAG-REV3-20260823.pdf',
  JSON_OBJECT(
    'schema_name', 'febraban_rag',
    'table_name', 'modelo_b1_v2_oci_embed_v4_rev3_20260823',
    'task_name', 'febraban_rag_gpu_rev3_<IDENTIFICADOR_DO_CLONE>',
    'language', 'pt',
    'embed_model_id', 'cohere.embed-v4.0',
    'description', 'FEBRABAN: B1 V2, sete features e threshold operacional unico 0.60; embedding OCI GPU.'
  )
);

-- Após a task atingir 100%, execute a validação 18_validate_gpu_rev3.sql.
