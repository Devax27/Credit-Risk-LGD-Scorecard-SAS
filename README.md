# Credit Risk LGD Scorecard using SAS

## Loss Given Default (LGD) Modeling & Scorecard Development

A complete **Credit Risk Loss Given Default (LGD) Scorecard** developed using **SAS**, covering data preparation, LGD target construction, variable segmentation, target encoding, regression modeling, scorecard scaling, model validation, decile analysis, lift & gains analysis, PSI monitoring, and out-of-sample scoring.

---

## 📌 Project Overview

**Loss Given Default (LGD)** represents the proportion of an exposure that is expected to be lost when a borrower defaults.

This project demonstrates an end-to-end credit risk modeling workflow for estimating loss severity and converting predicted LGD into an interpretable **300–850 LGD scorecard**.

The project was developed using **SAS Studio** and follows a structured credit-risk modeling approach.

### Key Objectives

- Construct an LGD target from available customer payment behavior
- Perform data quality and consistency checks
- Segment important credit-risk variables
- Apply target/mean encoding
- Develop a regression-based LGD model
- Evaluate model performance
- Convert predicted LGD into a score
- Validate model ranking through decile analysis
- Perform lift and gains analysis
- Evaluate score stability using PSI
- Generate out-of-sample LGD scores

---

# 💼 Business Problem

Financial institutions need to estimate not only **whether a borrower will default**, but also **how severe the resulting loss could be**.

LGD is an important component of credit-risk analysis and can support:

- Expected credit loss analysis
- Portfolio risk segmentation
- Credit risk measurement
- Loss severity estimation
- Risk-based decision making
- Portfolio monitoring
- Credit risk reporting
- Scorecard development

The objective of this project is to demonstrate how customer credit and repayment characteristics can be transformed into an interpretable **LGD prediction and scoring framework**.

---

# 📊 Dataset

## UCI Credit Card Default Dataset

The project uses the **UCI Credit Card Default Dataset**.

### Dataset Characteristics

| Attribute | Value |
|---|---:|
| Customer Records | **30,000** |
| Variables | **25** |
| Domain | **Retail Credit Risk** |
| Development Records | **21,004** |
| Validation/Test Records | **8,996** |

The dataset contains customer demographic information, credit limits, historical billing amounts, payment amounts, repayment status, and default information.

---

## 🔍 Important Variables

| Variable | Description |
|---|---|
| `LIMIT_BAL` | Customer credit limit |
| `PAY_0` | Most recent repayment status |
| `PAY_2` – `PAY_6` | Historical repayment status |
| `BILL_AMT1` – `BILL_AMT6` | Historical billing amounts |
| `PAY_AMT1` – `PAY_AMT6` | Historical payment amounts |
| `AGE` | Customer age |
| `default_payment_next_month` | Default indicator |

---

# 🎯 LGD Target Construction

The source dataset does not provide a directly observed contractual LGD or a dedicated post-default recovery amount.

Therefore, the project constructs a **derived LGD measure** using the available billing and payment information.

The conceptual calculation is:

```text
Total Bill
     ↓
Total Payment
     ↓
Recovery Rate
     ↓
LGD
```

The derived relationship is:

```text
Recovery Rate = Total Payment / Total Bill

LGD = 1 - Recovery Rate
```

The resulting LGD target is then used throughout the model development and validation workflow.

### Why This Approach?

The available dataset contains historical payment and billing information but does not contain a dedicated observed recovery field.

Therefore, the project uses the available information to demonstrate the complete **LGD modeling and scorecard methodology**.

### Production Data Consideration

For an institutional production LGD model, the target would typically be constructed from observed:

- Exposure at Default (EAD)
- Actual recovery cash flows
- Recovery timing
- Workout costs
- Collateral recoveries
- Other post-default recovery information

This project therefore demonstrates the **modeling methodology**, while the target itself is a derived severity measure based on the available dataset.

---

# 🔄 End-to-End Modeling Workflow

