# Required Packages 
{
  required_packages <- c(
    "dplyr", "ggplot2", "knitr", "forecast", "tidyr","tseries",
    "readr", "e1071", "stats", "MASS", "car","moments","labeling","farver", "caret"
  )
  install_and_load <- function(packages) {
    for (pkg in packages) {
      if (!requireNamespace(pkg, quietly = TRUE)) {
        install.packages(pkg)
      }
      library(pkg, character.only = TRUE)
    }
  }

  install_and_load(required_packages)
  

  set.seed(123)
}

{
  # Load data
  data <- read.csv("/Users/jainamrajput/Desktop/Study/Semester1/Data Stats and Info/Final Project/all_fuels_data.csv", header = TRUE, sep = ",")
  
  # Initial data overview
  print("Dataset Overview:\n")
  str(data)
  summary(data)
  # View(data)
}

# 2. Exploratory Data Analysis ----

# 2.1 Descriptive Statistics ----
{
  print("\n--- Descriptive Statistics ---\n")
  numeric_columns <- names(data)[sapply(data, is.numeric)]
  # Compute descriptive statistics
  descriptive_stats <- data.frame(
    Statistic = c("mean", "median", "min", "max", "sd", "variance")
  )
  
  for (col in numeric_columns) {
    descriptive_stats[[col]] <- c(
      mean(data[[col]], na.rm = TRUE),
      median(data[[col]], na.rm = TRUE),
      min(data[[col]], na.rm = TRUE),
      max(data[[col]], na.rm = TRUE),
      sd(data[[col]], na.rm = TRUE),
      var(data[[col]], na.rm = TRUE)
    )
  }
  
  # Print descriptive statistics
  print(kable(descriptive_stats, format = "simple"))

  # The dataset contains negative values for open, high, close and low prices. 
  # As price can not be negative we delete those values 
  print(paste("Length of data with negative values for prices: ", nrow(data)))
  data <- data[data$open>0 & data$close>0 & data$high>0 & data$low>0, ]
  print(paste("Length of data after removing negative values for prices: ", nrow(data)))
  # Null values analysis
  null_values <- colSums(is.na(data))
  null_values_table <- data.frame(
    Column = names(null_values),
    NullCount = null_values
  )
  
  print("\n--- Null Values ---\n")
  print(kable(null_values_table, format = "simple"))
  # Hence there are no null values present in the data 
}

# 2.2 Outlier Detection and Handling ----
{
  detect_and_handle_outliers <- function(data, columns) {
    outlier_results <- list()
    for (col in columns) {
      numeric_column <- data[[col]]
      # Calculate IQR and bounds
      Q1 <- quantile(numeric_column, 0.25, na.rm = TRUE)
      Q3 <- quantile(numeric_column, 0.75, na.rm = TRUE)
      IQR <- Q3 - Q1
      lower_bound <- Q1 - 1.5 * IQR
      upper_bound <- Q3 + 1.5 * IQR
      # Create boxplot
      png(paste0("Plots/boxplot_", col, ".png"))
      boxplot(numeric_column, main = paste("Boxplot for", col), ylab = "Value")
      dev.off()
      # Identify and replace outliers
      new_column_name <- paste0(col, "_no_outliers")
      data[[new_column_name]] <- ifelse(
        numeric_column >= lower_bound & numeric_column <= upper_bound,
        numeric_column,
        NA
      )
      # Store outlier statistics
      outlier_results[[col]] <- list(
        total_values = length(numeric_column),
        outliers = sum(is.na(data[[new_column_name]])),
        outlier_percentage = (sum(is.na(data[[new_column_name]])) / length(numeric_column)) * 100
      )
    }
    return(list(data = data, outlier_summary = outlier_results))
  }
  outlier_output <- detect_and_handle_outliers(data, numeric_columns)
  print("\n--- Outlier Analysis ---\n")
  print(outlier_output$outlier_summary)
}

# Skewness Analysis Function
{
  analyze_skewness <- function(data, numeric_columns) {
    skewness_results <- data.frame(
      column = character(),
      skewness = numeric(),
      interpretation = character(),
      stringsAsFactors = FALSE
    )
    
    for (col in numeric_columns) {
      numeric_column <- data[[col]]
      skewness_value <- skewness(numeric_column, na.rm = TRUE)
      interpretation <- case_when(
        abs(skewness_value) < 0.5 ~ "Approximately Symmetric",
        abs(skewness_value) >= 0.5 & abs(skewness_value) < 1 ~ "Moderately Skewed",
        abs(skewness_value) >= 1 & abs(skewness_value) < 2 ~ "Highly Skewed",
        abs(skewness_value) >= 2 ~ "Extremely Skewed"
      )
      skewness_results <- rbind(skewness_results, 
                                data.frame(
                                  column = col, 
                                  skewness = round(skewness_value, 4),
                                  interpretation = interpretation
                                ))
    }
    cat("\n--- Skewness Analysis ---\n")
    print(skewness_results)
    
    return(skewness_results)
  }
  skewness_output <- analyze_skewness(data, numeric_columns)
}

