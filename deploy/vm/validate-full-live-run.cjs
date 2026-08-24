/*
 * Validação ponta a ponta da demonstração:
 * 1) inicia a rodada de 50 mil eventos;
 * 2) espera ingestão e classificação terminarem;
 * 3) concilia cards/gráficos expostos pela API com SQL direto;
 * 4) pergunta ao chat e exige origem sys.NL_SQL nas cinco perguntas analíticas.
 *
 * Uso na VM (sem imprimir credenciais):
 * sudo /bin/sh -c 'set -a; . /etc/febraban-fraud-copilot.env; set +a;
 *   node /tmp/validate-full-live-run.cjs'
 */
// Resolve a dependência a partir do projeto para o mesmo validador funcionar
// tanto na VM quanto em qualquer notebook local que tenha executado npm install.
const mysql = require("mysql2/promise");

const baseUrl = "http://127.0.0.1:8787";
const targetEvents = 50_000;
const pollMs = 2_000;
const timeoutMs = 6 * 60_000;
const questions = [
  "Qual o valor movimentado na simulação atual?",
  "Quantos eventos foram simulados na rodada atual?",
  "Quantos alertas foram gerados na simulação atual?",
  "Quais categorias concentram mais valor na simulação atual?",
  "Qual estabelecimento lidera em vendas na simulação atual?",
  "Qual cidade tem maior movimentação na simulação atual?",
];

const pause = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const asNumber = (value) => Number(value ?? 0);
const same = (left, right, tolerance = 0.001) => Math.abs(asNumber(left) - asNumber(right)) <= tolerance;
function assert(condition, message) { if (!condition) throw new Error(message); }

async function api(path, options = {}) {
  const response = await fetch(`${baseUrl}${path}`, options);
  const body = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(`${path}: HTTP ${response.status}: ${body.error ?? JSON.stringify(body)}`);
  return body;
}

function normalizeRows(rows, keys) {
  return rows.map((row) => Object.fromEntries(keys.map((key) => [key, typeof row[key] === "number" ? row[key] : String(row[key] ?? "")] )));
}

function assertSameRows(actual, expected, keys, label) {
  assert(actual.length === expected.length, `${label}: quantidade divergente (${actual.length} != ${expected.length})`);
  for (let index = 0; index < expected.length; index += 1) {
    for (const key of keys) {
      const a = actual[index]?.[key];
      const e = expected[index]?.[key];
      if (typeof e === "number" || /^-?\d+(\.\d+)?$/.test(String(e))) {
        assert(same(a, e), `${label}: ${key} na posição ${index} diverge (${a} != ${e})`);
      } else {
        assert(String(a) === String(e), `${label}: ${key} na posição ${index} diverge (${a} != ${e})`);
      }
    }
  }
}

