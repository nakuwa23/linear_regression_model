# Digital Skills Pay Estimator

## Mission and problem
My mission is to equip youth in underserved African communities with the skills and pathways to become self-reliant.
Young African developers rarely know what their skills are worth or which learning and work pathways raise their pay.
This project predicts the annual pay (USD) a developer aged 18–34 can expect, so young people and youth skills programmes can set realistic goals.

## Dataset
**Stack Overflow Annual Developer Survey, 2023–2026**: real, self-reported responses from developers worldwide. No single year had 1,000 African respondents who reported pay, so I combined the four years, kept African respondents aged 18–34 with plausible pay (USD 600–300,000), and harmonised columns that were renamed between years. The cleaned dataset (`summative/linear_regression/data.csv`) has **1,355 rows and 11 features** (4 numeric, 7 categorical: experience, online-course learning, country, age group, education, role, employment type, work mode, organisation size, survey year). The target is **annual pay in USD**.

Source: [Stack Overflow Developer Survey](https://survey.stackoverflow.co/) · raw files: [StackExchange/Survey on GitHub](https://github.com/StackExchange/Survey)

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