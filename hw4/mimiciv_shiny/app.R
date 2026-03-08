library(shiny)
library(bslib)
library(ggplot2)
library(gtsummary)
library(gt)

mimic_icu_cohort <- readRDS("mimic_icu_cohort.rds")

ui <- navbarPage(
  title = "Exploring the Mimic Dataset",
  theme = bs_theme(version = 5),
  
  tabPanel("Variable Exploration",
    sidebarLayout(
      sidebarPanel(
        card(
            # which graph should be shown
            selectInput(
              inputId = "var",
              label = "Lab/Vital/Demographic Summary:",
              choices = c("hematocrit", "creatinine", "chloride", "sodium",
                          "glucose", "bicarbonate", "wbc", "potassium",
                          "heart_rate", "temperature_fahrenheit",
                          "non_invasive_blood_pressure_diastolic",
                          "respiratory_rate",
                          "non_invasive_blood_pressure_systolic",
                          "los", "insurance", "language",
                          "marital_status", "race", "gender"),
              selected = "hematocrit"
            )
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
      sidebarPanel(),
      mainPanel()
    )
  )
)

categorical = c("insurance", "language",
         "marital_status", "race", "gender")

continuous = c("hematocrit", "creatinine", "chloride", "sodium",
         "glucose", "bicarbonate", "wbc", "potassium", "los",
         "heart_rate", "temperature_fahrenheit",
         "non_invasive_blood_pressure_diastolic",
         "respiratory_rate",
         "non_invasive_blood_pressure_systolic")

server <- function(input, output) {
  
  output$barplot <- renderPlot({
    
    if (input$var %in% categorical) {
      ggplot(data = mimic_icu_cohort, 
             aes(x = .data[[input$var]])) +
        geom_bar(fill = "steelblue") +
        theme_minimal() +
        labs(title = paste("Distribution of ", input$var), 
             y = "Count") +
        theme(axis.text.x = element_text(angle = 45, hjust = 1))
    } 
    else {
      ggplot(data = mimic_icu_cohort,
             aes(x = .data[[input$var]])) +
      geom_boxplot(fill = "orange") +
      theme_minimal() +
      labs(title = paste("Distribution of ", input$var),
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
  
  
}

shinyApp(ui = ui, server = server)
