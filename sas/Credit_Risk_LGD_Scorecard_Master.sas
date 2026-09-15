/*========================================================================
  RETAIL BANKING LGD SCORECARD
  MODULE 01: PROJECT SETUP + DATA IMPORT + LGD TARGET CREATION
========================================================================*/

/*---------------------------------------------------------------
  1. Define project paths
----------------------------------------------------------------*/
%let PROJ_ROOT = /home/u64582537/sasuser.v94;
%let DATA_PATH = &PROJ_ROOT./raw;
%let MODEL_PATH = &PROJ_ROOT./model;
%let OUTPUT_PATH = &PROJ_ROOT./output;

/*---------------------------------------------------------------
  2. Assign SAS libraries
----------------------------------------------------------------*/
libname raw "&DATA_PATH.";
libname model "&MODEL_PATH.";
libname output "&OUTPUT_PATH.";

/*---------------------------------------------------------------
  3. Import the UCI Credit Card dataset
----------------------------------------------------------------*/
proc import
    datafile="&PROJ_ROOT./UCI_Credit_Card.csv"
    out=work.lgd_import
    dbms=csv
    replace;
    getnames=yes;
    guessingrows=max;
run;

/*---------------------------------------------------------------
  4. Create LGD proxy target
     
     Recovery Rate = Total Payments / Total Bills
     LGD           = 1 - Recovery Rate
     
     LGD is constrained to [0,1].
----------------------------------------------------------------*/
data raw.lgd_raw;
    set work.lgd_import;

    /* Total bill exposure across six months */
    Total_Bill = sum(of BILL_AMT1-BILL_AMT6);

    /* Total payments across six months */
    Total_Pay = sum(of PAY_AMT1-PAY_AMT6);

    /* Recovery rate proxy */
    if Total_Bill > 0 then
        Recovery_Rate = Total_Pay / Total_Bill;
    else
        Recovery_Rate = 1;

    /* LGD proxy */
    LGD_Actual = 1 - Recovery_Rate;

    /* Restrict LGD to valid [0,1] range */
    LGD_Actual = min(1, max(0, LGD_Actual));

    label
        LGD_Actual = "Proxy Loss Given Default [0,1]"
        Recovery_Rate = "Proxy Recovery Rate [0,1]"
        Total_Bill = "Total Bill Amount"
        Total_Pay = "Total Payment Amount";

    format
        LGD_Actual Recovery_Rate percent8.2
        Total_Bill Total_Pay comma16.2;
run;

/*---------------------------------------------------------------
  5. Basic data validation
----------------------------------------------------------------*/
title "LGD Project - Data Import Validation";

proc contents data=raw.lgd_raw;
run;

proc means data=raw.lgd_raw
    n nmiss mean std min q1 median q3 max;
    var LGD_Actual Recovery_Rate Total_Bill Total_Pay
        LIMIT_BAL AGE;
run;

title;

/*========================================================================
  MODULE 02: LGD TARGET VALIDATION & DATA QUALITY CHECK
========================================================================*/

/*---------------------------------------------------------------
  1. Check LGD target distribution
----------------------------------------------------------------*/
title "LGD Target Distribution";

proc means data=raw.lgd_raw
    n nmiss mean std min q1 median q3 max;
    var LGD_Actual Recovery_Rate Total_Bill Total_Pay;
run;

/*---------------------------------------------------------------
  2. Check LGD values outside valid range
----------------------------------------------------------------*/
title "LGD Range Validation";

proc sql;
    select
        count(*) as Total_Records,
        sum(case when LGD_Actual < 0 then 1 else 0 end) as LGD_Below_Zero,
        sum(case when LGD_Actual > 1 then 1 else 0 end) as LGD_Above_One,
        sum(case when missing(LGD_Actual) then 1 else 0 end) as LGD_Missing
    from raw.lgd_raw;
quit;

/*---------------------------------------------------------------
  3. Check duplicate customer IDs
----------------------------------------------------------------*/
title "Duplicate Customer ID Check";

proc sql;
    select
        count(*) as Total_Records,
        count(distinct ID) as Unique_IDs,
        calculated Total_Records - calculated Unique_IDs
            as Duplicate_IDs
    from raw.lgd_raw;
quit;

/*---------------------------------------------------------------
  4. Check missing values in important variables
----------------------------------------------------------------*/
title "Missing Value Audit";

proc means data=raw.lgd_raw n nmiss;
    var ID
        LIMIT_BAL
        AGE
        PAY_0
        PAY_2
        PAY_3
        PAY_4
        PAY_5
        PAY_6
        BILL_AMT1
        BILL_AMT2
        BILL_AMT3
        BILL_AMT4
        BILL_AMT5
        BILL_AMT6
        PAY_AMT1
        PAY_AMT2
        PAY_AMT3
        PAY_AMT4
        PAY_AMT5
        PAY_AMT6
        LGD_Actual;
run;

title;

/*========================================================================
  MODULE 03: DATA CLEANING & LOGICAL VALIDATION
========================================================================*/

/*---------------------------------------------------------------
  1. Remove duplicate customer IDs
----------------------------------------------------------------*/
proc sort data=raw.lgd_raw
    out=work.lgd_sorted
    nodupkey
    dupout=output.lgd_duplicate_records;
    by ID;
run;

/*---------------------------------------------------------------
  2. Clean categorical variables
----------------------------------------------------------------*/
data raw.lgd_cleaned;
    set work.lgd_sorted;

    /* Education */
    if EDUCATION in (0,5,6) or missing(EDUCATION) then
        EDUCATION = 4;

    /* Marriage */
    if MARRIAGE = 0 or missing(MARRIAGE) then
        MARRIAGE = 3;

    /* Payment status */
    array pay_vars[*]
        PAY_0 PAY_2 PAY_3 PAY_4 PAY_5 PAY_6;

    do i = 1 to dim(pay_vars);
        if pay_vars[i] < 0 then
            pay_vars[i] = 0;
    end;

    /*-----------------------------------------------------------
      Logical corrections for monetary variables
    -----------------------------------------------------------*/

    /* Negative bill amounts are retained as credit balances.
       Payment amounts are constrained to non-negative values. */
    array pay_amt[*]
        PAY_AMT1 PAY_AMT2 PAY_AMT3
        PAY_AMT4 PAY_AMT5 PAY_AMT6;

    do j = 1 to dim(pay_amt);
        if pay_amt[j] < 0 then
            pay_amt[j] = 0;
    end;

    /* Recalculate total payments after cleaning */
    Total_Pay = sum(of PAY_AMT1-PAY_AMT6);

    /* Recalculate recovery rate */
    if Total_Bill > 0 then
        Recovery_Rate = Total_Pay / Total_Bill;
    else
        Recovery_Rate = 1;

    /* Cap recovery rate for logical consistency */
    Recovery_Rate = min(1, max(0, Recovery_Rate));

    /* Recalculate LGD */
    LGD_Actual = 1 - Recovery_Rate;

    /* Final LGD bounds */
    LGD_Actual = min(1, max(0, LGD_Actual));

    drop i j;
run;

/*---------------------------------------------------------------
  3. Validate cleaned dataset
----------------------------------------------------------------*/
title "LGD Cleaned Dataset Validation";

proc contents data=raw.lgd_cleaned;
run;

proc means data=raw.lgd_cleaned
    n nmiss mean std min q1 median q3 max;
    var LGD_Actual Recovery_Rate
        Total_Bill Total_Pay
        LIMIT_BAL AGE;
run;

/*---------------------------------------------------------------
  4. Categorical distribution checks
----------------------------------------------------------------*/
title "Categorical Variable Distribution";

proc freq data=raw.lgd_cleaned;
    tables SEX EDUCATION MARRIAGE PAY_0 / missing;
run;

title;

