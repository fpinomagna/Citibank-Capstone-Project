/*
Non-Paris Lending Database: LSE Capstone Project
Authors: Cedric Andrä, Anna Bonnuto, Fernando Pino, Erin Li, and Alia Yusuf
Version: 03/2024
*/

*	This do-file interpolates the financial commitments of outstanding debt stocks 
*	owed to Non-Paris Club creditors from 2000 to 2023 based on the loan-level data

* 	Note: This do file is not for replication to provide transparency and document the process 
* 	behind the interpolation estimation


* The database used to run the interpolation corresponds to "PanelData"

*****************************
* Interest rate interpolation 
*****************************

* A. China data

* Merge with the HRT data - Objective: Contains characterisation of loans to identify their interpolation from Horn, Reinhart and Trebesch (2021)
* The database can be obtained https://data.mendeley.com/datasets/4mm6kdj4xg/1
preserve
clear all
* Raw data
import excel "HRT _ ConsensusDatabase.xlsx", sheet("Data") first row clear

* Renaming with relevant variables of analysis for the final database
rename RecipientCountry BorrowerCountry
gen Borroweriso3 = substr(ProjectID, 1, 3)
rename BorrowerType BorrowerType
rename ProjectDescription BorrowerProject
rename CreditorAgency CreditorAgency
rename CreditorAgencyType CreditorAgencyType
rename Year Year
rename TransactionType Type
rename Commitment AmountCurrency
rename CommitmentUSD AmountMUSD
replace AmountMUSD=AmountMUSD/1000000
rename Currency Currency
rename InterestRate Interest_rate
rename Maturity Maturity
rename GracePeriod Grace 
gen source="ChLO_via_"+Source
gen source_2="ChLO"

keep Borroweriso3 Year AmountMUSD LoanType
rename Year year
save "HRT_loantype.dta", replace // Converting the database to merge with "PanelData"
restore

* Merging
merge m:m Borroweriso3 year AmountMUSD using "HRT_loantype.dta"
drop if _merge==2
drop _merge

* Filling the gaps in other Commercial, Concessional, and Zero-Interest loans
gen dummy_concessional=0
* Assign 1 to the dummy variable if the condition is met
replace dummy_concessional = 1 if strpos(BorrowerProject, "concessional") > 0 
replace dummy_concessional = 1 if strpos(BorrowerProject, "Concessional") > 0 
gen dummy_zero=0
* Assign 1 to the dummy variable if the condition is met
replace dummy_zero = 1 if strpos(BorrowerProject, "Zero") > 0 
replace dummy_zero = 1 if strpos(BorrowerProject, "interest-free") > 0 
gen dummy_commercial=0
* Assign 1 to the dummy variable if the condition is met
replace dummy_commercial = 1 if strpos(BorrowerProject, "credit line") > 0 
replace dummy_commercial = 1 if strpos(BorrowerProject, "credit loan") > 0 
replace dummy_commercial = 1 if strpos(BorrowerProject, "CDB") > 0 

* Creating a dummy of LoanType
replace LoanType="Commercial" if LoanType=="" & dummy_commercial==1
replace LoanType="Concessional" if LoanType=="" & dummy_concessional==1
replace LoanType="Zero-Interest Loan" if LoanType=="" & dummy_zero==1

* Replacing characteristics in the CODF database (no financial information)
replace LoanType="Commercial" if LoanType=="" & source=="CODF" & (CreditorAgency=="China Development Bank" | CreditorAgency=="China Development Bank (CDB)" | CreditorAgency=="CDB") // Check this again when the team check the variable consistency
replace LoanType="Concessional" if LoanType=="" & source=="CODF" &   & (CreditorAgency!="China Development Bank" | CreditorAgency!="China Development Bank (CDB)" | CreditorAgency!="CDB") // Check this again when the team check the variable consistency

* B. India data 

* Characterization depends on  IMF's country classification
* Assumption: Calculations do not include the grant component of the loan

gen IND_country_class=.
replace IND_country_class=1 if inlist(BorrowerCountry,"Cote d'Ivoire","Kenya","Mozambique","Rwanda","Senegal") & Creditoriso3=="IND" & type=="Loan"
 // Check this with the final database
replace IND_country_class=2 if inlist(BorrowerCountry,"Cameroon","Mongolia","Sri Lanka","Uzbekistan","Zambia") & Creditoriso3=="IND" & type=="Loan"
replace IND_country_class=3 if inlist(BorrowerCountry,"Suriname") & Creditoriso3=="IND" & type=="Loan"

* C. Intrapolate Loan Terms 
rename year Year
merge m:1 Year using "Libor.dta" // Also provided by HRT but extended until 2023
drop if _merge==2
drop _merge
rename Year year 

