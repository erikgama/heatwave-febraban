from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import cm
from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "docs" / "GUIA-MODELO-E-DADOS-B1-V2-RAG-REV3-20260823.pdf"
NAVY = colors.HexColor("#0B3B4D")
TEAL = colors.HexColor("#00758F")
ORANGE = colors.HexColor("#F29111")
INK = colors.HexColor("#183642")
MUTED = colors.HexColor("#587582")
PALE = colors.HexColor("#EAF6F8")
LINE = colors.HexColor("#C9DEE5")


def paragraph(text, style):
    return Paragraph(text, style)


def footer(canvas, document):
    canvas.saveState()
    width, height = A4
    canvas.setFillColor(NAVY)
    canvas.rect(0, height - 1.05 * cm, width, 1.05 * cm, fill=1, stroke=0)
    canvas.setFillColor(colors.white)
    canvas.setFont("Helvetica-Bold", 8.5)
    canvas.drawString(1.55 * cm, height - 0.65 * cm, "FEBRABAN | MYSQL HEATWAVE | FONTE RAG REVISADA")
    canvas.setFillColor(ORANGE)
    canvas.rect(1.55 * cm, 0.95 * cm, width - 3.1 * cm, 0.05 * cm, fill=1, stroke=0)
    canvas.setFillColor(MUTED)
    canvas.setFont("Helvetica", 8)
    canvas.drawString(1.55 * cm, 0.58 * cm, "Dados sintéticos. Score representa risco previsto; não confirma fraude.")
    canvas.drawRightString(width - 1.55 * cm, 0.58 * cm, f"Página {document.page}")
    canvas.restoreState()


def table(rows, widths, styles):
    cells = []
    for idx, row in enumerate(rows):
        style = styles["TableHeader"] if idx == 0 else styles["TableBody"]
        cells.append([paragraph(str(value), style) for value in row])
    result = Table(cells, colWidths=widths, repeatRows=1, hAlign="LEFT")
    result.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), NAVY),
        ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
        ("GRID", (0, 0), (-1, -1), 0.35, LINE),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 7),
        ("RIGHTPADDING", (0, 0), (-1, -1), 7),
        ("TOPPADDING", (0, 0), (-1, -1), 6),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
    ]))
    return result