/*========================================================================
  MODULE 04: EXPLORATORY DATA ANALYSIS (EDA)
========================================================================*/

/*---------------------------------------------------------------
  1. Overall LGD distribution
----------------------------------------------------------------*/
title "Overall LGD Distribution";

proc means data=raw.lgd_cleaned
    n mean std min q1 median q3 max;
    var LGD_Actual;
run;

/*---------------------------------------------------------------
  2. LGD by repayment status
----------------------------------------------------------------*/
title "Mean LGD by Repayment Status";

proc means data=raw.lgd_cleaned
    n mean std min q1 median q3 max;
    class PAY_0;
    var LGD_Actual;
run;

/*---------------------------------------------------------------
  3. LGD by credit limit
----------------------------------------------------------------*/
title "Mean LGD by Credit Limit";

proc means data=raw.lgd_cleaned
    n mean std min q1 median q3 max;
    class LIMIT_BAL;
    var LGD_Actual;
run;

/*---------------------------------------------------------------
  4. LGD by age
----------------------------------------------------------------*/
title "Mean LGD by Age";

proc means data=raw.lgd_cleaned
    n mean std min q1 median q3 max;
    class AGE;
    var LGD_Actual;
run;

/*---------------------------------------------------------------
  5. LGD by customer demographics
----------------------------------------------------------------*/
title "Mean LGD by Sex, Education and Marriage";

proc means data=raw.lgd_cleaned
    n mean std min q1 median q3 max;
    class SEX EDUCATION MARRIAGE;
    var LGD_Actual;
run;

/*---------------------------------------------------------------
  6. Correlation analysis
----------------------------------------------------------------*/
title "LGD Feature Correlation Analysis";

proc corr data=raw.lgd_cleaned;
    var LGD_Actual
        LIMIT_BAL
        AGE
        PAY_0
        PAY_2
        PAY_3
        PAY_4
        PAY_5
        PAY_6
        BILL_AMT1
        BILL_AMT2
        PAY_AMT1
        PAY_AMT2;
run;

title;

/*========================================================================
  MODULE 05: MISSING VALUE & TARGET DISTRIBUTION AUDIT
========================================================================*/

/*---------------------------------------------------------------
  1. Missing-value audit
----------------------------------------------------------------*/
title "LGD Feature Missing Value Audit";

proc means data=raw.lgd_cleaned n nmiss;
    var
        LIMIT_BAL
        SEX
        EDUCATION
        MARRIAGE
        AGE
        PAY_0
        PAY_2
        PAY_3
        PAY_4
        PAY_5
        PAY_6
        BILL_AMT1
        BILL_AMT2
        BILL_AMT3
        BILL_AMT4
        BILL_AMT5
        BILL_AMT6
        PAY_AMT1
        PAY_AMT2
        PAY_AMT3
        PAY_AMT4
        PAY_AMT5
        PAY_AMT6
        Total_Bill
        Total_Pay
        Recovery_Rate
        LGD_Actual;
run;

/*---------------------------------------------------------------
  2. LGD distribution using fine-class bands
----------------------------------------------------------------*/
title "LGD Distribution by Risk Band";

proc format;
    value lgd_band
        0 - <0.10 = "01: 0-10%"
        0.10 - <0.25 = "02: 10-25%"
        0.25 - <0.50 = "03: 25-50%"
        0.50 - <0.75 = "04: 50-75%"
        0.75 - <0.90 = "05: 75-90%"
        0.90 - high = "06: 90-100%";
run;

proc freq data=raw.lgd_cleaned;
    tables LGD_Actual / missing;
    format LGD_Actual lgd_band.;
run;

/*---------------------------------------------------------------
  3. Count extreme LGD observations
----------------------------------------------------------------*/
title "Extreme LGD Observation Audit";

proc sql;
    select
        count(*) as Total_Records,
        sum(case when LGD_Actual = 0 then 1 else 0 end)
            as Zero_LGD_Count,
        sum(case when LGD_Actual = 1 then 1 else 0 end)
            as Full_LGD_Count,
        sum(case when LGD_Actual > 0.90 then 1 else 0 end)
            as LGD_Above_90pct,
        sum(case when LGD_Actual < 0.10 then 1 else 0 end)
            as LGD_Below_10pct
    from raw.lgd_cleaned;
quit;

title;

/*========================================================================
  MODULE 06: OUTLIER DETECTION & WINSORIZATION
========================================================================*/

/*---------------------------------------------------------------
  1. Calculate 1st and 99th percentiles
----------------------------------------------------------------*/
title "LGD Feature Outlier Thresholds";

proc univariate data=raw.lgd_cleaned noprint;
    var
        LIMIT_BAL
        BILL_AMT1 BILL_AMT2 BILL_AMT3
        BILL_AMT4 BILL_AMT5 BILL_AMT6
        PAY_AMT1 PAY_AMT2 PAY_AMT3
        PAY_AMT4 PAY_AMT5 PAY_AMT6;

    output out=work.lgd_percentiles
        p1 =
            P1_LIMIT_BAL
            P1_B1 P1_B2 P1_B3 P1_B4 P1_B5 P1_B6
            P1_P1 P1_P2 P1_P3 P1_P4 P1_P5 P1_P6
        p99 =
            P99_LIMIT_BAL
            P99_B1 P99_B2 P99_B3 P99_B4 P99_B5 P99_B6
            P99_P1 P99_P2 P99_P3 P99_P4 P99_P5 P99_P6;
run;

/*---------------------------------------------------------------
  2. Winsorize monetary variables
----------------------------------------------------------------*/
data raw.lgd_treated;
    if _N_ = 1 then set work.lgd_percentiles;
    set raw.lgd_cleaned;

    /* Credit limit */
    LIMIT_BAL =
        min(max(LIMIT_BAL,P1_LIMIT_BAL),P99_LIMIT_BAL);

    /* Bill amounts */
    BILL_AMT1 = min(max(BILL_AMT1,P1_B1),P99_B1);
    BILL_AMT2 = min(max(BILL_AMT2,P1_B2),P99_B2);
    BILL_AMT3 = min(max(BILL_AMT3,P1_B3),P99_B3);
    BILL_AMT4 = min(max(BILL_AMT4,P1_B4),P99_B4);
    BILL_AMT5 = min(max(BILL_AMT5,P1_B5),P99_B5);
    BILL_AMT6 = min(max(BILL_AMT6,P1_B6),P99_B6);

    /* Payment amounts */
    PAY_AMT1 = min(max(PAY_AMT1,P1_P1),P99_P1);
    PAY_AMT2 = min(max(PAY_AMT2,P1_P2),P99_P2);
    PAY_AMT3 = min(max(PAY_AMT3,P1_P3),P99_P3);
    PAY_AMT4 = min(max(PAY_AMT4,P1_P4),P99_P4);
    PAY_AMT5 = min(max(PAY_AMT5,P1_P5),P99_P5);
    PAY_AMT6 = min(max(PAY_AMT6,P1_P6),P99_P6);

    /* Recalculate exposure and recovery metrics */
    Total_Bill = sum(of BILL_AMT1-BILL_AMT6);
    Total_Pay  = sum(of PAY_AMT1-PAY_AMT6);

    if Total_Bill > 0 then
        Recovery_Rate = Total_Pay / Total_Bill;
    else
        Recovery_Rate = 1;

    Recovery_Rate = min(1,max(0,Recovery_Rate));

    LGD_Actual = 1 - Recovery_Rate;
    LGD_Actual = min(1,max(0,LGD_Actual));

    drop
        P1_: P99_:;
run;

/*---------------------------------------------------------------
  3. Compare before vs after treatment
----------------------------------------------------------------*/
title "LGD Treated Dataset Summary";

proc means data=raw.lgd_treated
    n nmiss mean std min q1 median q3 max;
    var
        LGD_Actual
        LIMIT_BAL
        BILL_AMT1
        PAY_AMT1
        Total_Bill
        Total_Pay;