```text
UCI Credit Card Dataset
          │
          ▼
      Data Import
          │
          ▼
 Data Quality Checks
          │
          ▼
   LGD Construction
          │
          ▼
 Exploratory Analysis
          │
          ▼
 Train / Test Split
          │
          ▼
 Variable Binning
          │
          ▼
 Target / Mean Encoding
          │
          ▼
 LGD Regression Model
          │
          ▼
   Predicted LGD
          │
          ▼
 LGD Score Scaling
          │
          ▼
  Decile Validation
          │
          ▼
 Lift & Gains Analysis
          │
          ▼
  PSI Stability Test
          │
          ▼
 Out-of-Sample Scoring
```

---

# 🧹 Data Preparation

The modeling workflow includes several data preparation and validation steps:

- Dataset import into SAS
- Record and variable validation
- Duplicate/quality checks
- Numeric variable inspection
- Missing-value checks
- LGD target construction
- Outlier analysis
- Dataset segmentation
- Train/test separation

The complete implementation is contained in the SAS master program.

---

# 🧪 Train / Test Split

The dataset was separated into development and validation populations.

| Population | Records |
|---|---:|
| Training | **21,004** |
| Testing | **8,996** |
| **Total** | **30,000** |

The training population was used for model development.

The test population was retained for **out-of-sample validation and scoring**.

---

# 🔍 Variable Segmentation

Important credit-risk variables were transformed into meaningful segments before modeling.

## PAY_0

`PAY_0` captures recent repayment behavior and provides an important indicator of customer payment risk.

The variable was segmented into repayment-status groups to capture differences in LGD severity.

## AGE

Customer age was divided into meaningful age groups to identify differences in loss severity across customer segments.

## LIMIT_BAL

Credit limit was segmented into ranges to capture differences in expected loss severity across exposure levels.

---

# 🧮 Target / Mean Encoding

After segmentation, the selected variables were transformed using **target/mean encoding**.

For each segment, the mean LGD was calculated and used as the encoded representation of the segment.

Conceptually:

```text
Customer Variable
       ↓
Risk Segment
       ↓
Average LGD of Segment
       ↓
Encoded Modeling Variable
```

This approach provides an interpretable representation of the relationship between customer segments and LGD severity.

---

# 📈 LGD Regression Model

A regression-based modeling approach was used to estimate LGD from the encoded credit-risk characteristics.

The model produces a continuous predicted LGD value for each customer.

### Model Performance

| Metric | Training | Test |
|---|---:|---:|
| R² | **0.1358** | **0.1397** |
| RMSE | — | **0.3020** |
| MAE | — | **0.2450** |

### Interpretation

The test-set results provide an out-of-sample assessment of predictive performance.

The relatively modest R² is consistent with the difficulty of predicting a noisy, derived LGD severity measure from a limited set of customer characteristics.

---

# 💳 LGD Scorecard Development

Predicted LGD values were converted into an interpretable score.

The scorecard uses a:

```text
300 – 850
```

scoring range.

The score direction is:

```text
Lower LGD Score
       ↓
Higher Expected Loss Severity
```

and:

```text
Higher LGD Score
       ↓
Lower Expected Loss Severity
```

This makes the score easier to interpret for portfolio segmentation and risk reporting.

---

# ⚙️ Score Scaling Methodology

The predicted LGD is transformed using a logit-based score scaling approach.

Before applying the logit transformation, predicted LGD values are safely bounded away from exactly 0 and 1.

Conceptually:

```text
Predicted LGD
      ↓
Boundary Protection
      ↓
LGD Odds
      ↓
Logit Transformation
      ↓
Score Scaling
      ↓
300 – 850 LGD Score
```

The final score is constrained to:

```text
Minimum Score = 300

Maximum Score = 850
```

---

# 📊 Decile Validation

Customers are ranked according to predicted LGD and divided into deciles.

The decile validation compares:

- Number of observations
- Average actual LGD
- Average predicted LGD
- LGD score
- Severity ranking

