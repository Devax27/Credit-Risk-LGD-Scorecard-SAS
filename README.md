\# Credit Risk LGD Scorecard using SAS



!\[SAS](https://img.shields.io/badge/SAS-Statistical%20Modeling-1f4e79)

!\[Credit Risk](https://img.shields.io/badge/Domain-Credit%20Risk-2f855a)

!\[LGD](https://img.shields.io/badge/Model-LGD%20Scorecard-2f855a)

!\[Regression](https://img.shields.io/badge/Model-Regression-4a5568)



\## 📌 Project Overview



This project develops an end-to-end \*\*Credit Risk Loss Given Default (LGD) Scorecard\*\* using SAS.



The objective is to estimate the expected severity of credit losses and convert the resulting LGD predictions into an interpretable credit-risk score.



The project covers the complete modeling workflow, including:



\- Data import and validation

\- Data quality checks

\- LGD target construction

\- Exploratory analysis

\- Train/test segmentation

\- Variable binning

\- Target/mean encoding

\- LGD regression modeling

\- Model performance evaluation

\- LGD scorecard scaling

\- Decile validation

\- Lift and gains analysis

\- Population Stability Index (PSI)

\- Out-of-sample scoring



\---



\## 💼 Business Problem



Loss Given Default (LGD) represents the proportion of an exposure that is expected to be lost when a borrower defaults.



For financial institutions, LGD modeling can support:



\- Credit risk measurement

\- Expected loss analysis

\- Portfolio segmentation

\- Risk-based decision making

\- Credit risk reporting

\- Portfolio monitoring

\- Loss severity analysis



The goal of this project is to demonstrate how customer credit behavior can be transformed into an interpretable \*\*LGD prediction and scorecard framework\*\* using SAS.



\---



\## 📊 Dataset



\### UCI Credit Card Default Dataset



The project uses the \*\*UCI Credit Card Default Dataset\*\* containing:



\- \*\*30,000 customer records\*\*

\- \*\*25 variables\*\*

\- Customer demographic information

\- Credit limit information

\- Historical billing amounts

\- Historical payment amounts

\- Historical repayment status

\- Credit default information



\### Key Variables



| Variable | Description |

|---|---|

| `LIMIT\_BAL` | Credit limit |

| `PAY\_0` | Most recent repayment status |

| `PAY\_2`–`PAY\_6` | Historical repayment status |

| `BILL\_AMT1`–`BILL\_AMT6` | Historical bill amounts |

| `PAY\_AMT1`–`PAY\_AMT6` | Historical payment amounts |

| `AGE` | Customer age |

| `default\_payment\_next\_month` | Default indicator |



\---



\## 🎯 LGD Target Definition



The source dataset does not provide a directly observed contractual LGD or post-default recovery amount.



Therefore, the project constructs an LGD measure from the available billing and payment information.



The derived target follows the relationship:



Total Bill → Total Payment → Recovery Rate → LGD





Conceptually:



Recovery Rate = Total Payment / Total Bill

LGD = 1 - Recovery Rate





The derived LGD target is then used consistently throughout the modeling, validation, and scorecard development workflow.



> \*\*Important Modeling Note:\*\* This approach demonstrates the LGD modeling methodology using the available dataset. For a production banking LGD model, the target would normally be constructed from observed exposure-at-default and actual post-default recovery/cash-flow information.



\---



\## 🔄 End-to-End Modeling Workflow



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

Lift \& Gains Analysis

│

▼

PSI Stability Test

│

▼

Out-of-Sample Scoring





\---



\## 🧪 Train / Test Split



The dataset was divided into development and validation populations.



| Population | Records |

|---|---|

| Training | 21,004 |

| Testing | 8,996 |

| \*\*Total\*\* | \*\*30,000\*\* |



The training population was used for model development, while the test population was used for out-of-sample validation and scoring.



\---



\## 🔍 Variable Segmentation



Credit-risk variables were transformed into meaningful segments before modeling.



\*\*PAY\_0\*\* — Repayment behavior was segmented to capture differences in customer payment performance.



\*\*AGE\*\* — Customers were grouped into age-based segments.



\*\*LIMIT\_BAL\*\* — Credit limits were segmented into risk-relevant ranges.



These segmented variables were subsequently transformed using target/mean encoding based on LGD severity.



\---



\## 📈 LGD Regression Model



A regression-based modeling approach was used to estimate LGD from the encoded credit-risk characteristics.



\### Model Performance



| Metric | Training | Test |

|---|---|---|

| R² | 0.1358 | 0.1397 |

| RMSE | — | 0.3020 |

| MAE | — | 0.2450 |



The model provides a measurable relationship between customer credit characteristics and the derived LGD target. The test-set metrics provide an out-of-sample view of model performance.



\---



\## 💳 LGD Scorecard Scaling



The predicted LGD values are transformed into an interpretable score using a \*\*300–850 scoring scale\*\*.



The score is designed so that:



\- \*\*Lower score\*\* → Higher expected loss severity

\- \*\*Higher score\*\* → Lower expected loss severity



Before the logit-based score transformation, predicted LGD values are safely bounded between 0 and 1 to avoid numerical instability at the boundaries.



\- \*\*Minimum Score:\*\* 300

\- \*\*Maximum Score:\*\* 850



\---



\## 📊 Decile Validation



Customers are ranked according to predicted LGD and divided into deciles.



The validation framework compares:



\- Number of customers

\- Average actual LGD

\- Average predicted LGD

\- LGD score

\- Risk/severity ordering



Decile analysis provides an interpretable way to evaluate whether the model successfully ranks customers according to expected loss severity.



\---



\## 📉 Lift \& Gains Analysis



The project includes cumulative lift and gains analysis. This analysis evaluates the model's ability to concentrate higher-loss-severity customers within smaller portions of the portfolio, comparing cumulative model performance against the overall portfolio baseline.



This provides an additional measure of the scorecard's discriminatory and ranking capability.



\---



\## 📐 Population Stability Index (PSI)



Population Stability Index (PSI) is used to assess whether the score distribution remains stable between development and validation populations.



The validated score-band analysis produced a PSI of approximately:



\*\*PSI ≈ 0.0002\*\*



This indicates very little distribution shift between the compared score populations. PSI can be used as part of an ongoing scorecard monitoring framework.



\---



\## 🧮 Out-of-Sample Scoring



The completed workflow generates LGD predictions and corresponding scores for the test population.



\*\*Test Records Scored: 8,996\*\*



The scored dataset contains:



\- Predicted LGD

\- LGD score

\- Risk/severity ranking

\- Validation fields



This demonstrates how the developed model can be applied to an unseen population.



\---



\## 📋 Model Validation Framework



| Validation Area | Purpose |

|---|---|

| R² | Measures explained variance |

| RMSE | Measures prediction error |

| MAE | Measures average absolute prediction error |

| Decile Analysis | Evaluates rank ordering |

| Lift \& Gains | Evaluates concentration capability |

| PSI | Evaluates population stability |

| Out-of-Sample Scoring | Tests performance on unseen records |



Using multiple validation techniques provides a broader assessment than relying on a single model metric.



\---



\## 🛠️ Tools \& Technologies



\*\*Programming \& Analytics\*\*

\- SAS

\- SAS Studio

\- SAS DATA Step

\- PROC SQL



\*\*Statistical Modeling\*\*

\- Regression modeling

\- Target/mean encoding

\- Variable binning

\- Model validation

\- Decile analysis

\- Lift and gains analysis

\- Population Stability Index



\*\*Credit Risk\*\*

\- Loss Given Default (LGD)

\- Credit risk segmentation

\- Scorecard development

\- Risk ranking

\- Portfolio stability monitoring



\*\*Version Control\*\*

\- Git

\- GitHub



\---



\## 📁 Repository Structure



Credit-Risk-LGD-Scorecard-SAS/

│

├── README.md

│

├── data/

│ └── README.md

│

├── report/

│ └── Credit\_Risk\_LGD\_Scorecard\_Project\_Report.docx

│

├── sas/

│ └── Credit\_Risk\_LGD\_Scorecard\_Master.sas

│

└── screenshots/

└── \[LGD model screenshots]





\---



\## 🎯 Key Takeaways



\- Built an end-to-end Credit Risk LGD Scorecard using SAS.

\- Worked with 30,000 customer records and 25 variables.

\- Constructed a derived LGD target from available billing and payment information.

\- Applied credit-risk variable segmentation and target/mean encoding.

\- Developed a regression-based LGD prediction model.

\- Achieved a test R² of 0.1397.

\- Achieved test RMSE of 0.3020 and MAE of 0.2450.

\- Converted predicted LGD into a 300–850 scorecard.

\- Performed decile-based model validation.

\- Performed cumulative lift and gains analysis.

\- Evaluated score distribution stability using PSI.

\- Generated 8,996 out-of-sample LGD scores.

\- Built a complete and interpretable credit-risk modeling workflow in SAS.



\---



\## ⚠️ Model Scope



This project demonstrates the practical implementation of an LGD scorecard methodology using the available credit-card dataset.



Because the source dataset does not contain observed post-default recovery cash flows or contractual exposure-at-default information, the LGD target is a derived severity measure based on billing and payment behavior.



For production deployment in a banking environment, the methodology would be extended using:



\- Observed Exposure at Default (EAD)

\- Actual recovery cash flows

\- Recovery timing

\- Workout costs

\- Collateral information

\- Discounting of future recoveries

\- Default/workout cohorts

\- Economic and portfolio-level variables

\- Independent model validation

\- Model monitoring and governance



\---



\## ⚠️ Disclaimer



This project is developed for portfolio, educational, and analytical purposes.



The methodology demonstrates an end-to-end credit-risk LGD modeling and scorecard workflow. Production implementation would require institution-specific recovery data, appropriate model governance, independent validation, monitoring, documentation, and regulatory controls.



\---



\## 👤 Author



\*\*Devansh Gupta\*\*

\*Data Analyst | Data Science | Credit Risk Modeling\*



This project was developed independently as a portfolio project demonstrating practical application of:



\- SAS

\- Statistical modeling

\- Credit risk analytics

\- Scorecard development

\- Model validation

\- Data analysis



\---



\## ⭐ Project Highlights



\- \*\*Domain:\*\* Credit Risk

\- \*\*Model:\*\* Loss Given Default (LGD)

\- \*\*Technology:\*\* SAS

\- \*\*Dataset:\*\* UCI Credit Card Default Dataset

\- \*\*Records:\*\* 30,000

\- \*\*Test Records:\*\* 8,996

\- \*\*Test R²:\*\* 0.1397

\- \*\*Test RMSE:\*\* 0.3020

\- \*\*Test MAE:\*\* 0.2450

\- \*\*Score Range:\*\* 300–850

\- \*\*PSI:\*\* \~0.0002