run;

/*---------------------------------------------------------------
  4. Validate LGD target after treatment
----------------------------------------------------------------*/
title "LGD Target Post-Treatment Validation";

proc sql;
    select
        count(*) as Total_Records,
        sum(case when LGD_Actual < 0 then 1 else 0 end)
            as LGD_Below_Zero,
        sum(case when LGD_Actual > 1 then 1 else 0 end)
            as LGD_Above_One,
        sum(case when missing(LGD_Actual) then 1 else 0 end)
            as LGD_Missing
    from raw.lgd_treated;
quit;

title;

/*========================================================================
  MODULE 07: STRATIFIED TRAIN / TEST SPLIT FOR LGD MODELING
========================================================================*/

/*---------------------------------------------------------------
  1. Create LGD bands for stratification
----------------------------------------------------------------*/
data work.lgd_split_base;
    set raw.lgd_treated;

    length LGD_Band $20;

    if LGD_Actual < 0.10 then
        LGD_Band = "01: 0-10%";
    else if LGD_Actual < 0.25 then
        LGD_Band = "02: 10-25%";
    else if LGD_Actual < 0.50 then
        LGD_Band = "03: 25-50%";
    else if LGD_Actual < 0.75 then
        LGD_Band = "04: 50-75%";
    else if LGD_Actual < 0.90 then
        LGD_Band = "05: 75-90%";
    else
        LGD_Band = "06: 90-100%";
run;

/*---------------------------------------------------------------
  2. Sort by stratification variable
----------------------------------------------------------------*/
proc sort data=work.lgd_split_base
          out=work.lgd_split_sorted;
    by LGD_Band;
run;

/*---------------------------------------------------------------
  3. Stratified 70/30 sample
----------------------------------------------------------------*/
proc surveyselect data=work.lgd_split_sorted
    out=work.lgd_sample
    samprate=0.70
    method=srs
    seed=98765432
    outall;
    strata LGD_Band;
run;

/*---------------------------------------------------------------
  4. Create permanent training and test datasets
----------------------------------------------------------------*/
data raw.lgd_train
     raw.lgd_test;

    set work.lgd_sample;

    if Selected = 1 then
        output raw.lgd_train;
    else
        output raw.lgd_test;
run;

/*---------------------------------------------------------------
  5. Training dataset validation
----------------------------------------------------------------*/
title "LGD Training Dataset Validation";

proc means data=raw.lgd_train
    n mean std min q1 median q3 max;
    var LGD_Actual;
run;

/*---------------------------------------------------------------
  6. Test dataset validation
----------------------------------------------------------------*/
title "LGD Test Dataset Validation";

proc means data=raw.lgd_test
    n mean std min q1 median q3 max;
    var LGD_Actual;
run;

/*---------------------------------------------------------------
  7. Compare LGD bands across train and test
----------------------------------------------------------------*/
title "LGD Band Distribution - Train vs Test";

proc freq data=raw.lgd_train;
    tables LGD_Band;
run;

proc freq data=raw.lgd_test;
    tables LGD_Band;
run;

title;

/*========================================================================
  MODULE 08: LGD VARIABLE BINNING & MEAN SEVERITY ANALYSIS
========================================================================*/

/*---------------------------------------------------------------
  1. Create business-oriented bins
----------------------------------------------------------------*/
data raw.lgd_binned_train;
    set raw.lgd_train;

    length
        BIN_PAY_0 $30
        BIN_AGE $30
        BIN_LIMIT_BAL $30;

    /*-----------------------------------------------------------
      PAY_0 repayment-status bins
    -----------------------------------------------------------*/
    if PAY_0 = 0 then
        BIN_PAY_0 = "01: Duly Paid/No Delay";
    else if PAY_0 = 1 then
        BIN_PAY_0 = "02: 1 Month Delay";
    else if PAY_0 = 2 then
        BIN_PAY_0 = "03: 2 Months Delay";
    else if PAY_0 >= 3 then
        BIN_PAY_0 = "04: 3+ Months Delay";
    else
        BIN_PAY_0 = "01: Duly Paid/No Delay";

    /*-----------------------------------------------------------
      AGE bins
    -----------------------------------------------------------*/
    if AGE < 25 then
        BIN_AGE = "01: <25";
    else if AGE < 35 then
        BIN_AGE = "02: 25-34";
    else if AGE < 45 then
        BIN_AGE = "03: 35-44";
    else if AGE < 55 then
        BIN_AGE = "04: 45-54";
    else
        BIN_AGE = "05: 55+";

    /*-----------------------------------------------------------
      Credit-limit bins
    -----------------------------------------------------------*/
    if LIMIT_BAL <= 50000 then
        BIN_LIMIT_BAL = "01: <= 50k";
    else if LIMIT_BAL <= 100000 then
        BIN_LIMIT_BAL = "02: 50k-100k";
    else if LIMIT_BAL <= 200000 then
        BIN_LIMIT_BAL = "03: 100k-200k";
    else
        BIN_LIMIT_BAL = "04: > 200k";
run;

/*---------------------------------------------------------------
  2. Calculate mean LGD by PAY_0 bin
----------------------------------------------------------------*/
title "Mean LGD by PAY_0 Bin";

proc means data=raw.lgd_binned_train
    n mean std min q1 median q3 max;
    class BIN_PAY_0;
    var LGD_Actual;
run;

/*---------------------------------------------------------------
  3. Calculate mean LGD by AGE bin
----------------------------------------------------------------*/
title "Mean LGD by AGE Bin";

proc means data=raw.lgd_binned_train
    n mean std min q1 median q3 max;
    class BIN_AGE;
    var LGD_Actual;
run;

/*---------------------------------------------------------------
  4. Calculate mean LGD by LIMIT_BAL bin
----------------------------------------------------------------*/
title "Mean LGD by Credit Limit Bin";

proc means data=raw.lgd_binned_train
    n mean std min q1 median q3 max;
    class BIN_LIMIT_BAL;
    var LGD_Actual;
run;

/*---------------------------------------------------------------
  5. Create consolidated severity summary
----------------------------------------------------------------*/
proc sql;

    create table output.lgd_bin_summary as

    select
        "PAY_0" as Variable length=32,
        BIN_PAY_0 as Bin_Value length=50,
        count(*) as Total_Accounts,
        mean(LGD_Actual) as Mean_LGD format=percent8.2,
        std(LGD_Actual) as Std_LGD format=8.4,
        min(LGD_Actual) as Min_LGD format=percent8.2,
        max(LGD_Actual) as Max_LGD format=percent8.2

    from raw.lgd_binned_train
    group by BIN_PAY_0;

    insert into output.lgd_bin_summary

    select
        "AGE" as Variable length=32,
        BIN_AGE as Bin_Value length=50,
        count(*) as Total_Accounts,
        mean(LGD_Actual) as Mean_LGD format=percent8.2,
        std(LGD_Actual) as Std_LGD format=8.4,
        min(LGD_Actual) as Min_LGD format=percent8.2,
        max(LGD_Actual) as Max_LGD format=percent8.2

    from raw.lgd_binned_train
    group by BIN_AGE;

    insert into output.lgd_bin_summary

    select
        "LIMIT_BAL" as Variable length=32,
        BIN_LIMIT_BAL as Bin_Value length=50,
        count(*) as Total_Accounts,
        mean(LGD_Actual) as Mean_LGD format=percent8.2,
        std(LGD_Actual) as Std_LGD format=8.4,
        min(LGD_Actual) as Min_LGD format=percent8.2,
        max(LGD_Actual) as Max_LGD format=percent8.2

    from raw.lgd_binned_train
    group by BIN_LIMIT_BAL;

quit;