The purpose of decile analysis is to determine whether the model produces a meaningful ordering of customers according to expected loss severity.

### Validation Principle

A well-ranked LGD model should generally demonstrate increasing predicted/actual severity as customers move toward higher-risk deciles.

---

# 📉 Lift & Gains Analysis

The project includes cumulative **lift and gains analysis**.

The analysis evaluates the model's ability to concentrate higher-loss-severity customers within smaller portions of the portfolio.

The methodology compares:

```text
Model-Based Ranking
        ↓
Cumulative Population
        ↓
Cumulative LGD
        ↓
Baseline Comparison
        ↓
Lift / Gains
```

This provides an additional evaluation of the model's ranking capability.

---

# 📐 Population Stability Index (PSI)

**Population Stability Index (PSI)** is used to assess whether the score distribution remains stable between development and validation populations.

The score distribution is divided into explicit score bands and compared across populations.

### Validated PSI

```text
PSI ≈ 0.0002
```

The very low PSI indicates **minimal distribution shift** between the compared score populations.

PSI can be incorporated into an ongoing scorecard monitoring framework.

---

# 🧮 Out-of-Sample Scoring

The final scoring workflow was applied to the test population.

### Test Scoring Result

```text
Test Records Scored = 8,996
```

The scored population contains:

- Predicted LGD
- LGD score
- Risk/severity ranking
- Validation fields

This demonstrates the application of the developed scorecard to an unseen population.

---

# 📋 Model Validation Framework

The project uses multiple validation techniques rather than relying on a single performance metric.

| Validation Method | Purpose |
|---|---|
| R² | Measures explained variance |
| RMSE | Measures prediction error |
| MAE | Measures average absolute prediction error |
| Decile Analysis | Evaluates risk/severity ordering |
| Lift & Gains | Evaluates concentration capability |
| PSI | Evaluates score distribution stability |
| Out-of-Sample Scoring | Validates application to unseen records |

---

# 📊 Final Project Results

| Category | Result |
|---|---:|
| Total Customers | **30,000** |
| Total Variables | **25** |
| Training Records | **21,004** |
| Test Records | **8,996** |
| Training R² | **0.1358** |
| Test R² | **0.1397** |
| Test RMSE | **0.3020** |
| Test MAE | **0.2450** |
| LGD Score Range | **300 – 850** |
| Test Records Scored | **8,996** |
| Validated PSI | **~0.0002** |

---

# 🛠️ Tools & Technologies

## Programming & Analytics

- SAS
- SAS Studio
- SAS DATA Step
- PROC SQL

## Statistical Modeling

- Regression Modeling
- Target/Mean Encoding
- Variable Binning
- Decile Analysis
- Model Validation
- Lift & Gains Analysis
- Population Stability Index

## Credit Risk

- Loss Given Default (LGD)
- Credit Risk Segmentation
- Risk Severity Modeling
- Scorecard Development
- Portfolio Monitoring

## Version Control

- Git
- GitHub

---

# 📁 Repository Structure

```text
Credit-Risk-LGD-Scorecard-SAS/
│
├── README.md
│
├── .gitignore
│
├── data/
│   └── README.md
│
├── report/
│   └── Credit_Risk_LGD_Scorecard_Project_Report.docx
│
├── sas/
│   └── Credit_Risk_LGD_Scorecard_Master.sas
│
└── screenshots/
    └── [LGD model screenshots]
```

---

# 📄 Project Report

A detailed project report is included in the `report/` directory.

```text
report/
└── Credit_Risk_LGD_Scorecard_Project_Report.docx
```

The report documents the methodology, modeling process, validation, and project results.

---

# 💻 SAS Implementation

The complete SAS workflow is provided in:

```text
sas/Credit_Risk_LGD_Scorecard_Master.sas
```

The master program contains the major stages of the LGD modeling workflow, including:

- Data preparation
- LGD construction
- Variable segmentation
- Target encoding
- Regression modeling
- Scorecard scaling
- Validation
- Decile analysis
- Lift/gains analysis
- PSI analysis
- Test scoring

