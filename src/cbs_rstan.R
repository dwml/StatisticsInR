library(rstan)

# Advised options by rstan
options(mc.cores = parallel::detectCores())
rstan_options(auto_write = TRUE)

read_or_fit_stan_model <- function(stanfile, data, fit_path) {
    if (file.exists((fit_path))) {
        fit <- readRDS(fit_path)
    } else {
        fit <- stan(
            file = stanfile,
            data = data,
            chains = 4,
            iter = 8000,
            warmup = 2000,
            verbose = TRUE
        )
        fit@stanmodel@dso <- new("cxxdso")
        saveRDS(fit, file = fit_path)
    }
    fit
}