# # 2.4 Visualizing the Skewness 
{
  skewness_plot <- ggplot(skewness_output, aes(x = column, y = skewness, fill = interpretation)) +
    geom_bar(stat = "identity") +
    labs(title = "Skewness Across Columns",
        x = "Columns", 
        y = "Skewness Value") +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
  print(skewness_plot)
  ggsave("Plots/skewness_plot.png", plot = skewness_plot, width = 10, height = 6, units = "in", dpi = 300)
}

# 2.5 Applying Log Transformation ----

{
  cat("\n--- Normality Analysis ---\n")
  boxcox_transformed_data <- data

  for (col in numeric_columns) {
    numeric_column <- data[[col]]
    numeric_column <- ifelse(numeric_column <= 0, NA, numeric_column)

    # Kolmogorov-Smirnov test on original data
    valid_samples <- numeric_column[!is.na(numeric_column)]
    valid_samples <- valid_samples + runif(length(valid_samples), -1e-5, 1e-5)
    ks_test <- ks.test(valid_samples, "pnorm", mean(valid_samples, na.rm = TRUE), sd(valid_samples, na.rm = TRUE))

    # Box-Cox transformation
    boxcox_result <- boxcox(lm(numeric_column ~ 1, na.action = na.exclude), lambda = seq(-2, 2, 0.1))
    best_lambda <- boxcox_result$x[which.max(boxcox_result$y)]
    
    # Apply transformation
    transformed <- if (best_lambda == 0) log(numeric_column) else (numeric_column^best_lambda - 1) / best_lambda
    boxcox_transformed_data[[paste0(col, "_boxcox")]] <- transformed
    
    # Kolmogorov-Smirnov test on transformed data
    valid_transformed <- transformed[!is.na(transformed)]
    valid_transformed <- valid_transformed + runif(length(valid_transformed), -1e-5, 1e-5)
    ks_test_boxcox <- ks.test(valid_transformed, "pnorm", mean(valid_transformed, na.rm = TRUE), sd(valid_transformed, na.rm = TRUE))
    
    # Print results
    cat(sprintf("Column: %s\n", col))
    cat(sprintf("Original KS test p-value: %.4f\n", ks_test$p.value))
    cat(sprintf("Best lambda: %.4f\n", best_lambda))
    cat(sprintf("Transformed KS test p-value: %.4f\n\n", ks_test_boxcox$p.value))
  }
}

# Even after applying BoxCox the normality is not getting achieved. 
# Fat tails, asymmetry, and volatility clustering are some of the traits that cause financial data to naturally depart from the normal distribution. The application of suitable statistical techniques that better represent the intricate, dynamic character of financial markets and more accurate risk assessment are made possible by acknowledging this non-normality.


# 3. Hypothesis 1  - 

{
  
  average_close <- data %>%
    group_by(commodity) %>%
    summarise(avg_close = mean(close, na.rm = TRUE))
  print(average_close)

  widened_data <- data[ , c('date', 'commodity', 'close')] %>%
  pivot_wider(names_from = commodity, values_from = close)

  cor_matrix <- cor(widened_data[,-1], use = "pairwise.complete.obs")
  print(cor_matrix)

  # Predicting whether there is significant difference between avg closing price of different commodities?
  data$commodity <- as.factor(data$commodity)
  anova_avg_close <- aov(close ~ commodity, data = data) # ->Applying ANOVA 
  cat("\n--- ANOVA Analysis ---\n")
  print(summary(anova_avg_close))

  # Performing the Levene's Test for Homogeneity of Variance
  cat("\n--- Levene's Test ---\n")
  levene_test_result <- leveneTest(close ~ commodity, data = data)
  print(levene_test_result)

  png("Plots/anova_qq_plot.png")
  qqnorm(residuals(anova_avg_close))
  qqline(residuals(anova_avg_close), col = "red")
  dev.off()
}

# Hypothesis 2
{
  year_wise_data <- data %>% mutate(year = lubridate::year(date))
  volatility <- year_wise_data %>%
    group_by(commodity, year) %>%
    summarise(
      std_dev = sd(volume, na.rm = TRUE),
      mean_volume = mean(volume, na.rm = TRUE),
      coefficient_of_variation = std_dev / mean_volume
    ) %>%
    ungroup()
  ranking <- volatility %>%
    group_by(commodity) %>%
    summarise(avg_cv = mean(coefficient_of_variation, na.rm = TRUE)) %>%
    arrange(desc(avg_cv))
  print(ranking)
}


