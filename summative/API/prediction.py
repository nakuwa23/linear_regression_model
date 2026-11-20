"""FastAPI service that predicts annual pay (USD) for young African developers."""

from pathlib import Path
from typing import Literal

import joblib
import numpy as np
import pandas as pd
from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, ConfigDict, Field

from retrain import FEATURES, retrain_model

BASE_DIR = Path(__file__).resolve().parent
MODEL_PATH = BASE_DIR / "best_model.pkl"

model = joblib.load(MODEL_PATH)

app = FastAPI(
    title="Digital Skills Pay Estimator API",
    description="Predicts the annual pay (USD) a young African developer (18-34) can expect.",
    version="1.0.0",
)

# CORS: only these browser origins may call the API -- the deployed Swagger UI and the
# Flutter web debug server on this machine. Any other website is blocked by the browser.
# Methods are limited to GET (docs) and POST (/predict, /retrain), and the only custom
# header needed is Content-Type for JSON. Credentials are off because the API uses no
# cookies or auth. The Flutter mobile app is not a browser, so CORS does not affect it.
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://digital-skills-pay-api.onrender.com",
        "http://localhost:5000",
        "http://127.0.0.1:5000",
    ],
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type"],
    allow_credentials=False,
)


class PayInput(BaseModel):
    """One developer's details. strict=True rejects wrong types (e.g. "5" for a number)."""

    YearsCode: float = Field(..., ge=0, le=30, description="Total years of coding (incl. learning)")
    WorkExp: float = Field(..., ge=0, le=20, description="Years of professional work experience")
    OnlineCourses: int = Field(..., ge=0, le=1, description="1 if learned via online courses/certifications, else 0")
    SurveyYear: int = Field(..., ge=2023, le=2026, description="Reference year for pay level")
    Country: Literal["Algeria", "Egypt", "Ethiopia", "Ghana", "Kenya", "Morocco", "Nigeria",
                     "South Africa", "Tunisia", "Other African country"]
    AgeGroup: Literal["18-24", "25-34"]
    Education: Literal["Secondary or less", "Some university, no degree", "Associate degree",
                       "Bachelor's degree", "Master's degree", "Doctorate or professional degree"]
    WorkMode: Literal["Remote", "Hybrid", "In-person"]
    OrgSize: Literal["Freelancer (just me)", "Under 20", "20-99", "100-499", "500-4,999", "5,000+"]
    EmploymentType: Literal["Employed", "Freelancer or self-employed", "Employed and freelancing"]
    RoleGroup: Literal["Full-stack developer", "Back-end developer", "Front-end developer",
                       "Mobile developer", "Data or AI", "Other tech role"]

    model_config = ConfigDict(
        strict=True,
        json_schema_extra={"example": {
            "YearsCode": 5, "WorkExp": 3, "OnlineCourses": 1, "SurveyYear": 2025,
            "Country": "Kenya", "AgeGroup": "25-34", "Education": "Bachelor's degree",
            "WorkMode": "Remote", "OrgSize": "20-99", "EmploymentType": "Employed",
            "RoleGroup": "Full-stack developer",
        }},
    )


def predict_pay(row: pd.DataFrame) -> float:
    """Same function as the notebook: model predicts log(1 + pay), expm1 converts back to USD."""
    return float(np.expm1(model.predict(row)[0]))


@app.get("/")
def root():
    return {"message": "Digital Skills Pay Estimator API. See /docs for the Swagger UI."}


@app.post("/predict")
def predict(data: PayInput):
    row = pd.DataFrame([data.model_dump()])[FEATURES]
    return {"predicted_annual_pay_usd": round(predict_pay(row), 2)}


@app.post("/retrain")
async def retrain(file: UploadFile = File(..., description="CSV with the same columns as data.csv")):
    """Uploading a CSV triggers retraining (logic in retrain.py); /predict uses the result at once."""
    try:
        return retrain_model(model, await file.read(), MODEL_PATH)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))