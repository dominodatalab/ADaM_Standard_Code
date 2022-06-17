# Domino Data Lab ADaM and TFL repository

This repo contains ADaM and TFL code for the Domino clinical trial demo.

# Directory structure

The programming is created in a typical clinical trial folder structure, where the production (prod) and qc programs have independent directory trees.

Standard library code (e.g. Company SAS macro library) is in the `share/macros` folder.

```
repo
├───config
│   └───macros
├───prod
│   ├───adam
│   │   └───code
│   └───tfl
│       └───code
├───qc
│   ├───adam
│   │   └───code
│   └───tfl
│       └───code
├───sasconfig
│   ├───preferences
│   └───state
└───share
    └───macros
```

# Naming convention

The programs follow a typical clinical trial naming convention, where the ADaM programs are named using the dataset name (e.g. ADSL.sas, etc.) and the TFL programs have a `t_` prefix to indicate tables, etc.

# Mult-Language Programming (SAS and R)

The production programming is a mixture of SAS and R programs. The productiobn ADSL dataset is created in R, and others are created in SAS. The R dataset is created in XPT format, and `config/xpt_to_sas.sas` putility converts to sas7bdat format.

# QC programming and reporting

The QC programming is all in SAS, and there is a `compare.sas` program which uses SAS PROC COMPARE to create a summary report of all differences between the prod and qc datasets. This program also generates the `dominostats.json` files which Domino uses to display a dashboard in the jobs screen.

# Support

Programming was created by Veramed Ltd. on behalf of Domino Data Lab, Inc.