* Interpolation flag
gen interpolation_int=0
gen interpolation_grace=0
gen interpolation_maturity=0
replace interpolation_maturity=1 if maturity == .  & inlist(LoanType,"Commercial","Concessional","Zero-Interest Loan","") & Creditoriso3=="CHN" & type=="Loan"
replace interpolation_grace   = 1 if grace == . 	  & inlist(LoanType,"Commercial","Concessional","Zero-Interest Loan","") & Creditoriso3=="CHN"  & type=="Loan"
replace interpolation_int = 1	if interest == .  & inlist(LoanType,"Commercial","Concessional","Zero-Interest Loan","") & Creditoriso3=="CHN"  & type=="Loan"
replace interpolation_maturity=1 if maturity == .  &  Creditoriso3=="IND" & type=="Loan"
replace interpolation_grace   = 1 if grace == . 	  &  Creditoriso3=="IND"  & type=="Loan"
replace interpolation_int = 1	if interest == .  &  Creditoriso3=="IND"  & type=="Loan"

* C.1. China

*Commercial Banks, CDB and supplier credits
replace maturity = 13 			if maturity == .  & LoanType  == "Commercial" & Creditoriso3=="CHN" & type=="Loan"
replace grace   = 4 			if grace == . 	  & LoanType  == "Commercial" & Creditoriso3=="CHN"  & type=="Loan"
replace interest = LIBOR + 2	if interest == .  & LoanType  == "Commercial" & Creditoriso3=="CHN"  & type=="Loan"

*Zero-Interest Loans
replace maturity = 20 if LoanType == "Zero-Interest Loan" & maturity == . & Creditoriso3=="CHN"  & type=="Loan"
replace grace    = 10 if LoanType == "Zero-Interest Loan" & grace   == .  & Creditoriso3=="CHN"  & type=="Loan"
replace interest    = 0 if LoanType == "Zero-Interest Loan" & interest   == .  & Creditoriso3=="CHN"  & type=="Loan"

*Concessional Loans
replace maturity = 20 			if maturity == .  & LoanType == "Concessional" & Creditoriso3=="CHN"  & type=="Loan"
replace grace   = 5 			if grace == . 	  & LoanType == "Concessional" & Creditoriso3=="CHN"  & type=="Loan"
replace interest = 2 			if interest == .  & LoanType == "Concessional" & Creditoriso3=="CHN"  & type=="Loan"
 
*Assume concessional lending terms for unknown Loan Types (just for China loans)
replace maturity  = 20  if LoanType == "" & maturity == . & Creditoriso3=="CHN"  & type=="Loan"
replace grace    = 5   if LoanType == "" & grace   == .  & Creditoriso3=="CHN"   & type=="Loan"
replace interest  = 2   if LoanType == "" & interest == . & Creditoriso3=="CHN"  & type=="Loan"

* C.2. India (just concessional loans)
replace maturity  = 25  if  maturity == . & Creditoriso3=="IND"  & type=="Loan" & IND_country_class==1
replace grace    = 5   if grace   == .  & Creditoriso3=="IND"   & type=="Loan" & IND_country_class==1
replace interest  = 1.5   if   interest == . & Creditoriso3=="IND"  & type=="Loan" & IND_country_class==1

replace maturity  = 20  if  maturity == . & Creditoriso3=="IND"  & type=="Loan" & IND_country_class==2
replace grace    = 5   if  grace   == .  & Creditoriso3=="IND"   & type=="Loan" & IND_country_class==2
replace interest  = 1.75   if interest == . & Creditoriso3=="IND"  & type=="Loan" & IND_country_class==2

replace maturity  = 15  if  maturity == . & Creditoriso3=="IND"  & type=="Loan" & IND_country_class==3
replace grace    = 5   if  grace   == .  & Creditoriso3=="IND"   & type=="Loan" & IND_country_class==3
replace interest  = 1.5+LIBOR   if interest == . & Creditoriso3=="IND"  & type=="Loan" & IND_country_class==3

* Saving database with interpolation (Excel version)

* Specify the desired variable order
preserve
sort BorrowerCountry year
keep if year>=2000
keep BorrowerCountry BorrowerAgency Borroweriso3 BorrowerAgencyType BorrowerProject CreditorCountry Creditoriso3 CreditorAgency CreditorType CreditorAgencyType year type AmountCurrency AmountMUSD currency interest maturity grace source interpolation_int interpolation_grace interpolation_maturity
local desired_order BorrowerCountry BorrowerAgency Borroweriso3 BorrowerAgencyType BorrowerProject CreditorCountry Creditoriso3 CreditorAgency CreditorType CreditorAgencyType year type AmountCurrency AmountMUSD currency interest maturity grace source interpolation_int interpolation_grace interpolation_maturity

* Order the variables
order `desired_order'

* Save the dataset as an Excel file
export excel using "non_paris_lending_database_review_VF.xlsx", firstrow(variables) sheet("PanelData", replace)
restore
