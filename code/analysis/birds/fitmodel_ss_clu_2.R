source(file = "./package_load.R", chdir = T)
these.species <- 4:6
these.sets    <- 1:50
cluster <- TRUE
n <- 100

species.list <- c("broadbill_hummingbird", "cattle_egret", "common_grounddove",
                  "eurasian_wigeon", "greater_white_goose", "hooded_oriole", 
                  "lapland_longspur", "longbilled_curlew", "longeared_owl",
                  "mountain_bluebird", "northern_sawwhet_owl", "piping_plover", 
                  "snowy_plover", "tricolored_blackbird", "vesper_sparrow")

source("fitmodel_ss.R", chdir = TRUE)