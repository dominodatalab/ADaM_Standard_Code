#/*****************************************************************************\
#         O
#        /
#   O---O     _  _ _  _ _  _  _|
#        \ \/(/_| (_|| | |(/_(_|
#         O
# ______________________________________________________________________________          
# Study: Domino Data Lab
# Analysis:
# Program:
# Purpose: Produce eDISH plot from adlbhy for Domino 
#_______________________________________________________________________________                            
# DESCRIPTION
#                           
# Input files: adlbhy.sas7bdat
#                             
# Output files: 
#                             
# Utility functions:
# 
# Assumptions:
# 
#
#_______________________________________________________________________________
# PROGRAM HISTORY
# 07JUN2022 |	Sarah Robson	| Original
#/*****************************************************************************\

#---------------------------- packages to include ------------------------------
library(tidyverse)
library(haven)

#--------------------------- set working directory -----------------------------
setwd("G:/.shortcut-targets-by-id/1yMsHxw9Fsin07zuRndKkciO4l6VibyAh/Sarah Robson/R Projects/Domino")

#------------------------------- read in data ----------------------------------
adlbhy <- read_sas("adlbhy.sas7bdat")

#-------------------------------------- eDISH plot - adlbhy -------------------------------------------  
# taking the max AVAL by USUBJID for max ALT
#----------- get ALT data
adlbhy_alt <- adlbhy %>%
  filter(ANL01FL == "Y" & PARAMCD == "ALT")  %>%
  group_by(USUBJID) %>%
  mutate(max_aval = max(AVAL),
         max_ALT_ULN = max(R2A1HI)) %>%
  ungroup()

# rename PARAMCD to "ALT"
# rename A1HI to "ALT_HI"
# rename A1LO to "ALT_LO"
names(adlbhy_alt)[names(adlbhy_alt) == "max_aval"] <- "ALT"
names(adlbhy_alt)[names(adlbhy_alt) == "A1HI"] <- "ALT_HI"
names(adlbhy_alt)[names(adlbhy_alt) == "A1LO"] <- "ALT_LO"


#---------- get BILI data
adlbhy_bili_pre <- adlbhy %>%
  filter(ANL01FL == "Y" & PARAMCD == "BILI")  %>%
  group_by(USUBJID) %>%
  mutate(max_aval = max(AVAL),
         max_BILI_ULN = max(R2A1HI)) %>%
  ungroup()

# keep only needed variables
adlbhy_bili <- adlbhy_bili_pre[,c("USUBJID", "AVISITN", "max_aval", "max_BILI_ULN", "A1HI", "A1LO")]

# rename PARAMCD to "BILI"
# rename A1HI to "BILI_HI"
# rename A1LO to "BILI_LO"
names(adlbhy_bili)[names(adlbhy_bili) == "max_aval"] <- "BILI"
names(adlbhy_bili)[names(adlbhy_bili) == "A1HI"] <- "BILI_HI"
names(adlbhy_bili)[names(adlbhy_bili) == "A1LO"] <- "BILI_LO"


#---------- merge all together
edish_data_prep <- merge(adlbhy_alt, adlbhy_bili, by = c("USUBJID", "AVISITN"), all = TRUE)


#---------- make eDISH plot
# find the unique data for each subject
edish_data_unique <- unique(edish_data_prep[,c("USUBJID", "ALT", "max_ALT_ULN", "BILI", "max_BILI_ULN")])
# find the number of patients that fall within each bound
edish_summary <- edish_data_unique %>%
  mutate(status = ifelse(max_ALT_ULN < 1 & max_BILI_ULN < 1, "Normal",
                         ifelse(max_ALT_ULN < 3 & max_BILI_ULN < 2 & max_ALT_ULN >= 1 , "",
                                ifelse(max_ALT_ULN < 3 & max_BILI_ULN < 2 & max_BILI_ULN >= 1, "",
                                       ifelse(max_ALT_ULN >= 3 & max_BILI_ULN >= 2, "Hy's Law",
                                              ifelse(max_ALT_ULN < 3 & max_BILI_ULN >= 2, "Hyperbilirubinemia",
                                                     ifelse(max_ALT_ULN >= 3 & max_BILI_ULN < 2, "Temple's Corollary",
                                                            NA))))))) %>%
  group_by(status) %>%
  summarise(USUBJID, 
            n = n(), 
            x_lab = ifelse(status != "", floor(min(max_ALT_ULN)), 1), # x position for labels
            y_lab = ifelse(status != "", floor(min(max_BILI_ULN)), 0)) %>% # y position for labels
  ungroup()

# get just the unique counts for status
status_count <- unique(edish_summary[,c("status", "n", "x_lab", "y_lab")])

# merge onto edish_data_prep to make edish_data
edish_data <- merge(edish_data_prep, edish_summary, by = "USUBJID", all = TRUE)




#---------- the plot
ggplot(data = edish_data) +
  
  # add labels of number in each status
  geom_text(data = status_count,
            aes(x = x_lab + 0.2,
                y = y_lab + 0.2),
            label = paste(status_count$status, "\n n = ", status_count$n),
            hjust = -0,
            vjust = -0,
            col = "red") +
  
  # scatter points
  geom_point(aes(x = max_ALT_ULN,
                 y = max_BILI_ULN,
                 color = TRTA),
             size = 2.1) +
  
  # set point colours
  scale_color_manual(values = c("grey60", "dodgerblue", "limegreen"),
                     name = "Treatment Arm") +
  
  # line of lower limit (requires two lines)
  geom_segment(aes(x = 1,
                   xend = 1,
                   y = 0,
                   yend = 1),
               linetype = "dashed",
               col = "grey40") +
  geom_segment(aes(x = 0,
                   xend = 1,
                   y = 1,
                   yend = 1),
               linetype = "dashed",
               col = "grey40") +
  
  # line of upper limit 
  geom_hline(aes(yintercept = 2),
             linetype = "dashed",
             col = "grey40") +
  geom_vline(aes(xintercept = 3),
             linetype = "dashed",
             col = "grey40") +
  
  # axis labels 
  labs(x = "Maximum ALT (/ULN)",
       y = "Maximum BILI (/ULN)",
       title = "Maximum Bilirubin VS Maximum Alanine Aminotransferase") +
  
  
  
  # set scales for x an y 
  scale_x_continuous(trans='log2') +
  scale_y_continuous(trans='log2') +
  expand_limits(x=c(0,6), y= c(0)) +
  
  
  # theme
  theme( strip.background = element_blank(),
         # legend.position = "none",
         axis.line = element_line(colour = "black"),
         axis.ticks = element_blank(),
         strip.text = element_text(size = 8,
                                   margin = margin(b = 5)),
         panel.background = element_rect(fill = "white"),
         #panel.grid = element_line(colour = "black"),
         plot.title = element_text(size = 15,
                                   hjust = 0.5,
                                   vjust = 10),
         plot.margin = margin(50, 30, 30, 30),
         plot.title.position = 'plot',
         panel.spacing = unit(0.2, 'in'),
         axis.title.x = element_text(size = 11,
                                     margin = margin(t = 15),
                                     color = "black"),
         plot.subtitle = element_text(size = 11,
                                      margin = margin(b = 15)),
         axis.text.x = element_text(size = 12,
                                    color = "black"),
         axis.text.y = element_text(size = 11,
                                    color = "black",
                                    hjust = 0))