# Hypothesis 3
{
  # Feature Engineering
  data$commodity_encoded <- as.numeric(factor(data$commodity))
  data$Volatility <- data$high - data$low
  data$Intraday_Change <- data$close - data$open
  data$Momentum <- ((data$close - dplyr::lag(data$close)) / dplyr::lag(data$close)) * 100
  data$MA_3 <- stats::filter(data$close, rep(1/3, 3), sides = 1)
  data$MA_5 <- stats::filter(data$close, rep(1/5, 5), sides = 1)
  
  # Target variable
  data$Next_Close <- dplyr::lead(data$close)
  
  # Remove NA rows
  data <- na.omit(data)
  
  # Train-Test Split
  train_indices <- sample(1:nrow(data), size = 0.8 * nrow(data))
  train_data <- data[train_indices, ]
  test_data <- data[-train_indices, ]
  
  # Linear Regression Model
  lm_model <- lm(Next_Close ~ commodity_encoded + Volatility + Intraday_Change + Momentum + MA_3 + MA_5, 
                 data = train_data)
  
  print(summary(lm_model))
  # Model Evaluation
  test_data$predicted_close <- predict(lm_model, test_data)
  print("After applying linear regression model to predict the next day closing price we get results as: ")
  cat("\n--- Model Performance Metrics ---\n")
  mae <- mean(abs(test_data$Next_Close - test_data$predicted_close))
  rmse <- sqrt(mean((test_data$Next_Close - test_data$predicted_close)^2))
  rsq <- 1 - sum((test_data$Next_Close - test_data$predicted_close)^2) / 
         sum((test_data$Next_Close - mean(test_data$Next_Close))^2)
  
  cat(sprintf("Mean Absolute Error: %.4f\n", mae))
  cat(sprintf("Root Mean Square Error: %.4f\n", rmse))
  cat(sprintf("R-squared: %.4f\n", rsq))
  
  # Visualization
  png("Plots/predicted_vs_actual.png")
  plot(test_data$Next_Close, test_data$predicted_close, 
       main = "Predicted vs Actual Closing Prices",
       xlab = "Actual Close", ylab = "Predicted Close")
  abline(0, 1, col = "red", lty = 2)
  dev.off()
  # Check for seasonality
  is_seasonal <- function(ts_data) {
    freq <- findfrequency(ts_data)
    return(freq > 1) # If the frequency detected is greater than 1, it indicates potential seasonality
  }
  mae_values <- c()

  for (commodity_name in unique(data$commodity)) {
    commodity_data <- data[data$commodity == commodity_name, ]
    close_prices <- ts(commodity_data$close, frequency = 252)
    train_size <- floor(0.8 * length(close_prices))
    train_data <- close_prices[1:train_size]
    test_data <- close_prices[(train_size + 1):length(close_prices)]
    seasonal <- is_seasonal(train_data)
    cat("\n--- Analysis for Commodity:", commodity_name, "---\n")
    cat("Seasonality detected:", seasonal, "\n")
    adf_result <- adf.test(train_data, alternative = "stationary")
    cat("ADF p-value:", adf_result$p.value, "\n")
    tryCatch({
      if (adf_result$p.value < 0.05) {
        if (seasonal) {
          model <- auto.arima(train_data, seasonal = TRUE, 
                              stepwise = FALSE, approximation = FALSE)
        } else {
          model <- auto.arima(train_data, seasonal = FALSE, 
                              stepwise = FALSE, approximation = FALSE)
        }
      } else {
        diff_data <- diff(train_data)
        model <- auto.arima(diff_data, seasonal = seasonal, 
                            stepwise = FALSE, approximation = FALSE)
      }
      forecast_result <- forecast(model, h = length(test_data))
      predicted_values <- as.numeric(forecast_result$mean)
      mae_forecast <- mean(abs(test_data - predicted_values))
      mae_values <- c(mae_values, mae_forecast)
      cat(sprintf("Forecast MAE for %s: %.4f\n", commodity_name, mae_forecast))
      png(paste0("Plots/time_series_forecast_", commodity_name, ".png"))
      plot(forecast_result, main = paste("Time Series Forecast for", commodity_name))
      dev.off()
      
    }, error = function(e) {
      cat("Time series modeling failed for", commodity_name, ":", e$message, "\n")
    })
  }
  average_mae <- mean(mae_values)
  cat("\n--- Overall Forecast Performance ---\n")
  cat(sprintf("Average Forecast MAE across all commodities: %.4f\n", average_mae))
}