---

# 🔐 Data Privacy & Repository Policy

The raw customer dataset is **not committed to this GitHub repository**.

The repository contains the modeling code, documentation, report, and project structure required to understand the methodology.

The `.gitignore` file prevents raw CSV and generated dataset files from being accidentally committed.

---

# 🎯 Key Takeaways

- Built a complete **Credit Risk LGD Scorecard** using SAS.
- Worked with **30,000 customer records and 25 variables**.
- Constructed a derived LGD target from available billing and payment information.
- Applied credit-risk variable segmentation.
- Applied target/mean encoding.
- Developed a regression-based LGD prediction model.
- Achieved a **test R² of 0.1397**.
- Achieved a **test RMSE of 0.3020**.
- Achieved a **test MAE of 0.2450**.
- Converted predicted LGD into a **300–850 scorecard**.
- Performed decile-based validation.
- Performed lift and gains analysis.
- Evaluated score stability using PSI.
- Achieved approximately **0.0002 PSI** in the validated score-band analysis.
- Generated **8,996 out-of-sample LGD scores**.
- Implemented a complete and interpretable credit-risk modeling workflow in SAS.

---

# 🚀 Future Enhancements

The methodology can be extended further with richer credit-risk and recovery information.

Potential enhancements include:

- Observed Exposure at Default (EAD)
- Actual recovery cash flows
- Recovery timing
- Workout costs
- Collateral information
- Economic variables
- Macroeconomic scenarios
- Segmented LGD models
- Alternative regression approaches
- Model calibration
- Back-testing
- Champion/challenger models
- Automated scorecard monitoring
- Production model governance

---

# ⚠️ Model Scope & Limitation

This project demonstrates an end-to-end **LGD modeling and scorecard development methodology**.

The underlying UCI dataset does not contain observed post-default recovery cash flows or a dedicated contractual LGD field. Therefore, the LGD target used in this project is derived from available billing and payment information.

This distinction is important when interpreting the results.

For a real-world banking implementation, the model would require institution-specific recovery and exposure data together with appropriate:

- Model governance
- Independent validation
- Documentation
- Monitoring
- Back-testing
- Data quality controls
- Regulatory review
- Production controls

---

# ⚠️ Disclaimer

This project is developed for **portfolio, educational, and analytical purposes**.

The results demonstrate the practical implementation of a credit-risk LGD modeling and scorecard workflow using SAS.

The derived LGD target should not be interpreted as an observed contractual recovery measure.

The model should not be used directly for real-world lending, capital, provisioning, regulatory, or financial decisions without appropriate institution-specific data, validation, governance, monitoring, and regulatory controls.

---

# 👤 Author

## Devansh Gupta

**Data Analyst | Data Science | Credit Risk Modeling**

This project was independently developed by **Devansh Gupta** as a portfolio project demonstrating practical experience in:

- Credit Risk Analytics
- Loss Given Default Modeling
- SAS
- Statistical Modeling
- Data Analysis
- Scorecard Development
- Model Validation
- Risk Segmentation
- Portfolio Monitoring

---

# ⭐ Project Summary

| Project Attribute | Details |
|---|---|
| **Project** | Credit Risk LGD Scorecard |
| **Domain** | Credit Risk |
| **Model** | Loss Given Default (LGD) |
| **Model Type** | Regression |
| **Technology** | SAS |
| **Dataset** | UCI Credit Card Default Dataset |
| **Records** | 30,000 |
| **Variables** | 25 |
| **Training Records** | 21,004 |
| **Test Records** | 8,996 |
| **Test R²** | 0.1397 |
| **Test RMSE** | 0.3020 |
| **Test MAE** | 0.2450 |
| **Score Range** | 300–850 |
| **PSI** | ~0.0002 |
| **Author** | Devansh Gupta |

---

**Credit Risk LGD Scorecard — SAS | Devansh Gupta**