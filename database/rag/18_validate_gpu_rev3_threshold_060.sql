-- Aceite da fonte RAG vigente. Execute como febraban após a carga chegar a 100%.
SET SESSION use_secondary_engine = OFF;

SET @rag_options = JSON_OBJECT(
  'vector_store', JSON_ARRAY('febraban_rag.modelo_b1_v2_oci_embed_v4_rev3_20260823'),
  'embed_model_id', 'cohere.embed-v4.0',
  'n_citations', 6,
  'model_options', JSON_OBJECT('model_id', 'meta.llama-3.3-70b-instruct', 'language', 'pt')
);

CALL sys.ML_RAG(
  'Qual é o threshold operacional único para gerar um alerta de risco?',
  @threshold_answer,
  @rag_options
);
SELECT JSON_PRETTY(@threshold_answer) AS threshold_answer;

CALL sys.ML_RAG(
  'Quais são exatamente as sete features usadas na inferência e is_fraud é enviado ao modelo?',
  @features_answer,
  @rag_options
);
SELECT JSON_PRETTY(@features_answer) AS features_answer;
