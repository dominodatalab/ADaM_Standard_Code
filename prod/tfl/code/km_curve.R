#/*****************************************************************************\
#         O
#        /
#   O---O     _  _ _  _ _  _  _|
#        \ \/(/_| (_|| | |(/_(_|
#         O
# ______________________________________________________________________________          
# Sponsor              : Domino
# Compound             : Xanomeline
# Study                : H2QMCLZZT
# Analysis             : PILOT01
# Program              : eDISH.R
# Purpose              : Produce visualisations of the data from ADTTE
#_______________________________________________________________________________                            
# DESCRIPTION
#                           
# Input files: adtte.sas7bdat
#                             
# Output files: vet_kmcurve_R.pdf
#                             
# Utility functions:
# 
# Assumptions:
# 
#
#_______________________________________________________________________________
# PROGRAM HISTORY
# 01JUN2022 |	Sarah Robson	| Original
#/*****************************************************************************\

#---------------------------- packages to include ------------------------------
library(tidyverse)
library(survminer)
library(survival)
library(haven)

#--------------------------- set working directory -----------------------------
setwd("/mnt/imported/data/ADAM")

#------------------------------- read in data ----------------------------------
adtte <- read_sas("adtte.sas7bdat")

#-------------------------- begin manipulating data ----------------------------
# Recode CNSR as R survfunction expects 0 for censored and 1 for event
adtte$CNSR2 = NA
adtte$CNSR2[adtte$CNSR==0] <-1
adtte$CNSR2[adtte$CNSR==1] <-0

#-------------------------- create survival objects ----------------------------
# Create Survival object using the Survfunction 
surv_trtp <- Surv(time = adtte$AVAL, event=adtte$CNSR2) # KM is the default

# Computes the estimates of the survival curves
# TRTA used as open label
surv_curve <- survfit(surv_trtp~ TRTA,  data = adtte, conf.type= c("log-log")) # Transformation log is default

#---------------------------- kaplan meier curve -------------------------------
# Create KM plot and output as a PNG
setwd("/mnt/artifacts/results")
pdf(file = "vet_kmcurve_R.pdf", height = 15, width = 15, onefile = FALSE) # need onefile = FALSE so that it prints on first page
ggsurvplot(surv_curve,          
           title = "KM Curve of Dermatological Events by Assigned Treatment",       
           risk.table= TRUE,                          # Display Number at Risk table  
           pval= TRUE,                                # Display Log rank test P-value 
           pval.coord= c(0,0.1),                    # Coordinates where to display the P-value  
           break.time.by = 33,                          # Specifies time intervals       
           xlim= c(0,198),                             # Width of x-axis       
           xlab= "Survival time (Days)",             # x-axis label  
           ylab= "No event probability",             # y-axis label 
           legend=c("top"),                            # Position of legend     
           legend.title="Assigned Treatment",           # Legend title      
           legend.labs= substr(names(surv_curve$strata), 6, nchar(names(surv_curve$strata))), # Strata labels in legend, removing "TRTA="     
           ggtheme= theme_minimal() +
             theme(plot.title= element_text(hjust= 0.5, face = "bold")),  # Customize the theme of KM curve and risk table      
           risk.table.y.text.col= TRUE,               # Display y-axis title of risk table   
           risk.table.y.text= TRUE,                   # Display Strata labels on number at risk table    
           risk.table.height=.30)

# Height of risk table
dev.off() # Closes the plot and saves it as file