/*---------------------------------------------------------------
  6. Print consolidated LGD severity table
----------------------------------------------------------------*/
title "LGD Variable Binning & Mean Severity Summary";

proc print data=output.lgd_bin_summary noobs;
run;

title;

/*========================================================================
  MODULE 09: MEAN LGD TARGET ENCODING
========================================================================*/

/*---------------------------------------------------------------
  1. Create PAY_0 severity statistics
----------------------------------------------------------------*/
proc sql;

    create table work.stats_pay_0 as
    select
        "PAY_0" as Variable length=32,
        BIN_PAY_0 as Bin_Value length=50,
        count(*) as Total_Accounts,
        mean(LGD_Actual) as Mean_LGD format=percent8.2,
        std(LGD_Actual) as Std_LGD format=8.4,
        min(LGD_Actual) as Min_LGD format=percent8.2,
        max(LGD_Actual) as Max_LGD format=percent8.2
    from raw.lgd_binned_train
    group by BIN_PAY_0;

/*---------------------------------------------------------------
  2. Create AGE severity statistics
----------------------------------------------------------------*/

    create table work.stats_age as
    select
        "AGE" as Variable length=32,
        BIN_AGE as Bin_Value length=50,
        count(*) as Total_Accounts,
        mean(LGD_Actual) as Mean_LGD format=percent8.2,
        std(LGD_Actual) as Std_LGD format=8.4,
        min(LGD_Actual) as Min_LGD format=percent8.2,
        max(LGD_Actual) as Max_LGD format=percent8.2
    from raw.lgd_binned_train
    group by BIN_AGE;

/*---------------------------------------------------------------
  3. Create LIMIT_BAL severity statistics
----------------------------------------------------------------*/

    create table work.stats_limit as
    select
        "LIMIT_BAL" as Variable length=32,
        BIN_LIMIT_BAL as Bin_Value length=50,
        count(*) as Total_Accounts,
        mean(LGD_Actual) as Mean_LGD format=percent8.2,
        std(LGD_Actual) as Std_LGD format=8.4,
        min(LGD_Actual) as Min_LGD format=percent8.2,
        max(LGD_Actual) as Max_LGD format=percent8.2
    from raw.lgd_binned_train
    group by BIN_LIMIT_BAL;

quit;

/*---------------------------------------------------------------
  4. Combine encoding tables
----------------------------------------------------------------*/
data output.lgd_encoding_dictionary;
    set
        work.stats_pay_0
        work.stats_age
        work.stats_limit;
run;

/*---------------------------------------------------------------
  5. Apply mean-LGD encoding to training data
----------------------------------------------------------------*/
proc sql;

    create table raw.lgd_model_train as

    select
        a.*,

        /* PAY_0 encoded severity */
        w1.Mean_LGD as ENC_PAY_0,

        /* AGE encoded severity */
        w2.Mean_LGD as ENC_AGE,

        /* LIMIT_BAL encoded severity */
        w3.Mean_LGD as ENC_LIMIT_BAL

    from raw.lgd_binned_train as a

    left join work.stats_pay_0 as w1
        on a.BIN_PAY_0 = w1.Bin_Value

    left join work.stats_age as w2
        on a.BIN_AGE = w2.Bin_Value

    left join work.stats_limit as w3
        on a.BIN_LIMIT_BAL = w3.Bin_Value;

quit;

/*---------------------------------------------------------------
  6. Validate encoded variables
----------------------------------------------------------------*/
title "Mean LGD Encoding Validation";

proc means data=raw.lgd_model_train
    n nmiss mean std min q1 median q3 max;
    var
        LGD_Actual
        ENC_PAY_0
        ENC_AGE
        ENC_LIMIT_BAL;
run;

/*---------------------------------------------------------------
  7. Display encoding dictionary
----------------------------------------------------------------*/
title "LGD Mean Encoding Dictionary";

proc print data=output.lgd_encoding_dictionary noobs;
run;

title;

/*========================================================================
  MODULE 10: CORRELATION & VIF / MULTICOLLINEARITY ANALYSIS
========================================================================*/

/*---------------------------------------------------------------
  1. Correlation among LGD-encoded predictors
----------------------------------------------------------------*/
title "LGD Model Feature Correlation Matrix";

proc corr data=raw.lgd_model_train
          pearson
          nosimple;
    var
        ENC_PAY_0
        ENC_AGE
        ENC_LIMIT_BAL;
run;

/*---------------------------------------------------------------
  2. VIF and tolerance diagnostics
----------------------------------------------------------------*/
title "LGD Model VIF / Multicollinearity Diagnostics";

ods select ParameterEstimates ANOVA FitStatistics;

proc reg data=raw.lgd_model_train;
    model LGD_Actual =
        ENC_PAY_0
        ENC_AGE
        ENC_LIMIT_BAL
        / vif tol;
run;
quit;

ods select all;

title;

/*========================================================================
  MODULE 11: FINAL LGD REGRESSION MODEL
========================================================================*/

/*---------------------------------------------------------------
  1. Fit final LGD regression model
----------------------------------------------------------------*/
title "Final LGD Regression Model";

proc reg data=raw.lgd_model_train
          outest=output.lgd_model_coefficients
          plots=none;

    model LGD_Actual =
        ENC_PAY_0
        ENC_AGE
        ENC_LIMIT_BAL
        / stb;

    output out=work.lgd_train_scored
        p=LGD_Predicted
        r=Residual
        student=Studentized_Residual;
run;

quit;

/*---------------------------------------------------------------
  2. Constrain predicted LGD to valid [0,1] range
----------------------------------------------------------------*/
data work.lgd_train_scored;

    set work.lgd_train_scored;

    LGD_Predicted_Raw = LGD_Predicted;

    LGD_Predicted =
        min(1,max(0,LGD_Predicted));

    Abs_Error =
        abs(LGD_Actual - LGD_Predicted);

    Squared_Error =
        (LGD_Actual - LGD_Predicted)**2;

run;

/*---------------------------------------------------------------
  3. Store final training scoring dataset
----------------------------------------------------------------*/
data raw.lgd_scored_train;

    set work.lgd_train_scored;

run;

/*---------------------------------------------------------------
  4. Calculate model error metrics
----------------------------------------------------------------*/
proc sql;

    create table output.lgd_model_performance as

    select

        count(*) as N,

        mean(LGD_Actual) as Mean_Actual_LGD
            format=percent8.2,

        mean(LGD_Predicted) as Mean_Predicted_LGD
            format=percent8.2,

        sqrt(mean(Squared_Error)) as RMSE
            format=8.4,

        mean(Abs_Error) as MAE
            format=8.4,

        1 -
        (
            sum(Squared_Error) /
            sum((LGD_Actual -
                (select mean(LGD_Actual)
                 from raw.lgd_model_train))**2)
        ) as R_Squared
            format=8.4

    from work.lgd_train_scored;

quit;

/*---------------------------------------------------------------
  5. Print model coefficients
----------------------------------------------------------------*/
title "Final LGD Regression Coefficients";

proc print data=output.lgd_model_coefficients noobs;
run;

/*---------------------------------------------------------------
  6. Print model performance
----------------------------------------------------------------*/
title "LGD Model Performance Metrics";

proc print data=output.lgd_model_performance noobs;
run;

title;

/*========================================================================
  MODULE 12: LGD RESIDUAL DIAGNOSTICS & ERROR ANALYSIS
========================================================================*/

title "LGD Residual Diagnostics";

