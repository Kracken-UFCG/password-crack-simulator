# 0. Limpeza e bibliotecas
graphics.off()
rm(list = ls())
library(ggplot2)
library(dplyr)
library(patchwork)
library(scales)

df_letras <- read.csv("plots/senhas_estruturadas.csv", stringsAsFactors = FALSE)
df_letras$tipo <- "Estruturada (4 Letras + 2)"
df_aleatorio <- read.csv("plots/senhas_aleatorias.csv", stringsAsFactors = FALSE)
df_aleatorio$tipo <- "Totalmente Aleatória"

df_comparativo <- rbind(df_letras, df_aleatorio)
if (!dir.exists("plots_output")) dir.create("plots_output")
cores_comp <- c("Totalmente Aleatória" = "#6ab1b0", "Estruturada (4 Letras + 2)" = "#e98973")

p1 <- ggplot(df_comparativo, aes(x = tipo, y = entropy_shannon, fill = tipo)) +
  geom_violin(alpha = 0.4, color = NA) +
  geom_boxplot(width = 0.2, color = "#444444") +
  scale_fill_manual(values = cores_comp) +
  labs(title = "1. Entropia de Shannon", y = "Bits", x = NULL) +
  theme_minimal() +
  theme(legend.position = "none")

p2 <- ggplot(df_comparativo, aes(x = cracktime_s, fill = tipo)) +
  geom_density(alpha = 0.6) +
  scale_x_log10() +
  scale_fill_manual(values = cores_comp) +
  labs(title = "2. Tempo de Quebra", x = "Segundos (Log)", y = "Densidade") +
  theme_minimal()

p3 <- ggplot(df_comparativo, aes(x = early_ratio, fill = tipo)) +
  geom_histogram(bins = 20, position = "identity", alpha = 0.6, color = "white") +
  scale_fill_manual(values = cores_comp) +
  labs(title = "3. Early Ratio", x = "Proporção", y = "Contagem") +
  theme_minimal()

df_cum <- df_comparativo %>%
  group_by(tipo) %>%
  arrange(cracktime_s) %>%
  mutate(p = row_number() / n())
p4 <- ggplot(df_cum, aes(x = cracktime_s, y = p, color = tipo)) +
  geom_line(linewidth = 1.2) +
  scale_x_log10() +
  scale_y_continuous(labels = percent_format()) +
  scale_color_manual(values = cores_comp) +
  labs(title = "4. Sucesso Acumulado", x = "Tempo (s)", y = "% Quebradas") +
  theme_minimal()

dashboard_geral <- ((p1 | p2) / (p3 | p4)) +
  plot_layout(guides = "collect") +
  plot_annotation(
    title = "Análise de Segurança: Senhas Estruturadas vs. Aleatórias",
    theme = theme(plot.title = element_text(size = 18, face = "bold", hjust = 0.5))
  ) & theme(legend.position = "bottom")

ggsave("plots_output/p1.png", plot = p1, width = 8, height = 6)
ggsave("plots_output/p2.png", plot = p2, width = 8, height = 6)
ggsave("plots_output/p3.png", plot = p3, width = 8, height = 6)
ggsave("plots_output/p4.png", plot = p4, width = 8, height = 6)
ggsave("plots_output/dashboard_geral_completo.png", dashboard_geral, width = 12, height = 15, dpi = 300)

message("Dashboard gerado com sucesso!")
