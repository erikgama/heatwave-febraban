# NL to SQL nativo do MySQL HeatWave

## Objetivo

Permitir que o visitante pergunte em português sobre a base e veja três
elementos auditáveis na mesma conversa:

1. SQL gerado pelo `sys.NL_SQL` a partir da pergunta.
2. Resultado do `SELECT` executado sobre a camada pública.
3. Resposta curta em português montada de forma determinística somente a
   partir das linhas retornadas.

Não há acesso de escrita no fluxo do visitante.

## Rotinas nativas usadas

- `sys.NL_SQL` é a rotina de linguagem natural para SQL do HeatWave. Ela está
  disponível a partir do MySQL HeatWave 9.4.1 e gera/executa apenas `SELECT`.
  Na aplicação, a opção `execute` é sempre `false`; portanto, a rotina não
  executa por conta própria o SQL gerado.
- A aplicação não chama `sys.ML_GENERATE` para reescrever o resultado do
  NL_SQL. O resumo é determinístico e baseado na evidência retornada; isso
  reduz latência e evita disputar conexões/recursos GenAI durante a demo.

Documentação oficial: [NL_SQL](https://dev.mysql.com/doc/heatwave/en/mys-hw-genai-nl-sql.html).

## Fluxo implementado

```text
Pergunta do visitante
  -> bloqueio de instruções perigosas e perguntas fora de escopo
  -> sys.NL_SQL(..., execute=false, tables=[views públicas])
  -> validação independente do SQL gerado
  -> SELECT com timeout e LIMIT
  -> resumo determinístico da evidência limitada
  -> resposta, tabela, visualização e SQL auditável na tela
```

O NL_SQL recebe somente estas views do schema `fraud_demo_public`:

- `v_transactions_investigation`
- `v_category_summary`
- `v_merchant_summary`
- `v_state_summary`
- `v_live_transaction_events`

Assim, metadados da tabela bruta, tabelas de sistema e qualquer outro schema
não entram no contexto de geração.

`v_fraud_predictions` existe no schema público, porém contém predições
históricas do modelo V1 e threshold 0,33. Ela não integra a allowlist atual do
NL_SQL, para não misturar esse histórico com o B1 V2 e a regra operacional de
60% usada na simulação.

## Roteamento unificado: SQL, RAG e memória

O chat tem uma única caixa de conversa, mas decide a fonte de verdade antes de
consultar o HeatWave:

| Pergunta do visitante | Fonte | Evidência mostrada |
| --- | --- | --- |
| Totais, rankings, filtros, clientes, transações e tendências atuais | `sys.NL_SQL` + `SELECT` validado | SQL exato, tabela e gráfico |
| Features, treino B1, métricas, threshold, limitações, compliance e governança | `sys.ML_RAG` | Documento, segmentos recuperados e distância semântica |
| “E por que isso?” após uma resposta documental | `sys.ML_RAG` com memória de sessão | Novas citações documentais |

A memória é mantida apenas em RAM durante a sessão. Ela armazena as últimas
mensagens e entidades ativas (caso, cliente, categoria e período) para resolver
referências; não entra como fato no SQL e não substitui os trechos recuperados
do RAG. O botão **Resetar conversa**, atualizar a página ou reiniciar o servidor
apaga esse contexto.

Configuração do RAG validada:

```bash
USE_HEATWAVE_RAG=true
HEATWAVE_RAG_VECTOR_STORE=febraban_rag.modelo_b1_v2_oci_embed_v4_rev2_20260823
HEATWAVE_RAG_EMBED_MODEL=cohere.embed-v4.0
```

O Vector Store usa `cohere.embed-v4.0` via OCI Generative AI (GPU) tanto para
os segmentos quanto para a pergunta e `meta.llama-3.3-70b-instruct` para geração.
O backend manda a pergunta atual,
um resumo seguro da memória e instruções para não tratar a memória como fonte
documental.

## Guardrails do gateway

O fato de o NL_SQL gerar somente `SELECT` não substitui controles da aplicação.
Depois da geração, o backend exige:

- início em `SELECT` ou `WITH ... SELECT`;
- uma view da allowlist pública;
- nenhuma relação fora da allowlist;
- nenhuma instrução múltipla, comentário, escrita, DDL, `CALL`, acesso ao
  schema bruto ou funções caras/perigosas;
- máximo de 100 linhas; quando não há `LIMIT`, o gateway acrescenta `LIMIT 25`;
- `max_execution_time` de 10 segundos na execução da consulta gerada.

Perguntas de compliance/RAG, explicabilidade do modelo, dados inexistentes e
ações destrutivas ficam no roteador protegido e não são encaminhadas ao NL_SQL.

## Configuração

```bash
USE_HEATWAVE_NL_SQL=true
HEATWAVE_NL_SQL_MODEL=meta.llama-3.3-70b-instruct
```

`meta.llama-3.3-70b-instruct` é o modelo maior hospedado no OCI Generative AI,
servido por GPU, escolhido para a demonstração e usado para gerar SQL no
`NL_SQL`. O fallback local
`llama3.2-3b-instruct-v1` pode ser usado apenas em testes sem acesso ao serviço
OCI. Para desativar a integração nativa sem remover o fallback curado, defina
`USE_HEATWAVE_NL_SQL=false`.

## Guia entregue ao modelo

Além do catálogo técnico passado pelo HeatWave, a aplicação envia um prompt de
negócio versionado em `src/server/nl-sql-guidance.ts`. Ele instrui o modelo a:

- usar somente as cinco views públicas permitidas e nunca inventar campos ou tabelas;
- distinguir `COUNT(*)` de `SUM(dataset_fraud_label)`;
- tratar o rótulo 1 como histórico e sintético, sem alegar fraude confirmada;
- reconhecer que cidade/estado são residência do cliente;
- recusar perguntas que dependam de produto, IP, dispositivo, cartão, canal ou
  causa, pois esses atributos não existem na base;
- escolher a view e a métrica corretas para ranking por volume, quantidade
  rotulada ou taxa rotulada; e
- aplicar contexto de categoria, estabelecimento, cliente e período apenas em
  perguntas de acompanhamento compatíveis.

## Privilégio mínimo do usuário de demonstração

O usuário `febraban` já deve manter somente `SELECT, SHOW VIEW` nos schemas
`fraud_demo` e `fraud_demo_public`. Para chamar as duas rotinas sem elevar seu
acesso aos dados, o administrador precisa adicionar apenas:

```sql
GRANT EXECUTE ON PROCEDURE sys.NL_SQL TO 'febraban'@'%';
GRANT EXECUTE ON PROCEDURE sys.ML_RAG TO 'febraban'@'%';
```

Não conceder `INSERT`, `UPDATE`, `DELETE`, `CREATE`, `ALTER`, `DROP`, acesso a
`information_schema`, nem acesso ao schema bruto. O `NL_SQL` continua vendo
apenas os objetos que o usuário pode ler e a aplicação ainda restringe a
geração às views acima.

## Validação realizada em 12/08/2026

- DB System: `9.7.2-cloud`.
- Rotina analítica disponível: `sys.NL_SQL`.
- Modelo GPU validado: `meta.llama-3.3-70b-instruct`.
- `NL_SQL` gerou e validou o `SELECT` abaixo com `execute=false` e acesso
  somente à view pública indicada.
- Pergunta: “Quais categorias possuem maior taxa de transações rotuladas?”.
- SQL gerado e aceito pelo gateway:

```sql
SELECT `category`, `labeled_fraud_pct`
FROM `fraud_demo_public`.`v_category_summary`
ORDER BY `labeled_fraud_pct` DESC
LIMIT 25
```

- Resultado: 14 categorias; tempo do `SELECT`: 2.870 ms.
- Resposta do gerador: `shopping_net` e `misc_net` lideraram no recorte, com
  1,593 e 1,304 de taxa de transações rotuladas, respectivamente.

O texto produzido pelo modelo recebe instruções explícitas para tratar os
rótulos como históricos e sintéticos. O backend também sanitiza termos que
tentem transformar um rótulo em confirmação, culpa ou probabilidade.
