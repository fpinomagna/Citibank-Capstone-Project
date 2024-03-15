/*
Non-Paris Lending Database: LSE Capstone Project
Authors: Cedric Andrä, Anna Bonnuto, Fernando Pino, Erin Li, and Alia Yusuf
Version: 03/2024
*/

*	This do-file applies the methodology to convert flows to debt and estimate,
*   and forecast the debt service from 2000 to 2023 based on the loan-level data

* 	Note: This do file is not for replication to provide transparency and document the process 
* 	behind the estimation

* The database used to run the methodology corresponds to "PanelData"

***************************************
*Map Flows into Stocks (HTV) + Forecast
***************************************
keep if year>=2000
keep if inlist(type,"Loan","Swap Use") // We work with loans and swaps because they have financial information
sort BorrowerCountry year

*Gen End of Grace Period and Maturity Years
gen EndofGracePeriod = year + round(grace, 1)
gen YearofMaturity   = year + round(maturity, 1)
gen AnnualRepayment  = AmountMUSD /(round(maturity, 1) - round(grace, 1))

*Debt without sluggish disbursement schedule (conservative)
forvalues num = 2000(1)2035 {
	gen Db`num' = cond(`num' < year, 0, ///
	cond(`num' <= EndofGracePeriod, AmountMUSD, ///
	cond(`num' <= YearofMaturity,  AmountMUSD - (`num' - EndofGracePeriod)*AnnualRepayment, 0)))
	replace  Db`num' =0 if  Db`num'<0
}
*

*Debt with sluggish disbursement schedule (with sluggish disbursement)
forvalues num = 2000(1)2035 {
	gen Db_dis`num' = 0
	quietly replace Db_dis`num' = (AmountMUSD/round(grace, 1))*(`num' - year + 1) if `num' >= year & `num' < EndofGracePeriod
	quietly replace Db_dis`num' = AmountMUSD if `num' == EndofGracePeriod
	quietly replace Db_dis`num' = Db`num' if `num' > EndofGracePeriod
	replace  Db_dis`num' =0 if  Db_dis`num'<0
}
*

*Generate Repayment & Debt Service Variables (Principal and Interest)
gen Rb2000 = 0

forvalues num = 2001/2035 {
	gen Rb`num' = cond(Db`--num' - Db`++num' > 0, AnnualRepayment, 0) + (cond(missing(interest),0,interest)/100)*Db`--num'
}
*

* Saving database (Excel version)

* Specify the desired variable order
preserve
sort BorrowerCountry year
keep if year>=2000
keep BorrowerCountry BorrowerAgency Borroweriso3 BorrowerAgencyType BorrowerProject CreditorCountry Creditoriso3 CreditorAgency CreditorType CreditorAgencyType year type AmountCurrency AmountMUSD currency interest maturity grace source interpolation_int interpolation_grace interpolation_maturity EndofGracePeriod YearofMaturity AnnualRepayment Db* Db_dis* Rb*
local desired_order BorrowerCountry BorrowerAgency Borroweriso3 BorrowerAgencyType BorrowerProject CreditorCountry Creditoriso3 CreditorAgency CreditorType CreditorAgencyType year type AmountCurrency AmountMUSD currency interest maturity grace source interpolation_int interpolation_grace interpolation_maturity EndofGracePeriod YearofMaturity AnnualRepayment Db* Db_dis* Rb*

* Order the variables
order `desired_order'

* Save the dataset as an Excel file
export excel using "non_paris_lending_database_review_VF.xlsx", firstrow(variables) sheet("PanelData_Stock_Estimation", replace)
restore
