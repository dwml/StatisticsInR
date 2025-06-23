library(dplyr)
library(cbsodataR)
library(tidyr)
library(ggplot2)
library(ggridges)
library(shinystan)

source("src/cbs_io.R")
source("src/cbs_rstan.R")


# CONSTANTS
birthrate_db_id <- "37230ned"
birthrate_db_path <- file.path(
    paste("data/", birthrate_db_id, ".csv", sep = "")
)
columns <- c("RegioS", "Perioden", "LevendGeborenKindern_2")

# Check if file exists, else download it once and save it in data folder
# this function is implemented in src/cbs_io.R
df <- check_file_exists_or_download(
    birthrate_db_id,
    birthrate_db_path,
    columns
)

# Select region NL
df_nl <- dplyr::filter(df, RegioS %in% c("NL01  "))

# Throw away unused columns
df_nl <- dplyr::select(
    df_nl,
    c("RegioS", "Perioden", "LevendGeborenKinderen_2")
)

# Remove total per year and split year and month, such that it is in separate
# columns
df_nl <- df_nl[grep("*MM*", df_nl$Perioden), ]
df_nl <- separate_wider_delim(
    df_nl,
    col = Perioden,
    delim = "MM",
    names = c("year", "month")
)

# Put newest data in separate df and only use older data to fit the model
df_newest <- df_nl[grep("202[4-5]", df_nl$year), ]
df_newest$date <- as.Date(
    sprintf(
        "%d/%02d/%02d",
        as.numeric(df_newest$year),
        as.numeric(df_newest$month),
        rep(c(1), times = nrow(df_newest))
    ),
    format = "%Y/%m/%d"
)
# notice the minus, which removes the found rows
df_nl <- df_nl[-grep("202[4-5]", df_nl$year), ]

# Transform y to vector and demean, demeaning makes it easier to fit
y <- as.vector(df_nl$LevendGeborenKinderen_2) / 1.
y_hat <- mean(y)
y <- y - y_hat

# Transform y to vector and demean, demeaning makes it easier to fit
years <- as.vector(as.numeric(df_nl$year))
years_hat <- mean(years)
years <- years - years_hat

months <- as.vector(as.numeric(df_nl$month))

# Create new data that the model uses to predict
new_years <- rep(c(2024, 2025, 2026), each = 12)
new_years <- new_years - years_hat
new_months <- rep(c(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12), times = 3)

# Input for model
# We also make some new predictions that will be stored in y_hat
data <- list(
    N = 22,
    M = 12,
    y = y,
    years = years,
    months = months,
    N_new = 3,
    new_years = new_years,
    new_months = new_months,
    y_hat = y_hat
)

fit <- read_or_fit_stan_model("birthrate_model.stan", data, "./data/fit.rds")

# The fit can easily be inspected using shinystan
# sso <- launch_shinystan((fit))

df_original <- data.frame(
    year = years + years_hat,
    month = months,
    median = y + y_hat
)

y_hat_summary <- summary(
    fit,
    pars = c(
        "y_tilde[1]",
        "y_tilde[2]",
        "y_tilde[3]",
        "y_tilde[4]",
        "y_tilde[5]",
        "y_tilde[6]",
        "y_tilde[7]",
        "y_tilde[8]",
        "y_tilde[9]",
        "y_tilde[10]",
        "y_tilde[11]",
        "y_tilde[12]",
        "y_tilde[13]",
        "y_tilde[14]",
        "y_tilde[15]",
        "y_tilde[16]",
        "y_tilde[17]",
        "y_tilde[18]",
        "y_tilde[19]",
        "y_tilde[20]",
        "y_tilde[21]",
        "y_tilde[22]",
        "y_tilde[23]",
        "y_tilde[24]",
        "y_tilde[25]",
        "y_tilde[26]",
        "y_tilde[27]",
        "y_tilde[28]",
        "y_tilde[29]",
        "y_tilde[30]",
        "y_tilde[31]",
        "y_tilde[32]",
        "y_tilde[33]",
        "y_tilde[34]",
        "y_tilde[35]",
        "y_tilde[36]"
    ),
    probs = c(
        0.015, 0.5, 0.985
    ),
)$summary

df_predictions <- data.frame(
    year = new_years + years_hat,
    month = new_months,
    lower_limit = y_hat_summary[, "1.5%"],
    upper_limit = y_hat_summary[, "98.5%"],
    median = y_hat_summary[, "50%"]
)
df_predictions$group <- "predictions"

df_original$lower_limit <- as.double(NA)
df_original$upper_limit <- as.double(NA)
df_original$group <- "original"

full_df <- rbind(df_original, df_predictions)
rownames(full_df) <- seq_len(nrow(full_df))

# Combine the year and month column into a date for plotting purposes
full_df$date <- as.Date(
    sprintf(
        "%d/%02d/%02d",
        full_df$year,
        full_df$month,
        rep(c(1), times = nrow(full_df))
    ),
    format = "%Y/%m/%d"
)


legend_colors <- c(
    "Original Data" = "#000000",
    "Median Predictions" = "#7996a0"
)
pl <- ggplot() +
    geom_line(
        data = full_df[full_df$group == "original", ],
        aes(x = date, y = median, color = "Original Data"),
    ) +
    geom_line(
        data = full_df[full_df$group == "predictions", ],
        aes(x = date, y = median, color = "Median Predictions"),
    ) +
    guides(col = guide_legend(title = "Legend", reverse = TRUE)) +
    scale_color_manual(values = legend_colors) +
    theme_bw()
ggsave(filename = "figures/overview.png", plot = pl)

legend_colors2 <- c(
    "Original Data" = "#000000",
    "Predictions w/ 97% CI" = "#7996a0"
)
legend_shapes2 <- c(
    "Original Data not used for fitting." = 5
)
pl2 <- ggplot() +
    scale_x_date(
        date_breaks = "1 year",
        date_minor_breaks = "1 month",
        limits = c(
            as.Date("2023/01/01", format = "%Y/%m/%d"),
            as.Date("2026/12/31", format = "%Y/%m/%d")
        ),
        date_labels = "%Y"
    ) +
    geom_ribbon(
        data = full_df[full_df$group == "predictions", ],
        aes(
            x = date,
            y = median,
            ymin = lower_limit,
            ymax = upper_limit,
        ),
        fill = "#add8e6",
        color = "#add8e6",
        outline.type = "full",
        alpha = 1.
    ) +
    geom_line(
        data = full_df[full_df$group == "original", ],
        aes(x = date, y = median, color = "Original Data"),
    ) +
    geom_line(
        data = full_df[full_df$group == "predictions", ],
        aes(x = date, y = median, color = "Predictions w/ 97% CI"),
    ) +
    scale_color_manual(values = legend_colors2) +
    labs(color = "Legend") +
    geom_point(
        data = df_newest, aes(
            x = date,
            y = LevendGeborenKinderen_2,
            shape = "Original Data not used for fitting."
        ),
    ) +
    scale_shape_manual(values = legend_shapes2) +
    labs(shape = "Legend") +
    theme_bw()

ggsave(filename = "figures/zoom.png", plot = pl2)
