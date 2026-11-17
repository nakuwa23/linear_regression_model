"""FastAPI service that predicts annual pay (USD) for young African developers."""

from io import BytesIO
from pathlib import Path
from typing import Literal

import joblib
import numpy as np
import pandas as pd
from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, ConfigDict, Field
from sklearn.metrics import mean_squared_error

BASE_DIR = Path(__file__).resolve().parent
MODEL_PATH = BASE_DIR / "best_model.pkl"

NUMERIC = ["YearsCode", "WorkExp", "OnlineCourses", "SurveyYear"]
CATEGORICAL = ["Country", "AgeGroup", "Education", "WorkMode", "OrgSize", "EmploymentType", "RoleGroup"]
FEATURES = NUMERIC + CATEGORICAL
TARGET = "AnnualPayUSD"

model = joblib.load(MODEL_PATH)

app = FastAPI(
    title="Digital Skills Pay Estimator API",
    description="Predicts the annual pay (USD) a young African developer (18-34) can expect.",
    version="1.0.0",
)

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
    try:
        new = pd.read_csv(BytesIO(await file.read()))
    except Exception:
        raise HTTPException(status_code=400, detail="File is not a readable CSV.")

    missing = [c for c in FEATURES + [TARGET] if c not in new.columns]
    if missing:
        raise HTTPException(status_code=400, detail=f"Missing columns: {missing}")

    # Same rules as the notebook: drop incomplete rows and implausible pay
    new = new[FEATURES + [TARGET]].dropna()
    new = new[new[TARGET].between(600, 300_000)]
    if new.empty:
        raise HTTPException(status_code=400, detail="No valid rows after cleaning.")

    X_new = model.named_steps["preprocessor"].transform(new[FEATURES])
    y_new = np.log1p(new[TARGET])
    sgd = model.named_steps["model"]
    mse_before = mean_squared_error(y_new, sgd.predict(X_new))

    for _ in range(20):
        sgd.partial_fit(X_new, y_new)
    mse_after = mean_squared_error(y_new, sgd.predict(X_new))

    joblib.dump(model, MODEL_PATH)
    return {
        "message": "Model retrained with partial_fit and now in use.",
        "rows_used": int(len(new)),
        "mse_on_new_data_before": round(mse_before, 4),
        "mse_on_new_data_after": round(mse_after, 4),
    }