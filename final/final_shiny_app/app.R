library(shiny)
library(bslib)
library(ggplot2)
library(gtsummary)
library(gt)
library(DBI)
library(bigrquery)
library(tidyverse)
library(dbplyr)
library(stringr)

cohort <- readRDS("final_cohort_flagged.rds") %>%
  select(-stay_seq) %>%
  mutate(stay_id = row_number())

xgb <- readRDS("xgb.rds")  # update path
model <- xgb$model
threshold <- xgb$threshold

ui <- navbarPage(
  title = "Exploring the Mimic Dataset",
  theme = bs_theme(version = 5),
  
  tabPanel("Cohort Exploration",
           sidebarLayout(
             sidebarPanel(
               # which graph should be shown
               selectInput(
                 inputId = "var",
                 label = "Lab/Vital/Demographic Summary:",
                 choices = c("insurance","marital_status", "race", 
                             "gender", "charlson_score", "admission_type",
                             "arrival_transport", "dbp", "heartrate", "o2sat",
                             "resprate", "sbp", "temperature", "temperature_measured",
                             "sbp_measured", "dbp_measured", "heartrate_measured", 
                             "resprate_measured", "o2sat_measured", "lactate_measured",
                             "hemoglobin_measured", "platelets_measured", "wbc_measured",
                             "creatinine_measured", "sodium_measured", "glucose_measured",
                             "potassium_measured", "bicarbonate_measured", "bun_measured",
                             "ph_measured", "pco2_measured", "po2_measured", "base_excess_measured", 
                             "shock_index", "shock_index_measured", "map", "map_measured", "age_intime",
                             "interdepartmental"),
                 selected = "insurance"
               )
             ),
             
             # Main panel for displaying outputs
             mainPanel(
               card(
                 plotOutput(outputId = "barplot")
               ),
               
               card(
                 gt_output(outputId = "my_gt_table")
               )
             )
           )
  ),
  
  tabPanel("Patient Trajectory",
         sidebarLayout(
           sidebarPanel(
             numericInput("stay_id",
                          "Enter Stay ID (1 to 125,571):",
                          value = 1,
                          min = 1,
                          max = nrow(cohort),
                          step = 1),
             hr(),
             helpText("Each row in the cohort represents one ED stay.
              Stay IDs are assigned by row number.")
           ),
           mainPanel(
             uiOutput("stay_header"),
             
             card(
               plotOutput("vitals_plot", height = "300px")
             ),
             
             card(
               plotOutput("labs_plot", height = "350px")
             )
           )
         )
  ),
  
  tabPanel("ICU Transfer Prediction",
           sidebarLayout(
             sidebarPanel(
               h5("Demographics"),
               selectInput("ml_gender", "Gender", choices = c("M", "F")),
               numericInput("ml_age", "Age", value = 50, min = 0, max = 91),
               selectInput("ml_race", "Race",
                           choices = c("WHITE", "BLACK", "HISPANIC",
                                       "ASIAN", "Other")),
               selectInput("ml_insurance", "Insurance",
                           choices = c("Private", "Medicare", "Medicaid", 
                                       "Other", "No Charge")),
               selectInput("ml_marital", "Marital Status",
                           choices = c("SINGLE", "MARRIED", "DIVORCED", "WIDOWED")),
               hr(),
               h5("Admission Info"),
               selectInput("ml_admission_type", "Admission Type",
                           choices = c("EW EMER.", "EU OBSERVATION", "DIRECT EMER.",
                                       "DIRECT OBSERVATION", "AMBULATORY OBSERVATION",
                                       "ELECTIVE", "OBSERVATION ADMIT", "URGENT",
                                       "SURGICAL SAME DAY ADMISSION")),
               selectInput("ml_arrival", "Arrival Transport",
                           choices = c("AMBULANCE", "WALK IN", "HELICOPTER", 
                                       "OTHER", "UNKNOWN")),
               numericInput("ml_charlson", "Charlson Score", value = 0, min = 0),
               selectInput("ml_interdepartmental", "Interdepartmental Transfer",
                           choices = c("No" = 0, "Yes" = 1)),
               hr(),
               h5("Vital Signs (leave blank if not measured)"),
               numericInput("ml_heartrate", "Heart Rate (bpm)", value = NA),
               numericInput("ml_sbp", "SBP (mmHg)", value = NA),
               numericInput("ml_dbp", "DBP (mmHg)", value = NA),
               numericInput("ml_resprate", "Resp Rate (/min)", value = NA),
               numericInput("ml_o2sat", "O2 Sat (%)", value = NA),
               numericInput("ml_temperature", "Temperature (°F)", value = NA),
               numericInput("ml_map", "MAP (mmHg)", value = NA),
               numericInput("ml_shock_index", "Shock Index", value = NA),
               hr(),
               h5("Labs Collected?"),
               checkboxInput("ml_lactate", "Lactate", FALSE),
               checkboxInput("ml_hemoglobin", "Hemoglobin", FALSE),
               checkboxInput("ml_platelets", "Platelets", FALSE),
               checkboxInput("ml_wbc", "WBC", FALSE),
               checkboxInput("ml_creatinine", "Creatinine", FALSE),
               checkboxInput("ml_sodium", "Sodium", FALSE),
               checkboxInput("ml_potassium", "Potassium", FALSE),
               checkboxInput("ml_bicarbonate", "Bicarbonate", FALSE),
               checkboxInput("ml_glucose", "Glucose", FALSE),
               checkboxInput("ml_bun", "BUN", FALSE),
               checkboxInput("ml_ph", "pH", FALSE),
               checkboxInput("ml_pco2", "PCO2", FALSE),
               checkboxInput("ml_po2", "PO2", FALSE),
               checkboxInput("ml_base_excess", "Base Excess", FALSE),
               hr(),
               actionButton("predict_btn", "Predict", class = "btn-primary")
             ),
             mainPanel(
               h4("Prediction Result"),
               uiOutput("prediction_output")
             )
           )
  )
)

categorical = c("insurance", "admission_type",
                "arrival_transport", "marital_status", 
                "race", "gender", "temperature_measured",
                "sbp_measured", "dbp_measured", "heartrate_measured", 
                "resprate_measured", "o2sat_measured", "lactate_measured",
                "hemoglobin_measured", "platelets_measured", "wbc_measured",
                "creatinine_measured", "sodium_measured", "glucose_measured",
                "potassium_measured", "bicarbonate_measured", "bun_measured",
                "ph_measured", "pco2_measured", "po2_measured", 
                "base_excess_measured", "shock_index_measured", "map_measured",
                "interdepartmental")

continuous = c("charlson_score", "dbp", "heartrate", "o2sat",
               "resprate", "sbp", "temperature", "shock_index",
               "map", "age_intime")

server <- function(input, output, session) {
  
  output$barplot <- renderPlot({
    
    if (input$var %in% categorical) {
      ggplot(data = cohort, 
             aes(x = .data[[input$var]], fill = icu_within_3hrs)) +
        geom_bar(position = "dodge") +
        scale_fill_manual(values = c("Yes" = "#2196F3", "No" = "#E0E0E0")) +
        theme_minimal() +
        labs(title = paste("Distribution of", input$var), 
             y = "Count", fill = "CCU within 3hrs") +
        theme(axis.text.x = element_text(angle = 45, hjust = 1))
    } 
    else {
      ggplot(data = cohort,
             aes(x = icu_within_3hrs, y = .data[[input$var]],
                 fill = icu_within_3hrs)) +
        geom_boxplot() +
        scale_fill_manual(values = c("Yes" = "#2196F3", "No" = "#E0E0E0")) +
        theme_minimal() +
        labs(title = paste("Distribution of", input$var),
             x = "CCU within 3hrs",
             y = input$var, fill = "CCU Within 3hrs") +
        theme(axis.text.x = element_text(angle = 45, hjust = 1))
      
    }
    
  })
  
  output$my_gt_table <- 
    render_gt({
      cohort %>%
        tbl_summary(
          by = icu_within_3hrs,
          include = all_of(input$var)
        ) %>%
        add_n() %>%
        as_gt() %>%
        tab_header(md("**Table 1. Patient Characteristics**"))
      
    })
  
  
  output$stay_header <- renderUI({
    req(input$stay_id)
    
    d <- cohort |> filter(stay_id == as.integer(input$stay_id))
    req(nrow(d) == 1)
      
    
    outcome <- if (d$icu_within_3hrs == "Yes")
      tags$span("Transferred to CCU within 3 hrs",
                style = "color:red; font-weight:bold;")
    else
      tags$span("✓ Not transferred to CCU within 3 hrs",
                style = "color:darkgreen; font-weight:bold;")
    
    tagList(
      tags$h4(paste0(
        "Stay #", input$stay_id, " | ",
        d$gender, ", Age ", d$age_intime, " | ",
        d$race, " | ",
        replace_na(d$insurance, "Unknown insurance")
      )),
      tags$p(paste0(
        "Admission: ", d$admission_type,
        " | Arrival: ", replace_na(d$arrival_transport, "Unknown"),
        " | Charlson Score: ", d$charlson_score,
        " | Interdepartmental: ", ifelse(d$interdepartmental == 1, "Yes", "No")
      )),
      outcome
    )
  })

  
  output$vitals_plot <- renderPlot({
    req(input$stay_id)
    
    d <- cohort |> filter(stay_id == as.integer(input$stay_id))
    req(nrow(d) == 1)
    
    vitals <- d %>%
      select(heartrate, sbp, dbp, resprate, o2sat,
             temperature, shock_index, map) %>%
      pivot_longer(everything(),
                   names_to = "vital",
                   values_to = "value") %>%
      filter(!is.na(value))
    
   if (nrow(vitals) > 0) {
      ggplot(vitals, aes(x = value, y = reorder(vital, value))) +
        geom_col(fill = "#FF7043", width = 0.6) +
        geom_text(aes(label = round(value, 1)), hjust = -0.2, size = 3.5) +
        xlim(0, max(vitals$value) * 1.2) +
        labs(title = "Vital Signs", x = "Value", y = NULL) +
        theme_minimal()
    } else {
      ggplot() +
        annotate("text", x = 0.5, y = 0.5, label = "No vitals recorded", size = 5, color = "grey50") +
        theme_void() + labs(title = "Vital Signs")
    }
  
  })
  
  output$labs_plot <- renderPlot({
    req(input$stay_id)
    
    d <- cohort |> filter(stay_id == as.integer(input$stay_id))
    req(nrow(d) == 1)
    
    labs <- d %>%
      select(ends_with("_measured")) %>%
      pivot_longer(everything(), names_to = "name", 
                   values_to = "value") %>%
      mutate(
        label = str_remove(name, "_measured") %>%
          str_replace_all("_", " ") %>%
          str_to_title(),
        type = "Lab"
      )
  
    
    ggplot(labs, aes(x = 1, y = label,
                           fill = factor(value, levels = c(1,0),
                                         labels = c("Collected", "Not Collected")))) +
      geom_tile(color = "white", linewidth = 0.5) +
      scale_fill_manual(values = c("Collected" = "#2196F3", "Not Collected" = "#E0E0E0")) +
      labs(title = "Lab Collection", x = NULL, y = NULL, fill = NULL) +
      theme_minimal() +
      theme(axis.text.x = element_blank(), axis.ticks.x = element_blank(),
            legend.position = "bottom")
    
  })
  
  
  observeEvent(input$predict_btn, {
    
    new_data <- tibble(
      gender              = input$ml_gender,
      age_intime          = input$ml_age,
      race                = input$ml_race,
      insurance           = input$ml_insurance,
      marital_status      = input$ml_marital,
      admission_type      = input$ml_admission_type,
      arrival_transport   = input$ml_arrival,
      charlson_score      = input$ml_charlson,
      interdepartmental   = as.integer(input$ml_interdepartmental),
      heartrate           = input$ml_heartrate,
      sbp                 = input$ml_sbp,
      dbp                 = input$ml_dbp,
      resprate            = input$ml_resprate,
      o2sat               = input$ml_o2sat,
      temperature         = input$ml_temperature,
      map                 = input$ml_map,
      shock_index         = input$ml_shock_index,
      # measured flags — vitals
      temperature_measured  = as.integer(!is.na(input$ml_temperature)),
      heartrate_measured    = as.integer(!is.na(input$ml_heartrate)),
      sbp_measured          = as.integer(!is.na(input$ml_sbp)),
      dbp_measured          = as.integer(!is.na(input$ml_dbp)),
      resprate_measured     = as.integer(!is.na(input$ml_resprate)),
      o2sat_measured        = as.integer(!is.na(input$ml_o2sat)),
      shock_index_measured  = as.integer(!is.na(input$ml_shock_index)),
      map_measured          = as.integer(!is.na(input$ml_map)),
      # measured flags — labs
      lactate_measured      = as.integer(input$ml_lactate),
      hemoglobin_measured   = as.integer(input$ml_hemoglobin),
      platelets_measured    = as.integer(input$ml_platelets),
      wbc_measured          = as.integer(input$ml_wbc),
      creatinine_measured   = as.integer(input$ml_creatinine),
      sodium_measured       = as.integer(input$ml_sodium),
      potassium_measured    = as.integer(input$ml_potassium),
      bicarbonate_measured  = as.integer(input$ml_bicarbonate),
      glucose_measured      = as.integer(input$ml_glucose),
      bun_measured          = as.integer(input$ml_bun),
      ph_measured           = as.integer(input$ml_ph),
      pco2_measured         = as.integer(input$ml_pco2),
      po2_measured          = as.integer(input$ml_po2),
      base_excess_measured  = as.integer(input$ml_base_excess)
    )
    
    prob <- predict(model, new_data, type = "prob")$.pred_Yes
    
    output$prediction_output <- renderUI({
      color <- if (prob >= threshold) "red" else "darkgreen"
      verdict <- if (prob >= threshold) "HIGH risk of CCU transfer" else "LOW risk of CCU transfer"
      
      tagList(
        tags$h2(sprintf("%.1f%%", prob * 100),
                style = paste0("color:", color, "; font-size: 64px; font-weight: bold;")),
        tags$h4(verdict, style = paste0("color:", color)),
        tags$p("Probability that this patient will be transferred to a critical care unit within 3 hours of ED arrival.")
      )
    })
    
  })
  
  
}

shinyApp(ui = ui, server = server)
