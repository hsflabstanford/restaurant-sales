library(cmdstanr)
library(posterior)
library(tidyverse)
library(arrow)
library(dplyr)
library(lubridate)
library(grid)
library(patchwork)

set_cmdstan_path("C:/Users/godli/.cmdstan/cmdstan-2.36.0/cmdstan-2.36.0")
source("tools/modeling_functions.R") 

set.seed(123)