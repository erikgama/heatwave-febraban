# 6. Construir e publicar a aplicação com apoio de um LLM

Este repositório não entrega código de aplicação. Use este prompt em Codex,
OpenCode ou outro assistente dentro do seu repositório privado:

```text
Crie uma SPA React e backend Node.js. Use exclusivamente app_readonly e views
fraud_demo_public. Não grave credenciais no código. Implemente: (1) dashboard
com consultas agregadas; (2) chat de dados via sys.NL_SQL com execute=false,
validação de SELECT, allowlist, LIMIT <=100, timeout e SQL exibido; (3) chat
documental via sys.ML_RAG com citações; e (4) scoring em lote de apenas cinco
features B1, persistido por run_id. Memória só na sessão, botão Resetar demo.
Nunca diga fraude confirmada para label ou score.
```

## Contratos sugeridos

| Rota | Entrada | Saída |
| --- | --- | --- |
| `GET /api/dashboard` | filtros permitidos | cards e séries |
| `POST /api/chat` | pergunta e sessão | resposta + SQL ou citações |
| `POST /api/live-runs` | parâmetros seguros | `runId` |
| `GET /api/live-runs/:runId` | paginação | progresso e scores |
| `GET /api/events/:id` | id validado | detalhe sem PII |

## Checklist de deploy

- segredos em Vault ou variáveis de runtime;
- TLS, pool mínimo e CORS restrito;
- input validation, rate limit e timeout;
- logs sem PII ou segredos;
- testes para DDL/DML, SQL multi-instrução e relações fora da allowlist;
- smoke tests de dashboard, NL SQL, RAG, scoring e reset;
- conectividade privada/controlada ao DB System.
