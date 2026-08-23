# Paridade local e VM — Chat da demonstração

Data da última validação: **18/08/2026**.

Este documento define o estado mínimo que deve existir tanto no diretório local
do projeto quanto na VM que serve a demonstração. O objetivo é evitar que uma
correção validada localmente não seja publicada, ou que uma alteração aplicada
na VM não esteja representada no código-fonte.

## Correções que devem existir nos dois ambientes

1. **Catálogo NL-to-SQL aderente ao banco**
   - O catálogo contém somente as views existentes em `fraud_demo_public`:
     `v_transactions_investigation`, `v_category_summary`,
     `v_merchant_summary` e `v_state_summary`.
   - Não usar `v_hour_summary`, `v_customer_summary`,
     `v_label_comparison` ou `v_daily_summary` enquanto essas views não forem
     efetivamente publicadas.
   - Agregações por horário, cliente, período e comparação de rótulos usam
     `v_transactions_investigation`.

2. **Sugestões analíticas usam NL-to-SQL nativo**
   - As cinco sugestões que investigam dados (categoria, horário,
     estabelecimento, detalhe de transação e comparação) passam por
     `sys.NL_SQL`. A rotina gera o `SELECT`; o gateway valida o SQL somente
     leitura antes de executá-lo.
   - “O que esta base não permite concluir?” é uma resposta de governança do
     schema, sem SQL: ela não deve inventar campos ausentes nem simular uma
     consulta para uma limitação conhecida.
   - O resumo de um resultado NL-to-SQL é determinístico e baseado nas linhas
     retornadas. Não chamar `ML_GENERATE` apenas para reescrever um resultado
     pequeno, pois isso pode reter conexões durante uma indisponibilidade do
   serviço GenAI.

### Evidência de validação na VM — 18/08/2026

Com `meta.llama-3.3-70b-instruct`, as cinco sugestões analíticas retornaram
origem `MySQL HeatWave · NL_SQL` e SQL efetivamente gerado pelo HeatWave:

- categoria: 5,0 s;
- horário: 8,6 s;
- estabelecimentos: 5,0 s;
- transação 75466: 3,0 s;
- comparação de rótulos: 4,8 s.

Esses tempos incluem a geração NL-to-SQL, a validação do `SELECT` e a execução
no banco. A pergunta de limitação de schema não executa SQL por desenho.

3. **Memória de sessão sem filtro oculto**
   - Contexto de categoria só pode ser aplicado quando o visitante usar uma
     referência explícita, como “dessa categoria”.
   - Uma nova pergunta genérica sobre horários ou estabelecimentos sempre
     consulta a base inteira, ainda que a pergunta anterior tenha aberto uma
     categoria.

4. **Linguagem segura para o dataset**
   - `dataset_fraud_label = 1` é apresentado como **rótulo histórico
     sintético**, não como confirmação de fraude real.
   - Alertas provenientes do modelo são risco previsto; não representam prova,
     culpa ou causalidade.

## Bateria de aceitação

Executar em uma única sessão, nesta ordem:

1. `Qual categoria tem mais fraudes?`
2. `Em quais horários acontecem mais fraudes?`
3. `Quais estabelecimentos têm maior taxa de fraude?`
4. `Abra o caso da transação 75466.`
5. `Compare transações legítimas e fraudulentas.`
6. `O que esta base não permite concluir?`

Resultados de referência:

| Pergunta | Resultado esperado |
|---|---|
| Categoria | `grocery_pos`, 2.228 registros rotulados em 176.191 transações. |
| Horários | 22h: 2.481 (2,601%); 23h: 2.442 (2,546%). |
| Estabelecimentos | Kozey-Boehm: 60 em 2.758, taxa de 2,175%. |
| Caso 75466 | `shopping_net`, 1.024,04 unidades monetárias, 23h, Hovland/MN e rótulo histórico 1. |
| Comparação | Rótulo 1: média 530,66; sem rótulo: 67,65. |
| Limitações | Sem produto/SKU, moeda, canal, IP, dispositivo, autenticação, localização do estabelecimento ou causalidade. |

## Validação local

No diretório do projeto:

```bash
npm test
npm run build
```

Critério atual: **109 testes aprovados** e build concluída. O build gera a
pasta `dist/`, que é o único artefato publicado na VM.

## Publicação e validação na VM

1. Publicar a pasta `dist/` validada; preservar a versão anterior antes da
   troca.
2. Reiniciar `febraban-fraud-copilot`.
3. Confirmar saúde local da aplicação:

```bash
sudo systemctl is-active febraban-fraud-copilot
curl -fsS http://127.0.0.1:8787/api/health
```

4. Executar a bateria de aceitação pela API e, em seguida, clicar nas seis
   sugestões na interface pública. Nas cinco perguntas analíticas, confirmar
   a origem `MySQL HeatWave · NL_SQL` e o SQL exibido.
5. Resetar a sessão de teste ao final para não deixar contexto residual.

## Estado validado em 18/08/2026

- Código-fonte local corrigido e build concluída.
- Build publicada na VM e serviço `active`.
- Health retornou `database: ok`.
- As seis perguntas foram executadas em sequência pela API e pela interface.
- Não houve travamento, erro de view inexistente nem herança indevida de
  categoria entre perguntas.

## Validação sob carga da simulação

Também foi executado o percurso completo pela interface pública, antes da
bateria de aceitação:

1. iniciar a simulação ao vivo;
2. aguardar 50.000 eventos inseridos;
3. aguardar 50.000 eventos classificados pelo modelo;
4. confirmar os indicadores finais: **284 alertas previstos** no threshold
   operacional de 27%; e
5. executar as seis perguntas sugeridas na mesma sessão, sem reiniciar a
   aplicação ou o cluster.

Resultado: as seis respostas apareceram corretamente, sem mensagem de erro ou
indisponibilidade. A renderização de cada resposta ocorreu entre **553 ms e
595 ms**, já com o fluxo de ingestão e classificação concluído.

## Conciliação visual do dashboard

Em uma rodada posterior de 50.000 eventos, foi feita a comparação entre os
valores renderizados na página e os agregados consolidados retornados pelo
backend/HeatWave. Todos os valores abaixo coincidiram após o arredondamento de
exibição:

| Elemento exibido | Valor confirmado |
|---|---:|
| Valor movimentado | US$ 133.299.788 |
| Transações | 1.902.394 |
| Ticket médio | US$ 70,07 |
| Alertas `score >= 27%` | 271 |
| Alertas `score >= 50%` | 241 |
| Casos críticos `score >= 85%` | 154 |
| Fluxo novo | 50.000 transações e US$ 3.514.455,50 |
| Top estabelecimento | Pacocha-O'Reilly, US$ 439.420,01 |

Correção aplicada: durante uma rodada ativa, a interface usa agregados
operacionais leves. Após `COMPLETED`, ela passa a usar a consolidação completa
do servidor. Isso evita que o ranking de estabelecimentos/cidades seja
calculado apenas com o top incremental e garante que o que o visitante vê é o
ranking consolidado da base histórica mais o fluxo simulado.

Veja também o [changelog](CHANGELOG-DEMO.md) e o
[runbook da VM](08-OPERACAO-VM-DEMO.md).
