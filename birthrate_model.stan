data {
    int<lower=0> N;
    int<lower=0> M;
    vector[N*M] y;
    vector[N*M] years;
    array[N*M] int months;
    int<lower=0> N_new;
    vector[N_new*M] new_years;
    array[N_new*M] int new_months;
    real y_hat;
}
parameters {
    real alpha;
    vector[M] beta;
    real<lower=0> sigma;
}
model {
    y ~ normal(alpha*years + beta[months], sigma);
}
generated quantities {
    array[N_new*M] real y_tilde;
    y_tilde = normal_rng(alpha*new_years + beta[new_months] + y_hat, sigma);
}
