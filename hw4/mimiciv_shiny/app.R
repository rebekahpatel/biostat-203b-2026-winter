library(shiny)

ui <- pageWithSidebar(
  
  # App title 
  headerPanel("Exploring the Mimic Dataset"),
  
  # Sidebar panel for inputs
  sidebarPanel(),
  
  # Main panel for displaying outputs
  mainPanel()
)

server <- function(input, output) {
  
  
}

shinyApp(ui, server)
