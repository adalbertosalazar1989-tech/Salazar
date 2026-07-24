import os
import tempfile
from pathlib import Path

DB_FILE = Path(tempfile.gettempdir()) / "saeng_v2_pytest.db"
if DB_FILE.exists():
    DB_FILE.unlink()
os.environ["SAENG_DB_PATH"] = str(DB_FILE)

from fastapi.testclient import TestClient
import app as saeng

client = TestClient(saeng.app)


def test_health_and_dashboard():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"
    response = client.get("/")
    assert response.status_code == 200
    assert "SAENG Software SST V2" in response.text


def test_company_worker_risk_exam_and_event_flow():
    response = client.post("/companies", data={"legal_name": "Empresa Teste", "cnpj": "12345678000195", "status": "ativa"})
    assert response.status_code == 200
    assert "Empresa cadastrada" in response.text

    company = saeng.one("SELECT * FROM companies WHERE cnpj=?", ("12345678000195",))
    assert company is not None

    response = client.post("/workers", data={
        "company_id": company["id"], "name": "Trabalhador Teste", "cpf": "12345678901",
        "registration": "MAT-001", "role_name": "Tecnico", "cbo": "351605"
    })
    assert response.status_code == 200
    worker = saeng.one("SELECT * FROM workers WHERE registration='MAT-001'")
    assert worker is not None

    response = client.post("/risks", data={
        "company_id": company["id"], "worker_id": worker["id"], "category": "quimico",
        "product_name": "Produto X", "substance": "Tolueno", "cas_number": "108-88-3",
        "table24_code": "01.17.001", "exposure_form": "vapor", "exposure_route": "inalatoria",
        "frequency": "habitual", "evaluation_type": "qualitativa", "intensity": "", "unit": "",
        "technique": "", "epi": "Respirador", "epc": "Exaustao", "table27_code": "0295",
        "exam_name": "Avaliacao clinica"
    })
    assert response.status_code == 200
    assert "Risco cadastrado" in response.text

    response = client.post("/exams", data={
        "company_id": company["id"], "worker_id": worker["id"], "aso_type": "periodico",
        "aso_date": "2026-07-23", "result": "apto", "table27_code": "0295",
        "procedure_name": "Avaliacao clinica", "physician": "Medico Teste", "crm": "CRM 0000/XX"
    })
    assert response.status_code == 200

    response = client.post("/events", data={
        "company_id": company["id"], "worker_id": worker["id"], "event_type": "S-2240",
        "event_date": "2026-07-23", "notes": "Evento local de teste"
    })
    assert response.status_code == 200
    assert "XML local gerado" in response.text
    event = saeng.one("SELECT * FROM events WHERE event_type='S-2240'")
    assert event is not None
    xml_response = client.get(f"/events/{event['id']}/xml")
    assert xml_response.status_code == 200
    assert "application/xml" in xml_response.headers["content-type"]
    assert "S2240" in xml_response.text


def test_chemical_and_quantitative_validations():
    company = saeng.one("SELECT * FROM companies LIMIT 1")
    assert company is not None

    response = client.post("/risks", data={
        "company_id": company["id"], "worker_id": "", "category": "quimico",
        "product_name": "Thinner", "substance": "", "cas_number": "", "table24_code": "",
        "exposure_form": "vapor", "exposure_route": "inalatoria", "frequency": "eventual",
        "evaluation_type": "qualitativa", "intensity": "", "unit": "", "technique": "",
        "epi": "", "epc": "", "table27_code": "", "exam_name": ""
    })
    assert response.status_code == 200
    assert "exige substancia" in response.text

    response = client.post("/risks", data={
        "company_id": company["id"], "worker_id": "", "category": "fisico",
        "product_name": "", "substance": "Ruido", "cas_number": "", "table24_code": "02.01.001",
        "exposure_form": "", "exposure_route": "", "frequency": "habitual",
        "evaluation_type": "quantitativa", "intensity": "85", "unit": "", "technique": "",
        "epi": "", "epc": "", "table27_code": "", "exam_name": "Audiometria"
    })
    assert response.status_code == 200
    assert "exige intensidade, unidade e tecnica" in response.text


def test_readiness_and_audit_pages():
    assert client.get("/readiness").status_code == 200
    response = client.get("/audit")
    assert response.status_code == 200
    assert "Trilha de auditoria" in response.text