/*---------------------------------------------------------------
  1. Create detailed residual metrics
----------------------------------------------------------------*/
data output.lgd_residual_diagnostics;

    set raw.lgd_scored_train;

    /* Absolute error */
    Abs_Error =
        abs(LGD_Actual - LGD_Predicted);

    /* Squared error */
    Squared_Error =
        (LGD_Actual - LGD_Predicted)**2;

    /* Signed residual */
    Residual =
        LGD_Actual - LGD_Predicted;

    /* Absolute percentage error where LGD > 0 */
    if LGD_Actual > 0 then
        Abs_Percent_Error =
            abs(Residual) / LGD_Actual;
    else
        Abs_Percent_Error = .;

    format
        LGD_Actual
        LGD_Predicted
        Residual
        Abs_Error
        Abs_Percent_Error
        percent8.2;

run;

/*---------------------------------------------------------------
  2. Summary of residual performance
----------------------------------------------------------------*/
title "LGD Residual Summary";

proc means data=output.lgd_residual_diagnostics
    n mean std min q1 median q3 max;
    var
        Residual
        Abs_Error
        Squared_Error
        Abs_Percent_Error;
run;

/*---------------------------------------------------------------
  3. Residual behavior by LGD band
----------------------------------------------------------------*/
proc format;
    value lgd_band
        0 - <0.10 = "01: 0-10%"
        0.10 - <0.25 = "02: 10-25%"
        0.25 - <0.50 = "03: 25-50%"
        0.50 - <0.75 = "04: 50-75%"
        0.75 - <0.90 = "05: 75-90%"
        0.90 - high = "06: 90-100%";
run;

title "Residual Performance by LGD Band";

proc means data=output.lgd_residual_diagnostics
    n mean std;
    class LGD_Actual;
    var Abs_Error Residual;
    format LGD_Actual lgd_band.;
run;

/*---------------------------------------------------------------
  4. Count large prediction errors
----------------------------------------------------------------*/
title "Large LGD Prediction Error Audit";

proc sql;

    select
        count(*) as Total_Records,

        sum(case
            when Abs_Error > 0.10
            then 1 else 0
        end) as Error_Above_10pct,

        sum(case
            when Abs_Error > 0.20
            then 1 else 0
        end) as Error_Above_20pct,

        sum(case
            when Abs_Error > 0.30
            then 1 else 0
        end) as Error_Above_30pct

    from output.lgd_residual_diagnostics;

quit;

title;

/*========================================================================
  MODULE 13: OUT-OF-SAMPLE TEST SCORING & LGD MODEL VALIDATION
========================================================================*/

/*---------------------------------------------------------------
  1. Create the same bins on the test population
----------------------------------------------------------------*/
data raw.lgd_binned_test;
    set raw.lgd_test;

    length
        BIN_PAY_0 $30
        BIN_AGE $30
        BIN_LIMIT_BAL $30;

    /* PAY_0 */
    if PAY_0 = 0 then
        BIN_PAY_0 = "01: Duly Paid/No Delay";
    else if PAY_0 = 1 then
        BIN_PAY_0 = "02: 1 Month Delay";
    else if PAY_0 = 2 then
        BIN_PAY_0 = "03: 2 Months Delay";
    else if PAY_0 >= 3 then
        BIN_PAY_0 = "04: 3+ Months Delay";
    else
        BIN_PAY_0 = "01: Duly Paid/No Delay";

    /* AGE */
    if AGE < 25 then
        BIN_AGE = "01: <25";
    else if AGE < 35 then
        BIN_AGE = "02: 25-34";
    else if AGE < 45 then
        BIN_AGE = "03: 35-44";
    else if AGE < 55 then
        BIN_AGE = "04: 45-54";
    else
        BIN_AGE = "05: 55+";

    /* LIMIT_BAL */
    if LIMIT_BAL <= 50000 then
        BIN_LIMIT_BAL = "01: <= 50k";
    else if LIMIT_BAL <= 100000 then
        BIN_LIMIT_BAL = "02: 50k-100k";
    else if LIMIT_BAL <= 200000 then
        BIN_LIMIT_BAL = "03: 100k-200k";
    else
        BIN_LIMIT_BAL = "04: > 200k";
run;

/*---------------------------------------------------------------
  2. Apply TRAINING encoding dictionary to TEST data
----------------------------------------------------------------*/
proc sql;

    create table raw.lgd_model_test as

    select
        a.*,

        /* Training-derived encoding */
        coalesce(
            p.Mean_LGD,
            (select mean(LGD_Actual)
             from raw.lgd_model_train)
        ) as ENC_PAY_0,

        coalesce(
            ag.Mean_LGD,
            (select mean(LGD_Actual)
             from raw.lgd_model_train)
        ) as ENC_AGE,

        coalesce(
            l.Mean_LGD,
            (select mean(LGD_Actual)
             from raw.lgd_model_train)
        ) as ENC_LIMIT_BAL

    from raw.lgd_binned_test as a

    left join work.stats_pay_0 as p
        on a.BIN_PAY_0 = p.Bin_Value

    left join work.stats_age as ag
        on a.BIN_AGE = ag.Bin_Value

    left join work.stats_limit as l
        on a.BIN_LIMIT_BAL = l.Bin_Value;

quit;

/*---------------------------------------------------------------
  3. Extract final regression coefficients
----------------------------------------------------------------*/
proc sql noprint;

    select Intercept,
           ENC_PAY_0,
           ENC_AGE,
           ENC_LIMIT_BAL

    into :LGD_INTERCEPT,
         :LGD_BETA_PAY,
         :LGD_BETA_AGE,
         :LGD_BETA_LIMIT

    from output.lgd_model_coefficients;

quit;

/*---------------------------------------------------------------
  4. Score test population
----------------------------------------------------------------*/
data raw.lgd_scored_test;

    set raw.lgd_model_test;

    LGD_Predicted_Raw =
          &LGD_INTERCEPT.
        + (&LGD_BETA_PAY.   * ENC_PAY_0)
        + (&LGD_BETA_AGE.   * ENC_AGE)
        + (&LGD_BETA_LIMIT. * ENC_LIMIT_BAL);

    /* Bound prediction to valid LGD range */
    LGD_Predicted =
        min(1,max(0,LGD_Predicted_Raw));

    /* Errors */
    Residual =
        LGD_Actual - LGD_Predicted;

    Abs_Error =
        abs(Residual);

    Squared_Error =
        Residual**2;

run;

/*---------------------------------------------------------------
  5. Calculate out-of-sample performance
----------------------------------------------------------------*/
proc sql;

    create table output.lgd_test_performance as

    select

        count(*) as N,

        mean(LGD_Actual) as Mean_Actual_LGD
            format=percent8.2,

        mean(LGD_Predicted) as Mean_Predicted_LGD
            format=percent8.2,

        sqrt(mean(Squared_Error)) as RMSE
            format=8.4,

        mean(Abs_Error) as MAE
            format=8.4,

        1 -
        (
            sum(Squared_Error) /
            sum(
                (LGD_Actual -
                (select mean(LGD_Actual)
                 from raw.lgd_test))**2
            )
        ) as R_Squared
            format=8.4

    from raw.lgd_scored_test;

quit;

/*---------------------------------------------------------------
  6. Compare TRAIN vs TEST performance
----------------------------------------------------------------*/
data output.lgd_model_validation;

    length Dataset $10;

    set
        output.lgd_model_performance(in=Train)
        output.lgd_test_performance(in=Test);

    if Train then
        Dataset = "TRAIN";
    else if Test then
        Dataset = "TEST";

run;

title "LGD Out-of-Sample Model Validation";

proc print data=output.lgd_model_validation noobs;
run;

/*---------------------------------------------------------------
  7. Test-set prediction distribution
----------------------------------------------------------------*/
title "Test Set LGD Prediction Distribution";

proc means data=raw.lgd_scored_test
    n mean std min q1 median q3 max;
    var LGD_Actual LGD_Predicted;
run;

title;

/*========================================================================
  MODULE 14: LGD DECILE & RANK-ORDERING VALIDATION
========================================================================*/

