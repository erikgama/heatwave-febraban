# Acesso temporário do laboratório

Copie este arquivo para `LAB-ACCESS.md` na raiz do projeto. O arquivo final é
ignorado pelo Git e deve existir apenas no notebook do participante.

```text
MYSQL_HOST=COLE_O_IP_OU_HOST_DO_DB_SYSTEM
MYSQL_PORT=3306
MYSQL_USER=COLE_O_USUARIO_DO_LABORATORIO
MYSQL_PASSWORD=COLE_A_SENHA_TEMPORARIA
MYSQL_DATABASE=fraud_demo_public
MYSQL_SSL=false

# Opcional: recursos já provisionados no DB System.
HEATWAVE_MODEL_HANDLE=HANDLE_DO_MODELO
HEATWAVE_RAG_VECTOR_STORE=VECTOR_STORE_DO_DOCUMENTO
```

Nunca coloque valores reais neste arquivo de exemplo. O Codex recebe essa
regra no `AGENTS.md`: pode ler o `LAB-ACCESS.md` local para conectar, mas não
deve mostrar ou versionar as credenciais.
