library(ggplot2)
library(dplyr)
library(scales)

df <- read.csv("benchmark.csv")

# Espera-se que o CSV tenha:
# scenario, space_size, attempts, crack_time

required_cols <- c("scenario", "space_size", "attempts", "crack_time")

if (!all(required_cols %in% colnames(df))) {
  stop(paste("O CSV precisa conter as colunas:", paste(required_cols, collapse=", ")))
}

df <- df %>%
  mutate(
    attempts_per_sec = attempts / crack_time,
    estimated_full_time = space_size / attempts_per_sec
  )

# PLOT 1 — PIN vs PIN + KDF

df_pin <- df %>%
  filter(scenario %in% c("PIN", "PIN + KDF"))

p1 <- ggplot(df_pin, aes(x = scenario, y = crack_time)) +
  geom_col(color = "black", alpha = 0.8) +
  scale_y_log10(labels = label_comma()) +
  labs(
    title = "PIN vs PIN + KDF — Crack Time",
    x = "Scenario",
    y = "Crack Time (seconds)"
  ) +
  theme_bw()

ggsave("plot1_pin_vs_kdf.png", p1, width = 7, height = 5)

# PLOT 2 — 6-char vs 2 words

df_pwd <- df %>%
  filter(scenario %in% c("6-char", "2 words"))

p2 <- ggplot(df_pwd, aes(x = scenario, y = crack_time)) +
  geom_col(color = "black", alpha = 0.8) +
  scale_y_log10(labels = label_comma()) +
  labs(
    title = "6 Characters vs Two Words — Crack Time",
    x = "Scenario",
    y = "Crack Time (seconds)"
  ) +
  theme_bw()

ggsave("plot2_6char_vs_2words.png", p2, width = 7, height = 5)

# PLOT 4 — Tempo projetado completo

p4 <- ggplot(df, aes(x = scenario, y = estimated_full_time)) +
  geom_col(color = "black", alpha = 0.8) +
  scale_y_log10(labels = label_comma()) +
  labs(
    title = "Projected Full Brute Force Time",
    x = "Scenario",
    y = "Estimated Full Search Time (seconds)"
  ) +
  theme_bw()

ggsave("plot4_projected_full_time.png", p4, width = 7, height = 5)

print("Todos os plots foram gerados com sucesso.")

print(p1)
print(p2)
print(p4)