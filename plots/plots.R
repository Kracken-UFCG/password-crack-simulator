library(ggplot2)
library(dplyr)
library(scales)

df <- read.csv("results.csv")

required_cols <- c("scenario", "space_size", "attempts", "crack_time")

df$scenario <- factor(
  df$scenario,
  levels = c(
    "pin 4 digit",
    "pin 4 digit kdf",
    "6 char",
    "2 palavras"
  )
)

if (!all(required_cols %in% colnames(df))) {
  stop(paste("O CSV precisa conter as colunas:", paste(required_cols, collapse=", ")))
}

df <- df %>%
  mutate(
    attempts_per_sec = attempts / crack_time,
    estimated_full_time = space_size / attempts_per_sec
  )

theme_att <- function() {
  theme_linedraw(base_size = 13) +
    ggplot2::theme(
      plot.title = element_text(face = "bold", size = 16),
      plot.subtitle = element_text(size = 12, color = "gray30"),
      axis.title = element_text(face = "bold", color = "black"),
      axis.text = element_text(color = "black"),
      panel.grid.major.x = element_blank(),
      panel.grid.minor = element_blank(),
      legend.position = "none"
    )
}

neutral_palette <- c(
  "pin 4 digit" = "#BDBDBD",
  "pin 4 digit kdf" = "#636363",
  "6 char" = "#D9D9D9",
  "2 palavras" = "#252525"
)

scale_y_log_clean <- scale_y_log10(
  labels = label_number(big.mark = ",")
)

# PLOT 1 — pin 4 digit vs com kdf

df_pin <- df %>%
  filter(scenario %in% c("pin 4 digit", "pin 4 digit kdf"))

df_pin$id <- seq_len(nrow(df_pin))

p1 <- ggplot(df_pin,
             aes(x = scenario,
                 y = crack_time,
                 group = id,
                 color = scenario)) +

  geom_point(size = 2) +

  scale_color_manual(values = neutral_palette) +
  scale_y_log_clean +
  labs(
    title = "Impacto do KDF em PIN de 4 Dígitos",
    x = NULL,
    y = "Tempo até a quebra da senha (segundos)"
  ) +
  theme_att()

ggsave("plot1_pin_vs_kdf.png", p1, width = 7, height = 5, dpi = 300)

# PLOT 2 — 6 char vs 2 palavras

df_pwd <- df %>%
  filter(scenario %in% c("6 char", "2 palavras"))

p2 <- ggplot(df_pwd, aes(x = scenario, y = crack_time, fill = scenario)) +
  geom_boxplot(
    alpha = 0.25,
    width = 0.5,
    outlier.shape = NA,
    color = "gray30",
    linewidth = 0.5,
    median.colour = "gray30",
    median.linewidth = 0.6
  ) +
  geom_jitter(width = 0.08, size = 1.6, alpha = 1) +
  scale_fill_manual(values = neutral_palette) +
  scale_y_log_clean +
  labs(
    title = "Comparação de Complexidade de Senhas",
    x = NULL,
    y = "Tempo até a quebra da senha (segundos)"
  ) +
  theme_att()

ggsave("plot2_6char_vs_2words.png", p2, width = 7, height = 5)

# PLOT 3 — Numero de tentativas por grupo

df_grouped <- df %>%
  mutate(
    group = case_when(
      scenario == "pin 4 digit" ~ "4 PIN",
      scenario == "pin 4 digit kdf" ~ "4 PIN + KDF",
      scenario == "6 char" ~ "6 CHAR",
      scenario == "2 palavras" ~ "2 PALAVRAS",
      TRUE ~ "Outro"
    )
  ) %>%
  filter(group != "Outro")

p3 <- ggplot(df_grouped,
             aes(x = scenario, y = attempts, fill = scenario)) +
  geom_boxplot(
    alpha = 0.25,
    width = 0.5,
    outlier.shape = NA,
    color = "gray30",
    linewidth = 0.5,
    median.colour = "gray30",
    median.linewidth = 0.6
  ) +
  geom_jitter(width = 0.08, size = 1.6, alpha = 1) +
  scale_fill_manual(values = neutral_palette) +
  scale_y_log_clean +
  labs(
    title = "Número de Tentativas por Tipo de Senha",
    x = NULL,
    y = "Tentativas"
  ) +
  theme_att()

ggsave("plot3_attempts_by_group.png", p3, width = 7, height = 5, dpi = 300)