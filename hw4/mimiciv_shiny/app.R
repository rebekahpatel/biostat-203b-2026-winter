library(shiny)
library(bslib)
library(ggplot2)
library(gtsummary)
library(gt)
library(DBI)
library(bigrquery)
library(dplyr)
library(dbplyr)
library(stringr)

mimic_icu_cohort <- readRDS("mimic_icu_cohort.rds")

# path to the service account token 
satoken <- "biostat-203b-2026-winter-92fefbfab477.json"
# BigQuery authentication using service account
bq_auth(path = "~/BIOSTAT203B/203b-hw/hw4/biostat-203b-2026-winter-92fefbfab477.json")

con_bq <- dbConnect(
  bigrquery::bigquery(),
  project = "biostat-203b-2025-winter",
  dataset = "mimiciv_3_1",
  billing = "biostat-203b-2025-winter"
)


ui <- navbarPage(
  title = "Exploring the Mimic Dataset",
  theme = bs_theme(version = 5),
  
  tabPanel("Variable Exploration",
    sidebarLayout(
      sidebarPanel(
            # which graph should be shown
        selectInput(
          inputId = "var",
          label = "Lab/Vital/Demographic Summary:",
          choices = c("hematocrit", "creatinine", "chloride", 
                      "sodium", "glucose", "bicarbonate", 
                      "wbc", "potassium", "heart_rate", 
                      "temperature_fahrenheit",
                      "non_invasive_blood_pressure_diastolic",
                      "respiratory_rate",
                      "non_invasive_blood_pressure_systolic",
                      "los", "insurance", "language",
                      "marital_status", "race", "gender"),
          selected = "hematocrit"
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
  
  tabPanel("Patient Exploration",
    sidebarLayout(
      sidebarPanel(
        selectizeInput(
          inputId = "patient",
          label = "Patient Id",
          choices = NULL,
          multiple = FALSE
        )
      ),
      mainPanel(
        card(
          plotOutput(outputId = "patient_plot")
        )
      )
    )
  )
)

categorical = c("insurance", "language",
         "marital_status", "race", "gender")

continuous = c("hematocrit", "creatinine", "chloride", 
               "sodium", "glucose", "bicarbonate", 
               "wbc", "potassium", "los", "heart_rate", 
               "temperature_fahrenheit",
               "non_invasive_blood_pressure_diastolic",
               "respiratory_rate",
               "non_invasive_blood_pressure_systolic")

server <- function(input, output, session) {
  
  output$barplot <- renderPlot({
    
    if (input$var %in% categorical) {
      ggplot(data = mimic_icu_cohort, 
             aes(x = .data[[input$var]])) +
        geom_bar(fill = "steelblue") +
        theme_minimal() +
        labs(title = paste("Distribution of", input$var), 
             y = "Count") +
        theme(axis.text.x = element_text(angle = 45, hjust = 1))
    } 
    else {
      ggplot(data = mimic_icu_cohort,
             aes(x = .data[[input$var]])) +
      geom_boxplot(fill = "orange") +
      theme_minimal() +
      labs(title = paste("Distribution of", input$var),
           y = "Count") +
      theme(axis.text.x = element_text(angle = 45, hjust = 1))
        
    }
    
  })
  
  output$my_gt_table <- 
    render_gt({
      mimic_icu_cohort %>%
        tbl_summary(
          include = input$var
          ) %>%
        add_n() %>%
        as_gt() %>%
        tab_header(md("**Table 1. Patient Characteristics**"))
      
    })
  
  updateSelectizeInput(session, 
                       "patient", 
                       choices = unique(mimic_icu_cohort$subject_id), 
                       server = TRUE) 
  
  output$patient_plot <- renderPlot({
    req(input$patient)
    
    admission_data <- tbl(con_bq, "admissions") |> 
      filter(subject_id == !!as.numeric(input$patient)) |> 
      select(subject_id, race) |>
      collect()
    
    patient_data <- tbl(con_bq, "patients") |> 
      filter(subject_id == !!as.numeric(input$patient)) |> 
      select(subject_id, gender, anchor_age) |>
      collect()
    
    title <- paste0("Patient ", input$patient, ", ", 
                    patient_data$gender, ", ", 
                    patient_data$anchor_age, " years old, ", 
                    str_to_title(admission_data$race[1]))
    
    diagnoses_icd <- tbl(con_bq, "diagnoses_icd") |> 
      filter(subject_id == !!as.numeric(input$patient)) |> 
      distinct(icd_code, .keep_all = TRUE) |>
      slice_min(order_by = seq_num, n = 3) |> 
      left_join(tbl(con_bq, "d_icd_diagnoses"), 
                by = c("icd_code", "icd_version")) |> 
      collect()
    
    str_top3 <- paste(diagnoses_icd$long_title[1], 
                      diagnoses_icd$long_title[2], 
                      diagnoses_icd$long_title[3], sep = "\n")
    
    transfer_data <- tbl(con_bq, "transfers") |> 
      filter(subject_id == !!as.numeric(input$patient)) |> 
      collect()
    
    procedures_icd <- tbl(con_bq, "procedures_icd") |> 
      filter(subject_id == !!as.numeric(input$patient)) |> 
      left_join(
        tbl(con_bq, "d_icd_procedures"),
        by = c("icd_code", "icd_version")) |> 
      collect()
    
    labevents <- tbl(con_bq, "labevents") |> 
      filter(subject_id == !!as.numeric(input$patient)) |> 
      collect()
  
      ggplot() +
      geom_segment(data = transfer_data,
                   aes(x = intime,
                       xend = outtime,
                       y = "ADT",
                       yend = "ADT",
                       color = careunit,
                       linewidth = str_detect(careunit, "ICU|CCU"))) +
      geom_point(data = procedures_icd,
                 aes(x = chartdate,
                     y = "Procedure",
                     shape = long_title)) +
      geom_point(data = labevents,
                 aes(x = storetime, y = "Lab"),
                 shape = "+") +
      labs(title = title,
           subtitle = str_top3,
           x = "Calendar Time",
           shape = "Procedure",
           color = "Care Unit") +
      scale_x_datetime(date_breaks = "1 week",
                       date_labels = "%b %d") +
      scale_y_discrete(limits = rev) +
      theme(legend.position = "bottom",
            legend.box = "vertical",
            legend.justification = "center",
            axis.title.y = element_blank()) +
      guides(linewidth = "none",
             shape = guide_legend(ncol = 2))
  })
  
}

shinyApp(ui = ui, server = server)
