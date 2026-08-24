-- Aceite da fonte RAG ativa da demonstração FEBRABAN.
-- Execute como o usuário da aplicação (febraban), após a task de
-- 15_load_model_document_gpu_rev2.sql chegar a 100%.
-- Não use stores CPU/anteriores como padrão da demo.

SET SESSION use_secondary_engine = OFF;

SET @rag_options = JSON_OBJECT(
  'vector_store', JSON_ARRAY('febraban_rag.modelo_b1_v2_oci_embed_v4_rev2_20260823'),
  'embed_model_id', 'cohere.embed-v4.0',
  'n_citations', 6,
  'model_options', JSON_OBJECT(
    'model_id', 'meta.llama-3.3-70b-instruct',
    'language', 'pt'
  )
);

-- Esperado: 0,60 é o threshold operacional; 0,27 é apenas referência histórica.
CALL sys.ML_RAG(
  'Qual é o threshold operacional da simulação e como ele difere de 0,27 histórico?',
  @threshold_answer,
  @rag_options
);
SELECT JSON_PRETTY(@threshold_answer) AS threshold_answer;

-- Esperado: exatamente as 7 features abaixo; is_fraud não é enviado.
CALL sys.ML_RAG(
  'Quais são exatamente as sete features usadas na inferência e is_fraud é enviado ao modelo?',
  @features_answer,
  @rag_options
);
SELECT JSON_PRETTY(@features_answer) AS features_answer;