async function main() {
  const before = await api("/api/live?page=1&grain=month");
  const startedAt = Date.now();
  const reuseCompletedRun = process.env.VALIDATE_EXISTING_RUN === "true";
  let runId;
  let snapshot;
  if (reuseCompletedRun) {
    assert(before.completed && before.scored === targetEvents && before.runId, "Não há rodada concluída de 50 mil eventos para validar.");
    snapshot = before;
    runId = before.runId;
  } else {
    assert(!before.active, `Já existe uma simulação ativa (${before.runId}); não a interrompi.`);
    const start = await api("/api/live/start", { method: "POST" });
    runId = start.runId;
    assert(start.targetEvents === targetEvents, `Meta inesperada: ${start.targetEvents}`);
    do {
      await pause(pollMs);
      snapshot = await api("/api/live?page=1&grain=month");
      if (snapshot.phase === "ERROR" || snapshot.lastError || snapshot.lastScoringError) {
        throw new Error(`Simulação falhou: ${snapshot.lastError ?? snapshot.lastScoringError ?? snapshot.phase}`);
      }
      if (Date.now() - startedAt > timeoutMs) throw new Error(`Timeout aguardando a rodada ${runId}. Último estado: ${JSON.stringify({ phase: snapshot.phase, inserted: snapshot.inserted, scored: snapshot.scored })}`);
    } while (!(snapshot.runId === runId && snapshot.completed && snapshot.scored === targetEvents));
  }

  const pool = mysql.createPool({
    host: process.env.MYSQL_HOST,
    port: Number(process.env.MYSQL_PORT || 3306),
    user: process.env.MYSQL_USER,
    password: process.env.MYSQL_PASSWORD,
    database: "fraud_demo_public",
    ssl: process.env.MYSQL_SSL === "true" ? { rejectUnauthorized: false } : undefined,
    dateStrings: true
  });
  const connection = await pool.getConnection();
  let reconciliation;
  try {
    await connection.query("SET SESSION use_secondary_engine = OFF");
    const [[overview]] = await connection.query(
      "SELECT COUNT(*) event_count, ROUND(SUM(amount),2) total_amount, SUM(model_prediction IS NOT NULL) scored_events, SUM(fraud_probability >= 0.60) alerts_at_060, SUM(fraud_probability >= 0.85) alerts_at_085, SUM(fraud_probability >= 0.95) alerts_at_095, MAX(fraud_probability) max_fraud_probability FROM fraud_demo_public.v_live_transaction_events WHERE run_id=?", [runId]
    );
    const [categories] = await connection.query("SELECT category, ROUND(SUM(amount),2) gross_sales, COUNT(*) transaction_count FROM fraud_demo_public.v_live_transaction_events WHERE run_id=? GROUP BY category ORDER BY gross_sales DESC LIMIT 8", [runId]);
    const [merchants] = await connection.query("SELECT merchant_name, category, ROUND(SUM(amount),2) gross_sales, COUNT(*) transaction_count FROM fraud_demo_public.v_live_transaction_events WHERE run_id=? GROUP BY merchant_name, category ORDER BY gross_sales DESC LIMIT 8", [runId]);
    const [cities] = await connection.query("SELECT city, state, ROUND(SUM(amount),2) gross_sales, COUNT(*) transaction_count FROM fraud_demo_public.v_live_transaction_events WHERE run_id=? GROUP BY city, state ORDER BY gross_sales DESC LIMIT 8", [runId]);

    assert(asNumber(snapshot.overview.event_count) === asNumber(overview.event_count), "Card de transações diverge do banco");
    assert(same(snapshot.overview.total_amount, overview.total_amount), "Card de valor movimentado diverge do banco");
    assert(asNumber(snapshot.scored) === asNumber(overview.scored_events), "Card de classificadas diverge do banco");
    assert(asNumber(snapshot.predictedAlerts) === asNumber(overview.alerts_at_060), "Card de alertas diverge do banco");
    assertSameRows(snapshot.aggregates.categorySales, categories.map((row) => ({ category: row.category, grossSales: asNumber(row.gross_sales), transactionCount: asNumber(row.transaction_count) })), ["category", "grossSales", "transactionCount"], "Gráfico de categorias");
    assertSameRows(snapshot.aggregates.merchantSales, merchants.map((row) => ({ merchantName: row.merchant_name, category: row.category, grossSales: asNumber(row.gross_sales), transactionCount: asNumber(row.transaction_count) })), ["merchantName", "category", "grossSales", "transactionCount"], "Gráfico de estabelecimentos");
    assertSameRows(snapshot.aggregates.citySales, cities.map((row) => ({ city: row.city, state: row.state, grossSales: asNumber(row.gross_sales), transactionCount: asNumber(row.transaction_count) })), ["city", "state", "grossSales", "transactionCount"], "Gráfico de cidades");
    reconciliation = { overview, categoryTop: categories[0], merchantTop: merchants[0], cityTop: cities[0] };
  } finally {
    connection.release();
    await pool.end();
  }

  const session = await api("/api/sessions", { method: "POST" });
  const answers = [];
  for (const [index, question] of questions.entries()) {
    const response = await api("/api/chat/turn", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ sessionId: session.sessionId, message: question }) });
    assert(response.dataSource === "MySQL HeatWave · NL_SQL", `Pergunta não usou NL_SQL: ${question} (${response.dataSource})`);
    assert(/^select\b/i.test(response.sql?.executedSql ?? ""), `Pergunta não devolveu SELECT auditável: ${question}`);
    assert(response.sql.executedSql.includes(runId), `Pergunta não foi isolada pelo run_id: ${question}`);
    const first = response.evidence.rows[0] ?? {};
    if (index === 0) assert(same(first.total_amount, reconciliation.overview.total_amount), "NL_SQL: valor movimentado diverge do card/banco");
    if (index === 1) assert(asNumber(first.event_count) === asNumber(reconciliation.overview.event_count), "NL_SQL: eventos divergem do card/banco");
    if (index === 2) assert(asNumber(first.predicted_alerts) === asNumber(reconciliation.overview.alerts_at_060), "NL_SQL: alertas divergem do card/banco");
    if (index === 3) {
      assert(String(first.category) === String(reconciliation.categoryTop.category), "NL_SQL: categoria líder diverge do gráfico/banco");
      assert(same(first.total_amount ?? first.gross_sales, reconciliation.categoryTop.gross_sales), "NL_SQL: valor da categoria líder diverge do gráfico/banco");
    }
    if (index === 4) {
      assert(String(first.merchant_name) === String(reconciliation.merchantTop.merchant_name), "NL_SQL: estabelecimento líder diverge do gráfico/banco");
      assert(same(first.total_amount ?? first.gross_sales, reconciliation.merchantTop.gross_sales), "NL_SQL: valor do estabelecimento líder diverge do gráfico/banco");
    }
    if (index === 5) {
      assert(String(first.city) === String(reconciliation.cityTop.city) && String(first.state) === String(reconciliation.cityTop.state), "NL_SQL: cidade líder diverge do gráfico/banco");
      assert(same(first.total_amount ?? first.gross_sales, reconciliation.cityTop.gross_sales), "NL_SQL: valor da cidade líder diverge do gráfico/banco");
    }
    answers.push({ question, source: response.dataSource, sql: response.sql.executedSql, firstRow: response.evidence.rows[0] ?? null });
  }
  await api(`/api/sessions/${session.sessionId}/reset`, { method: "POST" });

  process.stdout.write(`${JSON.stringify({
    ok: true,
    runId,
    elapsedSeconds: Number(((Date.now() - startedAt) / 1000).toFixed(1)),
    snapshot: { phase: snapshot.phase, inserted: snapshot.inserted, scored: snapshot.scored, predictedAlerts: snapshot.predictedAlerts },
    reconciliation,
    nlSqlAnswers: answers
  }, null, 2)}\n`);
}

main().catch((error) => { process.stderr.write(`${error.stack || error.message}\n`); process.exitCode = 1; });
