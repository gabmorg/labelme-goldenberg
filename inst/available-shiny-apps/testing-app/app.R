# TO DO: add DICOM files support
ui <- fluidPage(
  titlePanel("labelMe: Manual Labelling for Clinical Imaging"),
  # Arrow navigation between images (Javascript):
  tags$script(
    '
    $(document).on("keydown", function(e) {
    key = e.which;
    if(key === 39) {
    Shiny.onInputChange("rightArrow", [e.which, e.timeStamp]);
    }
    else if(key === 37) {
    Shiny.onInputChange("leftArrow", [e.which, e.timeStamp]);
    }
    });
    '
  ),
  sidebarLayout(
    position = "right",
    sidebarPanel(
      h3("Images"),
      uiOutput('fileInputs'),
      fluidRow(
        actionButton("flushData", "Flush Data"),
        downloadButton("download", "Download DATE-labels.csv")
      )
    ),
    mainPanel(
      uiOutput('images'),
      textOutput("radioSelection"),
      uiOutput('radios'),
      br(),
      h3("Images Uploaded"),
      br(),
      tableOutput('fileTable')
    )
  )
)

server <- shinyServer(function(input, output) {
  imagePages <- reactiveValues(page = 1)

  # pagination navigation helper:
  navigate <- function(direction, toStart = FALSE) {
    if (toStart) {
      imagePages$page <- 1
    }
    else {
      imagePages$page <- imagePages$page + direction
    }

  }

  # access with files()
  files <- reactive({
    input$flushData
    files <- input$files
    files$image_key <- c(1:nrow(input$files))
    files$datapath <- gsub("\\\\", "/", files$datapath)
    files$label <- c("Unknown")
    files
  })

  # Initialize dataframe built dynamically upon each labeling event
  # Serves as the session's data store to create the output CSV
  # This runs once per session
  selectiondf <- reactiveValues()
  selectiondf$df <- data.frame(
    image_key = integer(),
    image_name = character(),
    label_1 = character(),
    label_2 = character(),
    stringsAsFactors = FALSE
  )

  # Display uploaded file info
  output$fileTable <- renderTable({
    input$flushData
    if (is.null(input$files))
      return(NULL)
    else {
      return(files())
    }
  })

  # File input browser server-side setup
  output$fileInputs <- renderUI({
    input$flushData
    fileInput(
      inputId = 'files',
      label = 'Upload labeling images here',
      multiple = TRUE,
      accept = c(
        'image/png',
        'image/jpeg',
        'image/jpg',
        'image/pdf',
        'image/dicom-rle',
        'image/jls'
      )
    )
  })

  # Paginated images setup for uiOutput('images')
  output$images <- renderUI({
    input$flushData
    if (is.null(input$files))
      return(NULL)
    else {
      imageId <- paste0("image", imagePages$page)
      fluidRow(column(10, offset = 2, imageOutput(imageId)))
    }
  })

  # Paginated radio button setup for uiOutput('radios')
  output$imgName <- renderText({
    files()$name[imagePages$page]
  })
  output$radios <- renderUI({
    input$flushData

    if (is.null(input$files)) {
      return(NULL)
    }
    else {
      radioIdA <- paste0("radioA", imagePages$page)
      radioIdB <- paste0("radioB", imagePages$page)

      fluidRow(
        column(
          3,
          offset = 2,
          radioButtons(
            inputId = radioIdA,
            label = textOutput("imgName"),
            choices = c("Saggital", "Transverse",
                        "Bladder", "Unknown"),
            selected = selectiondf$df[imagePages$page, "label_1"]
          )
        ),
        column(
          3,
          offset = 2,
          radioButtons(
            inputId = radioIdB,
            label = "View type",
            choices = c("Left", "Right",
                        "Not Applicable"),
            selected = selectiondf$df[imagePages$page, "label_2"]
          )
        )
    )}
  })

  # Visual confirmation of selected radio button option (default is Unknown)
  # this code also attaches the label to selectiondf,
  # which is updated whenever a radio button option is selected at
  # the row corresponding to the image page
  # i.e. this expression is reactive on input[[radioIdA]], input[[radioIdB]]
  selectedOption <- reactive({
    if (is.null(input$files)) {
      return("NULL")
    }
    else {
      radioIdA <- paste0("radioA", imagePages$page)
      radioIdB <- paste0("radioB", imagePages$page)

      selectiondf$df[imagePages$page, "image_key"] <- imagePages$page
      selectiondf$df[imagePages$page, "image_name"] <- files()$name[imagePages$page]
      selectiondf$df[imagePages$page, "label_1"] <- input[[radioIdA]]
      selectiondf$df[imagePages$page, "label_2"] <- input[[radioIdB]]

      # Debug print (in console):
      print(paste0("Image label: ", input[[radioIdA]], input[[radioIdB]]))

      return(c(input[[radioIdA]], input[[radioIdB]]))
    }
  })
  output$radioSelection <- renderText({
    paste0("This image has been labeled: ",
           selectedOption()[1],
           ", ",
           selectedOption()[2])
  })

  # Paginated image rendering - From SO post: [LINK]
  observeEvent(input$files, {
    if (is.null(input$files))
      return(NULL)
    for (i in 0:nrow(files())) {
      local({
        local_i <- i
        imageIndex <- paste0("image", local_i)
        output[[imageIndex]] <-
          renderImage({
            list(
              src = files()$datapath[local_i],
              width = "400",
              height = "400",
              alt = "Image upload failed!"
            )
          }, deleteFile = FALSE)

      })
    }
  })

  # Arrow navigation between pages:
  observeEvent(input$rightArrow, {
    if (imagePages$page < nrow(files())) {
      navigate(1)
    }
    else
      navigate(0)

    # TO DELETE: bug tracking
    print(imagePages$page)
  })

  observeEvent(input$leftArrow, {
    if (imagePages$page >= 2) {
      navigate(-1)
    }
    else
      navigate(0)

    # TO DELETE: bug tracking
    print(imagePages$page)
  })

  # Download a file with the name labels-DATE.csv
  # the contents are equal to the contents of the data table
  # displayed on the user interface
  output$download <- downloadHandler(
    filename = function() {
      paste(Sys.Date(), "-labels", ".csv", sep = "")
    },
    content = function(fname) {
      write.csv(selectiondf$df, fname)
    },
    contentType = "text/csv"
  )

  observeEvent(input$flushData, {
    for (i in 0:nrow(files())) {
      local({
        local_i <- i
        imageIndex <- paste0("image", local_i)
        output[[imageIndex]] <- NULL
      })
    }

    selectiondf$df <- data.frame(
      image_key = c(1),
      image_name = c("test image_name"),
      label_1 = c("Unknown"),
      label_2 = c("Not applicable"),
      stringsAsFactors = FALSE
    )

    files <- NULL
    navigate(0, toStart = TRUE)
  })
})



shinyApp(ui = ui, server = server)
