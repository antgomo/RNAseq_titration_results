# J. Taroni Jun 2016
# The purpose of this script is to read in TGCA array and sequencing data,
# to preprocess leaving only overlapping genes and samples with complete 
# subtype information, and to split the data into training and testing sets
# It should be run from the command line through the run_experiments.R script

suppressMessages(source("load_packages.R"))

args <- commandArgs(trailingOnly = TRUE)
initial.seed <- as.integer(args[1])
set.seed(initial.seed)

data.dir <- "data"
seq.exprs.filename <- "BRCARNASeq.pcl"
array.exprs.filename <- "BRCAarray.pcl"
seq.clin.filename <- "BRCARNASeqClin.tsv"
array.clin.filename <- "BRCAClin.tsv"

plot.dir <- "plots"
subtype.distribtion.plot <- 
  paste0("BRCA_PAM50_subtypes_dist_split_stacked_bar_", initial.seed, ".pdf")

res.dir <- "results"
train.test.labels <- 
  paste0("BRCA_matchedSamples_PAM50Array_training_testing_split_labels_", 
         initial.seed, ".tsv")

#### read in expression and clinical data --------------------------------------

# read in expression data as data.frame
seq.data <- fread(file.path(data.dir, seq.exprs.filename), 
                  data.table = FALSE)
array.data <- fread(file.path(data.dir, array.exprs.filename), 
                    data.table = FALSE)
seq.clinical <- fread(file.path(data.dir, seq.clin.filename), 
                      data.table = FALSE)
array.clinical <- fread(file.path(data.dir, array.clin.filename), 
                        data.table = FALSE)

# change first column name to "gene"
colnames(array.data)[1] <- colnames(seq.data)[1] <- "gene"

# remove tumor-adjacent samples from the array data set
array.tumor.smpls <- 
  array.clinical$Sample[which(array.clinical$Type == "tumor")]
array.tumor.smpls <- substr(array.tumor.smpls, 1, 15)

array.subtypes <- array.clinical$PAM50[which(array.clinical$Type == "tumor")]

# filter array data only to include tumor samples
array.data <- array.data[, c(1, which(colnames(array.data) %in% 
                                        array.tumor.smpls))]


# what are the overlapping sample names -- "matched" samples?
sample.overlap <- intersect(colnames(array.data), colnames(seq.data))

# what are the overlapping genes between the two platforms?
gene.overlap <- intersect(array.data$gene, seq.data$gene)

# filter the expression data for matched samples and overlapping genes
array.matched <- array.data[which(array.data$gene %in% gene.overlap), 
                            sample.overlap]
seq.matched <- seq.data[which(seq.data$gene %in% gene.overlap),
                        sample.overlap]

# reorder genes on both platforms
array.matched <- array.matched[order(array.matched$gene), ]
seq.matched <- seq.matched[order(seq.matched$gene), ]

# reorder samples on both platforms
array.matched <- array.matched[, c(1, (order(colnames(array.matched)
                                             [2:ncol(array.matched)]) + 1))]
seq.matched <- seq.matched[, c(1, (order(colnames(seq.matched)
                                         [2:ncol(seq.matched)]) + 1))]

#  remove subtype labels for samples missing expression data
array.subtypes <- as.factor(array.subtypes[-which(!(array.tumor.smpls %in% 
                                              colnames(array.matched)))])

array.tumor.smpls <- array.tumor.smpls[-which(!(array.tumor.smpls %in% 
                                            colnames(array.matched)))]

# remove "unmatched" / "raw" expression data  
rm(array.data, seq.data)

# write matched only samples to pcl files
array.output.nm <- sub(".pcl", "_matchedOnly_ordered.pcl", array.exprs.filename)
array.output.nm <- file.path(data.dir, array.output.nm)
write.table(array.matched, file = array.output.nm, row.names = FALSE, 
            quote = FALSE, sep = "\t")

seq.output.nm <- sub(".pcl", "_matchedOnly_ordered.pcl", seq.exprs.filename)
seq.output.nm <- file.path(data.dir, seq.output.nm)
write.table(seq.matched, file = seq.output.nm, row.names = FALSE, 
            quote = FALSE, sep = "\t")

#### split data into balanced training and testing sets ------------------------

# order array subtypes to match the expression data order
array.subtypes <- array.subtypes[order(array.tumor.smpls)]

split.seed <- sample(1:10000, 1)
message(paste("\nRandom seed for splitting into testing and training:", 
              split.seed), appendLF = TRUE)

set.seed(split.seed)
train.index <- unlist(createDataPartition(array.subtypes, times = 1, p = (2/3)))

#### plot subtype distributions ------------------------------------------------
whole.df <- cbind(as.character(array.subtypes),
                  rep("whole", length(array.subtypes)))
train.df <- cbind(as.character(array.subtypes[train.index]), 
                  rep("train (2/3)", length(train.index)))
test.df <- cbind(as.character(array.subtypes[-train.index]), 
                 rep("test (1/3)", 
                     (length(array.subtypes)-length(train.index))))
mstr.df <- rbind(whole.df, train.df, test.df)

colnames(mstr.df) <- c("subtype", "split")
cbPalette <- c("#000000", "#E69F00", "#56B4E9", 
              "#009E73", "#F0E442","#0072B2", "#D55E00", "#CC79A7")

plot.nm <- file.path(plot.dir, subtype.distribtion.plot)
ggplot(as.data.frame(mstr.df), aes(x = split, fill = subtype)) + geom_bar() +
  theme_classic() + scale_fill_manual(values = cbPalette)
ggsave(plot.nm, plot = last_plot(), height = 6, width = 6)

#### write training/test labels to file ----------------------------------------

lbl <- rep("test", length(array.tumor.smpls))
lbl[train.index] <- "train"
lbl.df <- cbind(colnames(array.matched)[2:ncol(array.matched)],
                lbl, as.character(array.subtypes))
colnames(lbl.df) <- c("sample", "split", "subtype")

write.table(lbl.df, 
            file = file.path(res.dir, train.test.labels), 
            quote = FALSE, sep = "\t", row.names = FALSE)