/*---------------------------------------------------------------
  1. Rank TEST customers by predicted LGD
     Highest predicted LGD = highest severity risk
----------------------------------------------------------------*/
proc rank data=raw.lgd_scored_test
          out=work.lgd_ranked_test
          groups=10
          descending;

    var LGD_Predicted;
    ranks LGD_Decile;

run;

/*---------------------------------------------------------------
  2. Convert SAS ranks 0-9 into deciles 1-10
----------------------------------------------------------------*/
data work.lgd_ranked_test;

    set work.lgd_ranked_test;

    Risk_Decile = LGD_Decile + 1;

run;

/*---------------------------------------------------------------
  3. Calculate actual and predicted LGD by decile
----------------------------------------------------------------*/
proc summary data=work.lgd_ranked_test
             nway;

    class Risk_Decile;

    var LGD_Actual LGD_Predicted;

    output out=output.lgd_decile_validation
        n=Accounts
        mean(LGD_Actual)=Mean_Actual_LGD
        mean(LGD_Predicted)=Mean_Predicted_LGD;

run;

/*---------------------------------------------------------------
  4. Calculate decile-level prediction error
----------------------------------------------------------------*/
data output.lgd_decile_validation;

    set output.lgd_decile_validation;

    Prediction_Gap =
        Mean_Actual_LGD - Mean_Predicted_LGD;

    format
        Mean_Actual_LGD
        Mean_Predicted_LGD
        Prediction_Gap
        percent8.2;

    drop _TYPE_ _FREQ_;

run;

/*---------------------------------------------------------------
  5. Sort from highest predicted LGD to lowest
----------------------------------------------------------------*/
proc sort data=output.lgd_decile_validation;
    by Risk_Decile;
run;

/*---------------------------------------------------------------
  6. Display validation table
----------------------------------------------------------------*/
title "LGD Risk Decile Rank-Ordering Validation";

proc print data=output.lgd_decile_validation
          noobs;

    var
        Risk_Decile
        Accounts
        Mean_Actual_LGD
        Mean_Predicted_LGD
        Prediction_Gap;

run;

/*---------------------------------------------------------------
  7. Calculate overall rank-ordering range
----------------------------------------------------------------*/
proc sql;

    create table output.lgd_rank_order_summary as

    select
        min(Mean_Actual_LGD) as Minimum_Decile_Actual_LGD
            format=percent8.2,

        max(Mean_Actual_LGD) as Maximum_Decile_Actual_LGD
            format=percent8.2,

        max(Mean_Actual_LGD) -
        min(Mean_Actual_LGD) as LGD_Decile_Range
            format=percent8.2

    from output.lgd_decile_validation;

quit;

title "LGD Rank-Ordering Summary";

proc print data=output.lgd_rank_order_summary noobs;
run;

title;

/*========================================================================
  MODULE 15: LGD SEVERITY SCORECARD SCALING
========================================================================*/

/*---------------------------------------------------------------
  1. Define scorecard parameters
----------------------------------------------------------------*/
%let BASE_SCORE = 600;
%let BASE_ODDS  = 50;
%let PDO        = 20;

/*---------------------------------------------------------------
  2. Calculate score scaling parameters
----------------------------------------------------------------*/
data work.lgd_score_scaling_parameters;

    Factor =
        &PDO. / log(2);

    Offset =
        &BASE_SCORE. -
        (Factor * log(&BASE_ODDS.));

    Base_Score = &BASE_SCORE.;
    Base_Odds  = &BASE_ODDS.;
    PDO_Value  = &PDO.;

    format
        Factor
        Offset
        12.6;

run;

/*---------------------------------------------------------------
  3. Extract final regression coefficients
----------------------------------------------------------------*/
proc sql noprint;

    select
        Intercept,
        ENC_PAY_0,
        ENC_AGE,
        ENC_LIMIT_BAL

    into
        :S_INTERCEPT,
        :S_BETA_PAY,
        :S_BETA_AGE,
        :S_BETA_LIMIT

    from output.lgd_model_coefficients;

quit;

/*---------------------------------------------------------------
  4. Score TRAIN population
----------------------------------------------------------------*/
data raw.lgd_scorecard_train;

    set raw.lgd_model_train;

    /* Calculate predicted LGD from final regression */
    LGD_Predicted =
          &S_INTERCEPT.
        + (&S_BETA_PAY.   * ENC_PAY_0)
        + (&S_BETA_AGE.   * ENC_AGE)
        + (&S_BETA_LIMIT. * ENC_LIMIT_BAL);

    /* Restrict predicted LGD */
    LGD_Predicted =
        min(0.9999,max(0.0001,LGD_Predicted));

    /* LGD odds */
    LGD_Odds =
        LGD_Predicted /
        (1 - LGD_Predicted);

    /* Log-odds of LGD */
    LGD_Logit =
        log(LGD_Odds);

    /* Score scaling */
    LGD_Score =
        round(
            &BASE_SCORE.
            - (
                (&PDO. / log(2))
                * LGD_Logit
              )
        );

    /* Keep score in standard range */
    if LGD_Score < 300 then
        LGD_Score = 300;

    if LGD_Score > 850 then
        LGD_Score = 850;

run;

/*---------------------------------------------------------------
  5. Score TEST population
----------------------------------------------------------------*/
data raw.lgd_scorecard_test;

    set raw.lgd_scored_test;

    /* Use the same score transformation */
    LGD_Score =
        round(
            &BASE_SCORE.
            - (
                (&PDO. / log(2))
                *
                log(
                    LGD_Predicted /
                    (1 - LGD_Predicted)
                )
              )
        );

    /* Keep score within standard range */
    if LGD_Score < 300 then
        LGD_Score = 300;

    if LGD_Score > 850 then
        LGD_Score = 850;

run;

/*---------------------------------------------------------------
  6. Save score scaling parameters
----------------------------------------------------------------*/
data output.lgd_score_scaling;

    set work.lgd_score_scaling_parameters;

run;

/*---------------------------------------------------------------
  7. Score distribution
----------------------------------------------------------------*/
title "LGD Severity Score Distribution";

proc means data=raw.lgd_scorecard_train
    n mean std min q1 median q3 max;

    var LGD_Predicted LGD_Score;

run;

/*---------------------------------------------------------------
  8. Test score distribution
----------------------------------------------------------------*/
title "LGD Test Severity Score Distribution";

proc means data=raw.lgd_scorecard_test
    n mean std min q1 median q3 max;

    var LGD_Predicted LGD_Score;

run;

/*---------------------------------------------------------------
  9. Display scaling parameters
----------------------------------------------------------------*/
title "LGD Scorecard Scaling Parameters";

proc print data=output.lgd_score_scaling noobs;
run;

title;

/*========================================================================
  MODULE 16: LGD SCORE BANDS & PORTFOLIO RISK SEGMENTATION
========================================================================*/

/*---------------------------------------------------------------
  1. Create score bands for TEST population
----------------------------------------------------------------*/
data work.lgd_score_banded;

    set raw.lgd_scorecard_test;

    length Score_Band $30;

    if LGD_Score < 400 then
        Score_Band = "01: <400";

    else if LGD_Score < 500 then
        Score_Band = "02: 400-499";

    else if LGD_Score < 550 then
        Score_Band = "03: 500-549";

    else if LGD_Score < 600 then
        Score_Band = "04: 550-599";

    else
        Score_Band = "05: 600+";

run;

/*---------------------------------------------------------------
  2. Portfolio summary by score band
----------------------------------------------------------------*/
proc sql;

    create table output.lgd_score_band_analysis as

    select

        Score_Band,

        count(*) as Accounts,

        mean(LGD_Score) as Average_Score
            format=8.2,

        mean(LGD_Predicted) as Average_Predicted_LGD
            format=percent8.2,

        mean(LGD_Actual) as Average_Actual_LGD
            format=percent8.2,

        mean(abs(LGD_Actual - LGD_Predicted))
            as Mean_Absolute_Error
            format=percent8.2

    from work.lgd_score_banded

    group by Score_Band

    order by Score_Band;

