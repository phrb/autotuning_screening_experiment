library(dplyr)
library(tidyr)
library(GGally)
library(FrF2)

experiment_dir <- "autotuning_screening_experiment/data/5_replications_pilipili2/"

factors_file <- paste(experiment_dir, "factors.csv", sep = "")
results_file <- paste(experiment_dir, "results.csv", sep = "")
screening_file <- paste(experiment_dir, "screening_design.csv", sep = "")

factors <- as.data.frame(read.csv(factors_file, header = TRUE, sep = ","))
results <- as.data.frame(read.csv(results_file, header = TRUE, sep = ","))
screening <- as.data.frame(read.csv(screening_file, header = TRUE, sep = ","))

n <- c(make.names(trimws(factors$name, which = c("left"))),
       "response")

ordered_results <- as.data.frame(results[n])

ordered_results$X..optimize. = as.factor(ordered_results$X..optimize.)
ordered_results$X.Xptxas...opt.level. = as.factor(ordered_results$X.Xptxas...opt.level.)
ordered_results$X.Xptxas...maxrregcount. = as.factor(ordered_results$X.Xptxas...maxrregcount.)

# Uncomment to generate well-formatted figure:
#
#names(ordered_results)
#
#names(ordered_results) <- c("prl", "nad", "ufm", "ftz", "psq", "gpa", "opt", "rdc",
#                            "prd", "aee", "fmd", "flc", "opl", "fsc", "mrc", "dummy1",
#                            "dummy2", "dummy3", "dummy4", "response")

reg = aov(data = ordered_results, response ~ .)

summary.aov(reg)

summary.lm(reg)

# Uncomment to generate well-formatted figure:
#
#names(reg)
#MEPlot(reg, main = "Main Effects Plot of CUDA Compilation Flags for Execution Time", pch = 20,
#       lwd = 3, cex.xax = 1.7, cex.yax = 2, cex.title = 2, cex.main = 1.8, cex.lab = 1.5, abbrev = 2)
MEPlot(reg)

library(dplyr)
library(tidyr)
library(GGally)
library(FrF2)

experiment_dir <- "autotuning_screening_experiment/data/heartwall/5_replications_pilipili2/"

factors_file <- paste(experiment_dir, "factors.csv", sep = "")
results_file <- paste(experiment_dir, "results.csv", sep = "")
screening_file <- paste(experiment_dir, "screening_design.csv", sep = "")

factors <- as.data.frame(read.csv(factors_file, header = TRUE, sep = ","))
results <- as.data.frame(read.csv(results_file, header = TRUE, sep = ","))
screening <- as.data.frame(read.csv(screening_file, header = TRUE, sep = ","))

n <- c(make.names(trimws(factors$name, which = c("left"))),
       "response")

ordered_results <- as.data.frame(results[n])

ordered_results$X..optimize. = as.factor(ordered_results$X..optimize.)
ordered_results$X.Xptxas...opt.level. = as.factor(ordered_results$X.Xptxas...opt.level.)
ordered_results$X.Xptxas...maxrregcount. = as.factor(ordered_results$X.Xptxas...maxrregcount.)

# Uncomment to generate well-formatted figure:
#
#names(ordered_results)
#
#names(ordered_results) <- c("prl", "nad", "ufm", "ftz", "psq", "gpa", "opt", "rdc",
#                            "prd", "aee", "fmd", "flc", "opl", "fsc", "mrc", "dummy1",
#                            "dummy2", "dummy3", "dummy4", "response")

reg = aov(data = ordered_results, response ~ .)

summary.aov(reg)

summary.lm(reg)

# Uncomment to generate well-formatted figure:
#
#names(reg)
#MEPlot(reg, main = "Main Effects Plot of CUDA Compilation Flags for Execution Time", pch = 20,
#       lwd = 3, cex.xax = 1.7, cex.yax = 2, cex.title = 2, cex.main = 1.8, cex.lab = 1.5, abbrev = 2)
MEPlot(reg)
