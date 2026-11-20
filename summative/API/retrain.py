"""Retraining logic for the /retrain endpoint."""

from io import BytesIO
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from sklearn.metrics import mean_squared_error
from sklearn.pipeline import Pipeline

NUMERIC = ["YearsCode", "WorkExp", "OnlineCourses", "SurveyYear"]
CATEGORICAL = ["Country", "AgeGroup", "Education", "WorkMode", "OrgSize", "EmploymentType", "RoleGroup"]
FEATURES = NUMERIC + CATEGORICAL
TARGET = "AnnualPayUSD"
EPOCHS = 20


def load_new_data(csv_bytes: bytes) -> pd.DataFrame:
    """Read an uploaded CSV and clean it with the same rules as the notebook."""
    try:
        new = pd.read_csv(BytesIO(csv_bytes))
    except Exception as exc:
        raise ValueError("File is not a readable CSV.") from exc

    missing = [c for c in FEATURES + [TARGET] if c not in new.columns]
    if missing:
        raise ValueError(f"Missing columns: {missing}")

    new = new[FEATURES + [TARGET]].dropna()
    new = new[new[TARGET].between(600, 300_000)]
    if new.empty:
        raise ValueError("No valid rows after cleaning.")
    return new


def retrain_model(model: Pipeline, csv_bytes: bytes, model_path: Path) -> dict:
    new = load_new_data(csv_bytes)
    X_new = model.named_steps["preprocessor"].transform(new[FEATURES])
    y_new = np.log1p(new[TARGET])

    sgd = model.named_steps["model"]
    mse_before = mean_squared_error(y_new, sgd.predict(X_new))
    for _ in range(EPOCHS):
        sgd.partial_fit(X_new, y_new)
    mse_after = mean_squared_error(y_new, sgd.predict(X_new))

    joblib.dump(model, model_path)
    return {
        "message": "Model retrained with partial_fit and now in use.",
        "rows_used": int(len(new)),
        "mse_on_new_data_before": round(mse_before, 4),
        "mse_on_new_data_after": round(mse_after, 4),
    }