quit;

/*---------------------------------------------------------------
  3. Display score-band analysis
----------------------------------------------------------------*/
title "LGD Score Band Portfolio Analysis";

proc print data=output.lgd_score_band_analysis
          noobs;

run;

/*---------------------------------------------------------------
  4. Portfolio size distribution
----------------------------------------------------------------*/
title "LGD Score Band Population Distribution";

proc freq data=work.lgd_score_banded;

    tables Score_Band;

run;

title;

/*========================================================================
  MODULE 17: CUMULATIVE LGD GAINS & LIFT ANALYSIS
========================================================================*/

/*---------------------------------------------------------------
  1. Rank TEST population from highest severity to lowest
     Lowest score = highest expected LGD
----------------------------------------------------------------*/
proc sort data=raw.lgd_scorecard_test
          out=work.lgd_gains_sorted;

    by LGD_Score;

run;

/*---------------------------------------------------------------
  2. Calculate total portfolio LGD
----------------------------------------------------------------*/
proc sql noprint;

    select
        sum(LGD_Actual),
        count(*)

    into
        :TOTAL_LGD,
        :TOTAL_POP

    from raw.lgd_scorecard_test;

quit;

/*---------------------------------------------------------------
  3. Create cumulative gains metrics
----------------------------------------------------------------*/
data output.lgd_cumulative_gains;

    set work.lgd_gains_sorted;

    retain
        Cum_Population 0
        Cum_Actual_LGD 0;

    /* Population counter */
    Cum_Population + 1;

    /* Cumulative observed LGD */
    Cum_Actual_LGD + LGD_Actual;

    /* Population percentage */
    Population_Pct =
        Cum_Population / &TOTAL_POP.;

    /* Share of total observed LGD */
    LGD_Gains_Pct =
        Cum_Actual_LGD / &TOTAL_LGD.;

    /* Lift */
    if Population_Pct > 0 then
        LGD_Lift =
            LGD_Gains_Pct / Population_Pct;

    format
        Population_Pct
        LGD_Gains_Pct
        percent8.2
        LGD_Lift
        8.2;

run;

/*---------------------------------------------------------------
  4. Create decile-level gains table
----------------------------------------------------------------*/
proc rank data=output.lgd_cumulative_gains
          out=work.lgd_gains_decile
          groups=10;

    var Cum_Population;

    ranks Temp_Decile;

run;

data work.lgd_gains_decile;

    set work.lgd_gains_decile;

    Risk_Decile = Temp_Decile + 1;

    drop Temp_Decile;

run;

/*---------------------------------------------------------------
  5. Summarize gains at each risk decile
----------------------------------------------------------------*/
proc sql;

    create table output.lgd_gains_decile_summary as

    select
        Risk_Decile,

        max(Cum_Population)
            as Cumulative_Accounts,

        max(Population_Pct)
            as Cumulative_Population_Pct
            format=percent8.2,

        max(LGD_Gains_Pct)
            as Cumulative_LGD_Capture
            format=percent8.2,

        max(LGD_Lift)
            as Cumulative_Lift
            format=8.2

    from work.lgd_gains_decile

    group by Risk_Decile

    order by Risk_Decile;

quit;

/*---------------------------------------------------------------
  6. Display cumulative gains table
----------------------------------------------------------------*/
title "LGD Cumulative Gains & Lift Analysis";

proc print data=output.lgd_gains_decile_summary
          noobs;

run;

/*---------------------------------------------------------------
  7. Key concentration metrics
----------------------------------------------------------------*/
title "LGD Risk Concentration Summary";

proc sql;

    select
        max(
            case
                when Cumulative_Population_Pct <= 0.10
                then Cumulative_LGD_Capture
            end
        )
        as LGD_Capture_First_10pct
        format=percent8.2,

        max(
            case
                when Cumulative_Population_Pct <= 0.20
                then Cumulative_LGD_Capture
            end
        )
        as LGD_Capture_First_20pct
        format=percent8.2,

        max(
            case
                when Cumulative_Population_Pct <= 0.30
                then Cumulative_LGD_Capture
            end
        )
        as LGD_Capture_First_30pct
        format=percent8.2,

        max(Cumulative_Lift)
            as Maximum_LGD_Lift
            format=8.2

    from output.lgd_gains_decile_summary;

quit;

title;

/*========================================================================
  MODULE 18: POPULATION STABILITY INDEX (PSI)
========================================================================*/

/*---------------------------------------------------------------
  1. Create consistent score bands
----------------------------------------------------------------*/
proc format;

    value lgd_score_band
        low - <400 = "01: <400"
        400 - <500 = "02: 400-499"
        500 - <550 = "03: 500-549"
        550 - <600 = "04: 550-599"
        600 - high = "05: 600+";

run;

/*---------------------------------------------------------------
  2. Training score-band distribution
----------------------------------------------------------------*/
proc freq data=raw.lgd_scorecard_train
          noprint;

    tables LGD_Score /
        out=work.lgd_train_score_freq;

    format LGD_Score lgd_score_band.;

run;

/*---------------------------------------------------------------
  3. Test score-band distribution
----------------------------------------------------------------*/
proc freq data=raw.lgd_scorecard_test
          noprint;

    tables LGD_Score /
        out=work.lgd_test_score_freq;

    format LGD_Score lgd_score_band.;

run;

/*---------------------------------------------------------------
  4. Calculate PSI by score band
----------------------------------------------------------------*/
proc sql;

    create table output.lgd_psi_detail as

    select

        coalesce(a.LGD_Score,b.LGD_Score)
            as Score_Band,

        coalesce(a.Percent/100,0.0001)
            as Training_Prop,

        coalesce(b.Percent/100,0.0001)
            as Test_Prop,

        (
            (calculated Training_Prop -
             calculated Test_Prop)
            *
            log(
                calculated Training_Prop /
                calculated Test_Prop
            )
        ) as PSI_Contribution

    from work.lgd_train_score_freq as a

    full join work.lgd_test_score_freq as b

        on a.LGD_Score = b.LGD_Score;

quit;

/*---------------------------------------------------------------
  5. Calculate total PSI
----------------------------------------------------------------*/
proc sql;

    create table output.lgd_psi_summary as

    select

        sum(PSI_Contribution)
            as Total_PSI format=8.4

    from output.lgd_psi_detail;

quit;

/*---------------------------------------------------------------
  6. Display PSI detail
----------------------------------------------------------------*/
title "LGD Score Population Stability Index - Detail";

proc print data=output.lgd_psi_detail
          noobs;

run;

/*---------------------------------------------------------------
  7. Display total PSI
----------------------------------------------------------------*/
title "LGD Population Stability Index Summary";

proc print data=output.lgd_psi_summary
          noobs;

run;

title;

/*========================================================================
  MODULE 18A: CORRECTED LGD SCORE PSI CALCULATION
========================================================================*/

/*---------------------------------------------------------------
  1. Create explicit character score bands for TRAIN
----------------------------------------------------------------*/
data work.lgd_train_psi;

    set raw.lgd_scorecard_train;

    length Score_Band $20;

    if LGD_Score < 400 then
        Score_Band = "01: <400";
    else if LGD_Score < 500 then
        Score_Band = "02: 400-499";
    else if LGD_Score < 550 then
        Score_Band = "03: 500-549";
    else if LGD_Score < 600 then
        Score_Band = "04: 550-599";
    else
        Score_Band = "05: 600+";

run;