def build():
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    doc = SimpleDocTemplate(
        str(OUTPUT), pagesize=A4,
        leftMargin=1.55 * cm, rightMargin=1.55 * cm,
        topMargin=1.55 * cm, bottomMargin=1.35 * cm,
        title="Guia revisado do modelo B1 V2 para RAG",
        author="FEBRABAN HeatWave Fraud Copilot",
    )
    base = getSampleStyleSheet()
    styles = {
        "Title": ParagraphStyle("Title", parent=base["Title"], fontName="Helvetica-Bold", fontSize=23, leading=27, textColor=NAVY, alignment=TA_CENTER, spaceAfter=6),
        "Subtitle": ParagraphStyle("Subtitle", parent=base["Normal"], fontName="Helvetica", fontSize=10.5, leading=14, textColor=MUTED, alignment=TA_CENTER, spaceAfter=15),
        "H": ParagraphStyle("H", parent=base["Heading2"], fontName="Helvetica-Bold", fontSize=14, leading=18, textColor=NAVY, spaceBefore=12, spaceAfter=6),
        "Body": ParagraphStyle("Body", parent=base["BodyText"], fontName="Helvetica", fontSize=9.4, leading=13.4, textColor=INK, spaceAfter=7),
        "Callout": ParagraphStyle("Callout", parent=base["BodyText"], fontName="Helvetica-Bold", fontSize=9.6, leading=13.6, textColor=NAVY, backColor=PALE, borderColor=TEAL, borderWidth=0.8, borderPadding=10, spaceBefore=7, spaceAfter=10),
        "Warning": ParagraphStyle("Warning", parent=base["BodyText"], fontName="Helvetica-Bold", fontSize=9.6, leading=13.6, textColor=INK, backColor=colors.HexColor("#FFF6E7"), borderColor=ORANGE, borderWidth=0.8, borderPadding=10, spaceBefore=7, spaceAfter=10),
        "TableHeader": ParagraphStyle("TableHeader", parent=base["BodyText"], fontName="Helvetica-Bold", fontSize=8, leading=10, textColor=colors.white),
        "TableBody": ParagraphStyle("TableBody", parent=base["BodyText"], fontName="Helvetica", fontSize=8, leading=10.3, textColor=INK),
    }

    story = [Spacer(1, 0.5 * cm)]
    story += [
        paragraph("Guia do modelo e dos dados", styles["Title"]),
        paragraph("B1 V2 - fonte vigente para ML_RAG no MySQL HeatWave | Revisão 23/08/2026", styles["Subtitle"]),
        paragraph("Esta é a fonte normativa da demonstração. Ela apresenta as sete features B1 V2 e o threshold operacional único de 60%.", styles["Warning"]),
        paragraph("Finalidade", styles["H"]),
        paragraph("O laboratório usa o dataset público Credit Card Transactions Fraud Detection, gerado pelo Sparkov e distribuído no Kaggle. São 1.852.394 transações sintéticas de 2019 e 2020; 9.651 têm is_fraud=1 (0,521%). O rótulo é histórico e sintético: nem o rótulo nem o score confirmam fraude de uma pessoa ou empresa.", styles["Body"]),
        paragraph("O HeatWave armazena dados, acelera analytics no cluster, executa o classificador B1 e recupera esta documentação via Vector Store e ML_RAG. Fatos atuais - totais, rankings, casos e resultados de uma rodada - devem ser consultados em SQL nas views públicas; RAG explica método, métricas, limites e governança.", styles["Body"]),
        paragraph("Contrato do modelo B1 V2", styles["H"]),
        table([
            ["Propriedade", "Valor aprovado"],
            ["Handle", "febraban_fraud_manual_xgb_b1_final_v2_20260810"],
            ["Catálogo da aplicação", "ML_SCHEMA_febraban.MODEL_CATALOG (proprietário: febraban)"],
            ["Algoritmo", "XGBClassifier para classificação binária"],
            ["Target histórico", "is_fraud; nunca deve ser enviado para uma nova predição"],
            ["Rotinas", "ML_MODEL_LOAD; ML_PREDICT_ROW; ML_PREDICT_TABLE"],
        ], [4.4 * cm, 12.2 * cm], styles),
        paragraph("As sete features efetivamente usadas", styles["H"]),
        table([
            ["Feature", "Definição"],
            ["amount", "Valor da compra."],
            ["amount_log", "LN(1 + amount), para reduzir assimetria de valores altos."],
            ["category", "Categoria sintética da compra."],
            ["transaction_hour", "Hora entre 0 e 23."],
            ["weekday_number", "Dia da semana: segunda-feira=0 e domingo=6."],
            ["is_weekend", "Indicador de sábado ou domingo, derivado do dia."],
            ["customer_merchant_distance_km", "Distância entre cliente e estabelecimento sintéticos."],
        ], [6.2 * cm, 10.4 * cm], styles),
        paragraph("LISTA NORMATIVA COMPLETA DAS SETE FEATURES B1 V2: amount; amount_log; category; transaction_hour; weekday_number; is_weekend; customer_merchant_distance_km. Não há quinta, sexta ou sétima feature implícita: as sete devem estar presentes em toda nova predição.", styles["Callout"]),
        paragraph("amount_log deve ser calculado como LN(1 + amount). IDs e timestamp são auditoria, não features. Não envie is_fraud, pois ele é exatamente o alvo que o modelo estima.", styles["Callout"]),
        paragraph("Threshold e interpretação correta", styles["H"]),
        table([
            ["Contexto", "Threshold / interpretação"],
            ["Simulação ao vivo", "0,60: alerta de risco previsto quando fraud_probability >= 0,60."],
            ["Priorização visual", "0,85: alerta alto. 0,95: caso crítico. Não confirmam fraude."],
            ["Predições históricas B1 V2", "0,60: a view pública usa os scores do split de teste do B1 V2."],
        ], [5.0 * cm, 11.6 * cm], styles),
        paragraph("Comunicação obrigatória: diga 'alerta de risco previsto acima do threshold operacional de 60%'. Nunca diga 'fraude confirmada', nem associe score a culpa, intenção ou bloqueio automático.", styles["Callout"]),
        paragraph("Operação da demonstração", styles["H"]),
        paragraph("A simulação usa fraud_demo.live_transaction_seed para criar eventos coerentes, grava fraud_demo.live_transaction_events e isola cada rodada por run_id. A cada 5.000 eventos, ML_PREDICT_TABLE registra classe, probabilidade e faixa de risco. O dashboard usa consultas analíticas no HeatWave; a interface só declara conclusão quando inserted=scored=50.000.", styles["Body"]),
        paragraph("Em validação E2E de 23/08/2026 com o usuário febraban: 50.000 eventos inseridos, 50.000 classificados, zero falhas de lote, zero falhas de classificação e 612 alertas com score >=60%. Os valores precisam ser tratados como resultado de uma rodada sintética, não métrica universal de produção.", styles["Body"]),
        paragraph("Governança", styles["H"]),
        paragraph("O laboratório é educacional. Produção requer dados reais validados, segurança, privacidade, monitoramento de drift, avaliação de vieses, revisão humana, trilha de auditoria e política formal para cada limiar. NL_SQL deve aceitar somente SELECT/WITH nas views públicas permitidas; ML_RAG explica documentos e deve exibir citações.", styles["Body"]),
    ]
    doc.build(story, onFirstPage=footer, onLaterPages=footer)


if __name__ == "__main__":
    build()
