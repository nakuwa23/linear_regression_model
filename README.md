# Digital Skills Pay Estimator

## Mission and problem
My mission is to equip youth in underserved African communities with the skills and pathways to become self-reliant.
Young African developers rarely know what their skills are worth or which learning and work pathways raise their pay.
This project predicts the annual pay (USD) a developer aged 18–34 can expect, so young people and youth skills programmes can set realistic goals.

## Dataset
**Stack Overflow Annual Developer Survey, 2023–2026**: real, self-reported responses from developers worldwide. No single year had 1,000 African respondents who reported pay, so I combined the four years, kept African respondents aged 18–34 with plausible pay (USD 600–300,000), and harmonised columns that were renamed between years. The cleaned dataset (`summative/linear_regression/data.csv`) has **1,355 rows and 11 features** (4 numeric, 7 categorical: experience, online-course learning, country, age group, education, role, employment type, work mode, organisation size, survey year). The target is **annual pay in USD**.

Source: [Stack Overflow Developer Survey](https://survey.stackoverflow.co/)

## API (Swagger UI)
**https://digital-skills-pay-api.onrender.com/docs**

The API is on Render's free plan, so the first request after 15 idle minutes can take up to a minute while the service wakes up. 

## How to run the mobile app
1. Install [Flutter](https://docs.flutter.dev/get-started/install) (stable) and Android Studio, then run `flutter doctor` until the Android toolchain shows a tick.
2. Start an Android emulator (Android Studio → Device Manager) or connect an Android phone with USB debugging turned on.
3. Clone the repository:
   ```bash
   git clone https://github.com/nakuwa23/linear_regression_model.git
   ```
4. Open the app folder:
   ```bash
   cd linear_regression_model/summative/FlutterApp
   ```
5. Install the dependencies:
   ```bash
   flutter pub get
   ```
6. Run the app on your device:
   ```bash
   flutter run
   ```
7. Fill in all 11 fields (category fields suggest options as you type) and tap **Predict**. The estimated annual pay, or a readable error, appears below the button.

---

## Model results
All four models were trained with scikit-learn on the same 80/20 split (1,084 train / 271 test rows). MSE is measured on log(1 + annual pay).

| Model | Train MSE | Test MSE |
|---|---|---|
| **SGDRegressor (gradient descent), best, deployed** | 1.1186 | **0.9684** |
| LinearRegression (closed form) | 1.0541 | 0.9717 |
| RandomForestRegressor | 0.8875 | 0.9963 |
| DecisionTreeRegressor | 0.9568 | 1.2832 |

SGDRegressor has the lowest test MSE, making it the best model. It is saved together with its preprocessing (scaler and one-hot encoder) as a scikit-learn Pipeline in `summative/API/best_model.pkl`.

## API endpoints
| Route | Method | Purpose |
|---|---|---|
| `/predict` | POST | Takes the 11 inputs (types and ranges validated with Pydantic) and returns the predicted annual pay in USD |
| `/retrain` | POST | Upload a CSV with the same columns as `data.csv`; the SGD model continues training on the new rows with `partial_fit` and is used by `/predict` straight away |
| `/docs` | GET | Swagger UI |

## Repository structure
```
linear_regression_model/
├── README.md
└── summative/
    ├── pyproject.toml           # uv project for the notebook
    ├── uv.lock
    ├── linear_regression/
    │   ├── multivariate.ipynb   # data cleaning, EDA, four models, loss curve, best model
    │   └── data.csv             # cleaned dataset
    ├── API/
    │   ├── prediction.py        # FastAPI app: /predict, /retrain, CORS
    │   ├── retrain.py           # retraining logic (partial_fit on uploaded data)
    │   ├── pyproject.toml       # uv project for the API
    │   ├── uv.lock
    │   ├── requirements.txt     # exported from uv.lock; installed by Render
    │   └── best_model.pkl       # saved SGDRegressor pipeline
    └── FlutterApp/              # Flutter mobile app
```