/*---------------------------------------------------------------
  2. Create explicit character score bands for TEST
----------------------------------------------------------------*/
data work.lgd_test_psi;

    set raw.lgd_scorecard_test;

    length Score_Band $20;

    if LGD_Score < 400 then
        Score_Band = "01: <400";
    else if LGD_Score < 500 then
        Score_Band = "02: 400-499";
    else if LGD_Score < 550 then
        Score_Band = "03: 500-549";
    else if LGD_Score < 600 then
        Score_Band = "04: 550-599";
    else
        Score_Band = "05: 600+";

run;

/*---------------------------------------------------------------
  3. Training population distribution
----------------------------------------------------------------*/
proc freq data=work.lgd_train_psi
          noprint;

    tables Score_Band /
        out=work.lgd_train_psi_freq;

run;

/*---------------------------------------------------------------
  4. Test population distribution
----------------------------------------------------------------*/
proc freq data=work.lgd_test_psi
          noprint;

    tables Score_Band /
        out=work.lgd_test_psi_freq;

run;

/*---------------------------------------------------------------
  5. Calculate PSI by explicit score band
----------------------------------------------------------------*/
proc sql;

    create table output.lgd_psi_detail_corrected as

    select

        coalesce(
            a.Score_Band,
            b.Score_Band
        ) as Score_Band length=20,

        coalesce(
            a.Percent / 100,
            0.0001
        ) as Training_Prop,

        coalesce(
            b.Percent / 100,
            0.0001
        ) as Test_Prop,

        (
            (
                calculated Training_Prop -
                calculated Test_Prop
            )
            *
            log(
                calculated Training_Prop /
                calculated Test_Prop
            )
        ) as PSI_Contribution

    from work.lgd_train_psi_freq as a

    full join work.lgd_test_psi_freq as b

        on a.Score_Band = b.Score_Band

    order by Score_Band;

quit;

/*---------------------------------------------------------------
  6. Calculate total PSI
----------------------------------------------------------------*/
proc sql;

    create table output.lgd_psi_summary_corrected as

    select

        sum(PSI_Contribution)
            as Total_PSI
            format=8.4

    from output.lgd_psi_detail_corrected;

quit;

/*---------------------------------------------------------------
  7. Display PSI detail
----------------------------------------------------------------*/
title "Corrected LGD Score PSI Detail";

proc print data=output.lgd_psi_detail_corrected
          noobs;

run;

/*---------------------------------------------------------------
  8. Display final PSI
----------------------------------------------------------------*/
title "Corrected LGD Population Stability Index";

proc print data=output.lgd_psi_summary_corrected
          noobs;

run;

title;

/*========================================================================
  MODULE 19: PRODUCTION LGD SCORING PIPELINE
========================================================================*/

/*---------------------------------------------------------------
  1. Create production scoring dataset
----------------------------------------------------------------*/
data output.lgd_production_scored;

    set raw.lgd_scored_test;

    /*-----------------------------------------------------------
      Apply final model coefficients
    -----------------------------------------------------------*/
    LGD_Production_Predicted =
          &LGD_INTERCEPT.
        + (&LGD_BETA_PAY.   * ENC_PAY_0)
        + (&LGD_BETA_AGE.   * ENC_AGE)
        + (&LGD_BETA_LIMIT. * ENC_LIMIT_BAL);

    /* Restrict predicted LGD */
    LGD_Production_Predicted =
        min(0.9999,
        max(0.0001,
        LGD_Production_Predicted));

    /*-----------------------------------------------------------
      Calculate LGD severity score
    -----------------------------------------------------------*/
    LGD_Score_Production =
        round(
            &BASE_SCORE.
            -
            (
                (&PDO. / log(2))
                *
                log(
                    LGD_Production_Predicted /
                    (1 - LGD_Production_Predicted)
                )
            )
        );

    /* Score boundaries */
    if LGD_Score_Production < 300 then
        LGD_Score_Production = 300;

    if LGD_Score_Production > 850 then
        LGD_Score_Production = 850;

    /*-----------------------------------------------------------
      Production score bands
    -----------------------------------------------------------*/
    length LGD_Risk_Band $30;

    if LGD_Score_Production < 400 then
        LGD_Risk_Band = "01: Very High Severity";

    else if LGD_Score_Production < 500 then
        LGD_Risk_Band = "02: High Severity";

    else if LGD_Score_Production < 550 then
        LGD_Risk_Band = "03: Moderate-High Severity";

    else if LGD_Score_Production < 600 then
        LGD_Risk_Band = "04: Moderate Severity";

    else
        LGD_Risk_Band = "05: Lower Severity";

    label
        LGD_Production_Predicted =
            "Production Predicted LGD"

        LGD_Score_Production =
            "Production LGD Severity Score"

        LGD_Risk_Band =
            "LGD Severity Risk Band";

run;

/*---------------------------------------------------------------
  2. Production portfolio summary
----------------------------------------------------------------*/
title "Production LGD Portfolio Summary";

proc means data=output.lgd_production_scored
    n mean std min q1 median q3 max;

    var
        LGD_Production_Predicted
        LGD_Score_Production;

run;

/*---------------------------------------------------------------
  3. Production risk-band distribution
----------------------------------------------------------------*/
title "Production LGD Risk Band Distribution";

proc freq data=output.lgd_production_scored;

    tables LGD_Risk_Band;

run;

/*---------------------------------------------------------------
  4. Display sample production records
----------------------------------------------------------------*/
title "Production LGD Scoring Sample";

proc print data=output.lgd_production_scored
          obs=20
          noobs;

    var
        ID
        PAY_0
        AGE
        LIMIT_BAL
        LGD_Production_Predicted
        LGD_Score_Production
        LGD_Risk_Band;

run;

title;

/*========================================================================
  MODULE 15A: CORRECTED TEST LGD SCORECARD SCORING
========================================================================*/

/*---------------------------------------------------------------
  Rebuild TEST scorecard with safe LGD bounds.

  IMPORTANT:
  Regression predictions can exceed 1.0.
  Therefore, before calculating LGD odds/logit,
  predictions are constrained to (0,1), not [0,1].
----------------------------------------------------------------*/

data raw.lgd_scorecard_test;

    set raw.lgd_scored_test;

    /* Safe probability/severity bounds */
    LGD_Predicted_Safe =
        min(0.9999,
        max(0.0001,
        LGD_Predicted_Raw));

    /* Store corrected predicted LGD */
    LGD_Predicted =
        LGD_Predicted_Safe;

    /* LGD odds */
    LGD_Odds =
        LGD_Predicted /
        (1 - LGD_Predicted);

    /* Logit */
    LGD_Logit =
        log(LGD_Odds);

    /* Score */
    LGD_Score =
        round(
            &BASE_SCORE.
            -
            (
                (&PDO. / log(2))
                *
                LGD_Logit
            )
        );

    /* Score boundaries */
    if LGD_Score < 300 then
        LGD_Score = 300;

    else if LGD_Score > 850 then
        LGD_Score = 850;

run;

/*---------------------------------------------------------------
  Validate corrected TEST scorecard
----------------------------------------------------------------*/
title "Corrected Test LGD Scorecard Validation";

proc means data=raw.lgd_scorecard_test
    n nmiss mean std min q1 median q3 max;

    var
        LGD_Predicted
        LGD_Score;

run;

/*---------------------------------------------------------------
  Check for missing / invalid scores
----------------------------------------------------------------*/
title "Corrected LGD Score Validation Check";

proc sql;

    select
        count(*) as Total_Records,

        sum(
            case
                when missing(LGD_Predicted)
                then 1 else 0
            end
        ) as Missing_Predicted_LGD,

        sum(
            case
                when missing(LGD_Score)
                then 1 else 0
            end
        ) as Missing_Score,

        sum(
            case
                when LGD_Predicted <= 0
                     or LGD_Predicted >= 1
                then 1 else 0
            end
        ) as Invalid_LGD_Bounds

    from raw.lgd_scorecard_test;

quit;

title;