#!/usr/bin/env Rscript
args <- commandArgs(trailingOnly = TRUE)
unknown <- setdiff(args, "--smoke")
if (length(unknown)) stop("Supported option: --smoke")
# Works when called from any directory; no RStudio editor API is needed.
all_args <- commandArgs()
script_arg <- grep("^--file=", all_args, value = TRUE)
script_path <- if (length(script_arg)) sub("^--file=", "", script_arg[1]) else {
  at <- which(all_args %in% c("-f", "--file"))
  if (!length(at)) stop("Run this file with Rscript.")
  all_args[at[1] + 1L]
}
root <- dirname(dirname(normalizePath(script_path)))
setwd(root)
source(file.path(root, "src", "ml_pipeline.R"))
smoke <- "--smoke" %in% args
outdir <- file.path(root, "results", if (smoke) "smoke" else "full")
result <- run_experiment(read_project_data(root), outdir, smoke = smoke)
print(result$comparison, row.names = FALSE)
