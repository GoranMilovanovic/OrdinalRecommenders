
### --------------------------------------------------
### --- Recommender Systems: Ordinal Logistic Regression
### --- Goran S. Milovanović, PhD
### --- Data Kolektiv, Belgrade, Serbia
### --- Developed for: SmartCat, Novi Sad, Serbia
### --- 25 February 2017.
### --- MovieLens 100K Data Set
### --------------------------------------------------

### --------------------------------------------------
### --- The MovieLens 100K Dataset:
### --- F. Maxwell Harper and Joseph A. Konstan. 2015. 
### --- The MovieLens Datasets: History and Context. 
### --- ACM Transactions on Interactive Intelligent Systems
### --- (TiiS) 5, 4, Article 19 (December 2015), 19 pages. 
### --- DOI=http://dx.doi.org/10.1145/2827872
### --------------------------------------------------

### --------------------------------------------------
### --- Part 3A: Model w. clm() {ordinal}
### --- No imputation
### --- Store 100 nearest neighbours from
### --- distance and similarity matrices
### --------------------------------------------------

rm(list = ls())
library(ordinal)
library(dplyr)

### --- load data
setwd('./outputs100K')
# - load features and produce modelFrame:
proxUsersRatingsFrame <- read.csv('proxUsersRatingsFrame100_Feat.csv',
                                  row.names = 1,
                                  header = T)
simUsersRatingsFrame <- read.csv('simUsersRatingsFrame100_Feat.csv',
                                 row.names = 1,
                                 header = T)
proxItemsRatingsFrame <- read.csv('proxItemsRatingsFrame100_Feat.csv',
                                  row.names = 1,
                                  header = T)
simItemsRatingsFrame <- read.csv('simItemsRatingsFrame100_Feat.csv',
                                 row.names = 1,
                                 header = T)
ratingsData <- read.csv("ratingsData_Model.csv",
                        row.names = 1,
                        header = T)
ratingsData$Timestamp <- NULL

### --- 10-fold cross-validation for each:
### --- numSims <- seq(5, 25, by = 5)
numSims <- seq(5, 30, by = 5)
meanRMSE <- numeric(length(numSims))
totalN <- dim(ratingsData)[1]
n <- numeric(length(numSims))
ct <- 0
for (k in numSims) {
  
  ## -- loop counter
  ct <- ct + 1
  
  ## -- report
  print(paste0("Ordinal Logistic Regression w. ",
               k, " nearest neighbours running:"))
  
  ## -- Prepare modelFrame:
  # - select variables:
  f1 <- select(proxUsersRatingsFrame, 
               starts_with('proxUsersRatings_')[1:k])
  f2 <- select(simUsersRatingsFrame, 
               starts_with('simUsersRatings_')[1:k])
  f3 <- select(proxItemsRatingsFrame, 
               starts_with('proxItemsRatings_')[1:k])
  f4 <- select(simItemsRatingsFrame, 
               starts_with('simItemsRatings_')[1:k])
  # - modelFrame:
  mFrame <- cbind(f1, f2, f3, f4, ratingsData$Rating)
  colnames(mFrame)[dim(mFrame)[2]] <- 'Rating'
  # - Keep complete observations only:
  mFrame <- mFrame[complete.cases(mFrame), ]
  # - store sample size:
  n[ct] <- dim(mFrame)[1]
  # - Rating as ordered factor for clm():
  mFrame$Rating <- factor(mFrame$Rating, ordered = T)
  # - clean up a bit:
  rm('f1', 'f2', 'f3', 'f4'); gc()
  
  # - model for the whole data set (no CV):
  mFitAll <- clm(Rating ~ .,
                 data = mFrame)
  saveRDS(mFitAll, paste0("OrdinalModel_", k, "Feats.Rds"))
  
  ## -- 10-fold cross-validation
  set.seed(10071974)
  # - folds:
  foldSize <- round(length(mFrame$Rating)/10)
  foldRem <- length(mFrame$Rating) - 10*foldSize
  foldSizes <- rep(foldSize, 9)
  foldSizes[10] <- foldSize + foldRem
  foldInx <- numeric()
  for (i in 1:length(foldSizes)) {
    foldInx <- append(foldInx, rep(i,foldSizes[i]))
  }
  foldInx <- sample(foldInx)
  
  RMSE <- numeric(10)
  for (i in 1:10) {
    # - train and test data sets
    trainFrame <- mFrame[which(foldInx != i), ]
    testFrame <- mFrame[which(foldInx == i), ]
    # - model
    mFit <- clm(Rating ~ .,
                data = trainFrame)
    
    # - predict test set:
    predictions <- predict(mFit, newdata = testFrame, 
                           type = "class")$fit
    
    # - RMSE:
    dataPoints <- length(testFrame$Rating)
    RMSE[i] <- 
      sum((as.numeric(predictions)-as.numeric(testFrame$Rating))^2)/dataPoints
    print(paste0(i, "-th fold, RMSE:", RMSE[i]))
  }
  
  ## -- store mean RMSE over 10 folds:
  meanRMSE[ct] <- mean(RMSE)
  print(meanRMSE[ct])
  
  ## -- clean up:
  rm('testFrame', 'trainFrame', 'mFrame'); gc()
}

resultsFrame <- data.frame(numSims = numSims,
                           sampleSize = n/totalN,
                           averageRMSE = meanRMSE)
saveRDS(resultsFrame, 'resultsFrame_NoImputation.Rds')


### --- Analysis
library(tidyr)
library(ggplot2)

### --- plot average RMSE from 10-fold CV vs. number of NNs
resultsFrame <- readRDS('resultsFrame_NoImputation.Rds')
ggplot(resultsFrame, aes(x = numSims, 
                         y = averageRMSE, 
                         label = paste0(round(resultsFrame$sampleSize*100,2),"%"))) +
  geom_path(color = "firebrick", size = .25) + 
  geom_point(size = 1.5, color = "firebrick") +
  geom_point(size = 1, color = "white") +
  theme_bw() + ggtitle('100k MovieLens dataset\nRMSE from CLM() Predictions') +
  xlab("Number of Features used per Feature Category") +
  ylab("Average RMSE (10-fold CV)") +
  theme(axis.title.x = element_text(size = 8)) +
  theme(axis.title.y = element_text(size = 8)) +
  theme(plot.title = element_text(size = 9.5)) +
  geom_text(size = 3, hjust = -.1, vjust = -.25) +
  scale_x_continuous(breaks = seq(5, 30, by = 5),
                     labels = seq(5, 30, by = 5))

### --- Inspect regression coefficients:
### --- no CV, full data sets used to fit clm()
### --- average exp(regression coefficients) + ranges
modelFiles <- list.files()[grepl("OrdinalModel_[[:digit:]]", list.files())]
AIC <- numeric(length(modelFiles))
proxUsersCoeff <- numeric(length(modelFiles))
simUsersCoeff <- numeric(length(modelFiles))
proxItemsCoeff <- numeric(length(modelFiles))
simItemsCoeff <- numeric(length(modelFiles))
proxUsersCoeffMin <- numeric(length(modelFiles))
simUsersCoeffMin <- numeric(length(modelFiles))
proxItemsCoeffMin <- numeric(length(modelFiles))
simItemsCoeffMin <- numeric(length(modelFiles))
proxUsersCoeffMax <- numeric(length(modelFiles))
simUsersCoeffMax <- numeric(length(modelFiles))
proxItemsCoeffMax <- numeric(length(modelFiles))
simItemsCoeffMax <- numeric(length(modelFiles))
numFeats <- numeric(length(modelFiles))

for (i in seq(5, 30, by = 5)) {
  fileName <- modelFiles[which(grepl(paste0("l_",i,"F"), modelFiles, fixed = T))]
  model <- readRDS(fileName)
  coeffs <- exp(model$beta)
  proxUsersCoeff[i/5] <- median(coeffs[which(grepl("proxUsers", names(coeffs), fixed = T))])
  simUsersCoeff[i/5] <- median(coeffs[which(grepl("simUsers", names(coeffs), fixed = T))])
  proxItemsCoeff[i/5] <- median(coeffs[which(grepl("proxItems", names(coeffs), fixed = T))])
  simItemsCoeff[i/5] <- median(coeffs[which(grepl("simItems", names(coeffs), fixed = T))])
  proxUsersCoeffMin[i/5] <- min(coeffs[which(grepl("proxUsers", names(coeffs), fixed = T))])
  simUsersCoeffMin[i/5] <- min(coeffs[which(grepl("simUsers", names(coeffs), fixed = T))])
  proxItemsCoeffMin[i/5] <- min(coeffs[which(grepl("proxItems", names(coeffs), fixed = T))])
  simItemsCoeffMin[i/5] <- min(coeffs[which(grepl("simItems", names(coeffs), fixed = T))])
  proxUsersCoeffMax[i/5] <- max(coeffs[which(grepl("proxUsers", names(coeffs), fixed = T))])
  simUsersCoeffMax[i/5] <- max(coeffs[which(grepl("simUsers", names(coeffs), fixed = T))])
  proxItemsCoeffMax[i/5] <- max(coeffs[which(grepl("proxItems", names(coeffs), fixed = T))])
  simItemsCoeffMax[i/5] <- max(coeffs[which(grepl("simItems", names(coeffs), fixed = T))])
  AIC[i/5] <-  as.numeric(levels(model$info$AIC))
  numFeats[i/5] <- i
}
regPlotFrame <- data.frame(numFeats,
                           proxUsersCoeff, simUsersCoeff, proxItemsCoeff, simItemsCoeff)
regPlotFrame <- regPlotFrame %>% 
  gather(key = Regressor,
         value = Coefficient,
         proxUsersCoeff:simItemsCoeff)
regPlotFrame$Min <- c(proxUsersCoeffMin, simUsersCoeffMin, proxItemsCoeffMin, simItemsCoeffMin)
regPlotFrame$Max <- c(proxUsersCoeffMax, simUsersCoeffMax, proxItemsCoeffMax, simItemsCoeffMax)

### --- plot AIC vs. number of NNs
aicFrame <- data.frame(numSims = resultsFrame$numSims,
                       AIC = AIC)
write.csv(aicFrame, 'Akaike_Frame_NoImputation.csv')

ggplot(resultsFrame, aes(x = numSims, 
                         y = AIC, 
                         label = paste0(round(resultsFrame$sampleSize*100,2),"%"))) +
  geom_path(color = "darkblue", size = .25) + 
  geom_point(size = 1.5, color = "darkblue") +
  geom_point(size = 1, color = "white") +
  theme_bw() + ggtitle('100k MovieLens dataset\nAIC from CLM() Predictions') +
  xlab("Number of Features used per Feature Category") +
  ylab("AIC") +
  theme(axis.title.x = element_text(size = 8)) +
  theme(axis.title.y = element_text(size = 8)) +
  theme(plot.title = element_text(size = 9.5)) +
  scale_x_continuous(breaks = seq(5, 30, by = 5),
                     labels = seq(5, 30, by = 5))

### --- plot regression coefficients
# Define the top and bottom of the errorbars
limits <- aes(ymax = Max, ymin = Min)
dodge <- position_dodge(width = 1)
ggplot(regPlotFrame, aes(x = numFeats, 
                         y = Coefficient, 
                         color = Regressor)) +
  geom_errorbar(limits, width = 3, size = .25, position = dodge) +
  geom_path(size = .25, position = dodge) + 
  geom_point(size = 1.5, position = dodge) +
  theme_bw() + ggtitle('100k MovieLens dataset\nMedian Exp(Coefficient) and Range') +
  xlab("Number of Features used per Feature Category") +
  ylab("Coefficient") +
  theme(axis.title.x = element_text(size = 8)) +
  theme(axis.title.y = element_text(size = 8)) +
  theme(plot.title = element_text(size = 9.5)) +
  theme(legend.key = element_blank()) +
  scale_x_continuous(breaks = seq(5, 30, by = 5),
                     labels = seq(5, 30, by = 5))


### --------------------------------------------------
### --- Part 3.B: Model w. clm() {ordinal}
### --- No imputation
### --- Store 100 nearest neighbours from
### --- similarity matrices ONLY
### --------------------------------------------------

rm(list = ls())
library(ordinal)
library(dplyr)

### --- load data
setwd('./outputs100K')
# - load features and produce modelFrame:
simUsersRatingsFrame <- read.csv('simUsersRatingsFrame100_Feat.csv',
                                 row.names = 1,
                                 header = T)
simItemsRatingsFrame <- read.csv('simItemsRatingsFrame100_Feat.csv',
                                 row.names = 1,
                                 header = T)
ratingsData <- read.csv("ratingsData_Model.csv",
                        row.names = 1,
                        header = T)
ratingsData$Timestamp <- NULL

### --- 10-fold cross-validation for each:
### --- numSims <- seq(5, 25, by = 5)
numSims <- seq(5, 30, by = 5)
meanRMSE <- numeric(length(numSims))
totalN <- dim(ratingsData)[1]
n <- numeric(length(numSims))
ct <- 0
for (k in numSims) {
  
  ## -- loop counter
  ct <- ct + 1
  
  ## -- report
  print(paste0("Ordinal Logistic Regression w. ",
               k, " nearest neighbours running:"))
  
  ## -- Prepare modelFrame:
  # - select variables:
  f1 <- select(simUsersRatingsFrame, 
               starts_with('simUsersRatings_')[1:k])
  f2 <- select(simItemsRatingsFrame, 
               starts_with('simItemsRatings_')[1:k])
  # - modelFrame:
  mFrame <- cbind(f1, f2, ratingsData$Rating)
  colnames(mFrame)[dim(mFrame)[2]] <- 'Rating'
  # - Keep complete observations only:
  mFrame <- mFrame[complete.cases(mFrame), ]
  # - store sample size:
  n[ct] <- dim(mFrame)[1]
  # - Rating as ordered factor for clm():
  mFrame$Rating <- factor(mFrame$Rating, ordered = T)
  # - clean up a bit:
  rm('f1', 'f2'); gc()
  
  # - model for the whole data set (no CV):
  mFitAll <- clm(Rating ~ .,
                 data = mFrame)
  saveRDS(mFitAll, paste0("OrdinalModel_SimMatricesOnly_", k, "Feats.Rds"))
  
  ## -- 10-fold cross-validation
  # - ensure reproducibility:
  set.seed(10071974)
  # - folds:
  foldSize <- round(length(mFrame$Rating)/10)
  foldRem <- length(mFrame$Rating) - 10*foldSize
  foldSizes <- rep(foldSize, 9)
  foldSizes[10] <- foldSize + foldRem
  foldInx <- numeric()
  for (i in 1:length(foldSizes)) {
    foldInx <- append(foldInx, rep(i,foldSizes[i]))
  }
  foldInx <- sample(foldInx)
  
  RMSE <- numeric(10)
  for (i in 1:10) {
    # - train and test data sets
    trainFrame <- mFrame[which(foldInx != i), ]
    testFrame <- mFrame[which(foldInx == i), ]
    # - model
    mFit <- clm(Rating ~ .,
                data = trainFrame)
    
    # - predict test set:
    predictions <- predict(mFit, newdata = testFrame, 
                           type = "class")$fit
    
    # - RMSE:
    dataPoints <- length(testFrame$Rating)
    RMSE[i] <- 
      sum((as.numeric(predictions)-as.numeric(testFrame$Rating))^2)/dataPoints
    print(paste0(i, "-th fold, RMSE:", RMSE[i]))
  }
  
  ## -- store mean RMSE over 10 folds:
  meanRMSE[ct] <- mean(RMSE)
  print(meanRMSE[ct])
  
  ## -- clean up:
  rm('testFrame', 'trainFrame', 'mFrame'); gc()
}

resultsFrame <- data.frame(numSims = numSims,
                           sampleSize = n/totalN,
                           averageRMSE = meanRMSE)
saveRDS(resultsFrame, 'resultsFrame_NoImputation_SimMatricesOnly.Rds')

### --- Analysis
library(tidyr)
library(ggplot2)

### --- plot average RMSE from 10-fold CV vs. number of NNs
resultsFrame <- readRDS('resultsFrame_NoImputation_SimMatricesOnly.Rds')
ggplot(resultsFrame, aes(x = numSims, 
                         y = averageRMSE, 
                         label = paste0(round(resultsFrame$sampleSize*100,2),"%"))) +
  geom_path(color = "firebrick", size = .25) + 
  geom_point(size = 1.5, color = "firebrick") +
  geom_point(size = 1, color = "white") +
  theme_bw() + ggtitle('100k MovieLens dataset\nRMSE from CLM() Predictions\nNearest Neighbours from Similarity Matrices Only') +
  xlab("Number of Features used per Feature Category") +
  ylab("Average RMSE (10-fold CV)") +
  theme(axis.title.x = element_text(size = 8)) +
  theme(axis.title.y = element_text(size = 8)) +
  theme(plot.title = element_text(size = 9.5)) +
  geom_text(size = 3, hjust = -.1, vjust = -.25) +
  scale_x_continuous(breaks = seq(5, 30, by = 5),
                     labels = seq(5, 30, by = 5))

### --- Inspect regression coefficients:
### --- no CV, full data sets used to fit clm()
### --- average exp(regression coefficients) + ranges
modelFiles <- list.files()[grepl("OrdinalModel_SimMatricesOnly_", list.files(), fixed = T)]
AIC <- numeric(length(modelFiles))
simUsersCoeff <- numeric(length(modelFiles))
simItemsCoeff <- numeric(length(modelFiles))
simUsersCoeffMin <- numeric(length(modelFiles))
simItemsCoeffMin <- numeric(length(modelFiles))
simUsersCoeffMax <- numeric(length(modelFiles))
simItemsCoeffMax <- numeric(length(modelFiles))
numFeats <- numeric(length(modelFiles))

for (i in seq(5, 30, by = 5)) {
  fileName <- modelFiles[which(grepl(paste0("_",i,"F"), modelFiles, fixed = T))]
  model <- readRDS(fileName)
  coeffs <- exp(model$beta)
  simUsersCoeff[i/5] <- median(coeffs[which(grepl("simUsers", names(coeffs), fixed = T))])
  simItemsCoeff[i/5] <- median(coeffs[which(grepl("simItems", names(coeffs), fixed = T))])
  simUsersCoeffMin[i/5] <- min(coeffs[which(grepl("simUsers", names(coeffs), fixed = T))])
  simItemsCoeffMin[i/5] <- min(coeffs[which(grepl("simItems", names(coeffs), fixed = T))])
  simUsersCoeffMax[i/5] <- max(coeffs[which(grepl("simUsers", names(coeffs), fixed = T))])
  simItemsCoeffMax[i/5] <- max(coeffs[which(grepl("simItems", names(coeffs), fixed = T))])
  AIC[i/5] <-  as.numeric(levels(model$info$AIC))
  numFeats[i/5] <- i
}
regPlotFrame <- data.frame(numFeats,
                           simUsersCoeff, simItemsCoeff)
regPlotFrame <- regPlotFrame %>% 
  gather(key = Regressor,
         value = Coefficient,
         simUsersCoeff:simItemsCoeff)
regPlotFrame$Min <- c(simUsersCoeffMin, simItemsCoeffMin)
regPlotFrame$Max <- c(simUsersCoeffMax, simItemsCoeffMax)

### --- plot AIC vs. number of NNs
aicFrame <- data.frame(numSims = resultsFrame$numSims,
                       AIC = AIC)
write.csv(aicFrame, 'Akaike_NoImputation_SimMatricesOnly.csv')
ggplot(resultsFrame, aes(x = numSims, 
                         y = AIC, 
                         label = paste0(round(resultsFrame$sampleSize*100,2),"%"))) +
  geom_path(color = "darkblue", size = .25) + 
  geom_point(size = 1.5, color = "darkblue") +
  geom_point(size = 1, color = "white") +
  theme_bw() + ggtitle('100k MovieLens dataset\nAIC from CLM() Predictions') +
  xlab("Number of Features used per Feature Category") +
  ylab("AIC") +
  theme(axis.title.x = element_text(size = 8)) +
  theme(axis.title.y = element_text(size = 8)) +
  theme(plot.title = element_text(size = 9.5)) +
  scale_x_continuous(breaks = seq(5, 30, by = 5),
                     labels = seq(5, 30, by = 5))

### --- plot regression coefficients
# Define the top and bottom of the errorbars
limits <- aes(ymax = Max, ymin = Min)
dodge <- position_dodge(width = 1)
ggplot(regPlotFrame, aes(x = numFeats, 
                         y = Coefficient, 
                         color = Regressor)) +
  geom_errorbar(limits, width = 3, size = .25, position = dodge) +
  geom_path(size = .25, position = dodge) + 
  geom_point(size = 1.5, position = dodge) +
  theme_bw() + ggtitle('100k MovieLens dataset\nMedian Exp(Coefficient) and Range') +
  xlab("Number of Features used per Feature Category") +
  ylab("Coefficient") +
  theme(axis.title.x = element_text(size = 8)) +
  theme(axis.title.y = element_text(size = 8)) +
  theme(plot.title = element_text(size = 9.5)) +
  theme(legend.key = element_blank()) +
  scale_x_continuous(breaks = seq(5, 30, by = 5),
                     labels = seq(5, 30, by = 5))


### --------------------------------------------------
### --- Part 3.C: Model w. clm() {ordinal}
### --- No imputation
### --- Store 100 nearest neighbours from
### --- proximity matrices ONLY
### --------------------------------------------------

rm(list = ls())
library(ordinal)
library(dplyr)

### --- load data
setwd('./outputs100K')
# - load features and produce modelFrame:
proxUsersRatingsFrame <- read.csv('proxUsersRatingsFrame100_Feat.csv',
                                  row.names = 1,
                                  header = T)
proxItemsRatingsFrame <- read.csv('proxItemsRatingsFrame100_Feat.csv',
                                  row.names = 1,
                                  header = T)
ratingsData <- read.csv("ratingsData_Model.csv",
                        row.names = 1,
                        header = T)
ratingsData$Timestamp <- NULL

### --- 10-fold cross-validation for each:
### --- numSims <- seq(5, 25, by = 5)
numSims <- seq(5, 30, by = 5)
meanRMSE <- numeric(length(numSims))
totalN <- dim(ratingsData)[1]
n <- numeric(length(numSims))
ct <- 0
for (k in numSims) {
  
  ## -- loop counter
  ct <- ct + 1
  
  ## -- report
  print(paste0("Ordinal Logistic Regression w. ",
               k, " nearest neighbours running:"))
  
  ## -- Prepare modelFrame:
  # - select variables:
  f1 <- select(proxUsersRatingsFrame, 
               starts_with('proxUsersRatings_')[1:k])
  f2 <- select(proxItemsRatingsFrame, 
               starts_with('proxItemsRatings_')[1:k])
  # - modelFrame:
  mFrame <- cbind(f1, f2, ratingsData$Rating)
  colnames(mFrame)[dim(mFrame)[2]] <- 'Rating'
  # - Keep complete observations only:
  mFrame <- mFrame[complete.cases(mFrame), ]
  # - store sample size:
  n[ct] <- dim(mFrame)[1]
  # - Rating as ordered factor for clm():
  mFrame$Rating <- factor(mFrame$Rating, ordered = T)
  # - clean up a bit:
  rm('f1', 'f2'); gc()
  
  # - model for the whole data set (no CV):
  mFitAll <- clm(Rating ~ .,
                 data = mFrame)
  saveRDS(mFitAll, paste0("OrdinalModel_ProxMatricesOnly_", k, "Feats.Rds"))
  
  ## -- 10-fold cross-validation
  # - ensure reproducibility:
  set.seed(10071974)
  # - folds:
  foldSize <- round(length(mFrame$Rating)/10)
  foldRem <- length(mFrame$Rating) - 10*foldSize
  foldSizes <- rep(foldSize, 9)
  foldSizes[10] <- foldSize + foldRem
  foldInx <- numeric()
  for (i in 1:length(foldSizes)) {
    foldInx <- append(foldInx, rep(i,foldSizes[i]))
  }
  foldInx <- sample(foldInx)
  
  RMSE <- numeric(10)
  for (i in 1:10) {
    # - train and test data sets
    trainFrame <- mFrame[which(foldInx != i), ]
    testFrame <- mFrame[which(foldInx == i), ]
    # - model
    mFit <- clm(Rating ~ .,
                data = trainFrame)
    
    # - predict test set:
    predictions <- predict(mFit, newdata = testFrame, 
                           type = "class")$fit
    
    # - RMSE:
    dataPoints <- length(testFrame$Rating)
    RMSE[i] <- 
      sum((as.numeric(predictions)-as.numeric(testFrame$Rating))^2)/dataPoints
    print(paste0(i, "-th fold, RMSE:", RMSE[i]))
  }
  
  ## -- store mean RMSE over 10 folds:
  meanRMSE[ct] <- mean(RMSE)
  print(meanRMSE[ct])
  
  ## -- clean up:
  rm('testFrame', 'trainFrame', 'mFrame'); gc()
}

resultsFrame <- data.frame(numSims = numSims,
                           sampleSize = n/totalN,
                           averageRMSE = meanRMSE)
saveRDS(resultsFrame, 'resultsFrame_NoImputation_ProxMatricesOnly.Rds')

### --- Analysis
library(tidyr)
library(ggplot2)

### --- plot average RMSE from 10-fold CV vs. number of NNs
resultsFrame <- readRDS('resultsFrame_NoImputation_ProxMatricesOnly.Rds')
ggplot(resultsFrame, aes(x = numSims, 
                         y = averageRMSE, 
                         label = paste0(round(resultsFrame$sampleSize*100,2),"%"))) +
  geom_path(color = "firebrick", size = .25) + 
  geom_point(size = 1.5, color = "firebrick") +
  geom_point(size = 1, color = "white") +
  theme_bw() + ggtitle('100k MovieLens dataset\nRMSE from CLM() Predictions') +
  xlab("Number of Features used per Feature Category") +
  ylab("Average RMSE (10-fold CV)") +
  theme(axis.title.x = element_text(size = 8)) +
  theme(axis.title.y = element_text(size = 8)) +
  theme(plot.title = element_text(size = 9.5)) +
  geom_text(size = 3, hjust = -.1, vjust = -.25) +
  scale_x_continuous(breaks = seq(5, 30, by = 5),
                     labels = seq(5, 30, by = 5))

### --- Inspect regression coefficients:
### --- no CV, full data sets used to fit clm()
### --- average exp(regression coefficients) + ranges
modelFiles <- list.files()[grepl("OrdinalModel_ProxMatricesOnly_", list.files(), fixed = T)]
AIC <- numeric(length(modelFiles))
proxUsersCoeff <- numeric(length(modelFiles))
proxItemsCoeff <- numeric(length(modelFiles))
proxUsersCoeffMin <- numeric(length(modelFiles))
proxItemsCoeffMin <- numeric(length(modelFiles))
proxUsersCoeffMax <- numeric(length(modelFiles))
proxItemsCoeffMax <- numeric(length(modelFiles))
numFeats <- numeric(length(modelFiles))

for (i in seq(5, 30, by = 5)) {
  fileName <- modelFiles[which(grepl(paste0("_",i,"F"), modelFiles, fixed = T))]
  model <- readRDS(fileName)
  coeffs <- exp(model$beta)
  proxUsersCoeff[i/5] <- median(coeffs[which(grepl("proxUsers", names(coeffs), fixed = T))])
  proxItemsCoeff[i/5] <- median(coeffs[which(grepl("proxItems", names(coeffs), fixed = T))])
  proxUsersCoeffMin[i/5] <- min(coeffs[which(grepl("proxUsers", names(coeffs), fixed = T))])
  proxItemsCoeffMin[i/5] <- min(coeffs[which(grepl("proxItems", names(coeffs), fixed = T))])
  proxUsersCoeffMax[i/5] <- max(coeffs[which(grepl("proxUsers", names(coeffs), fixed = T))])
  proxItemsCoeffMax[i/5] <- max(coeffs[which(grepl("proxItems", names(coeffs), fixed = T))])
  AIC[i/5] <-  as.numeric(levels(model$info$AIC))
  numFeats[i/5] <- i
}
regPlotFrame <- data.frame(numFeats,
                           proxUsersCoeff, proxItemsCoeff)
regPlotFrame <- regPlotFrame %>% 
  gather(key = Regressor,
         value = Coefficient,
         proxUsersCoeff:proxItemsCoeff)
regPlotFrame$Min <- c(proxUsersCoeffMin, proxItemsCoeffMin)
regPlotFrame$Max <- c(proxUsersCoeffMax, proxItemsCoeffMax)

### --- plot AIC vs. number of NNs
aicFrame <- data.frame(numSims = resultsFrame$numSims,
                       AIC = AIC)
write.csv(aicFrame, 'Akaike_NoImputation_ProxMatricesOnly.csv')
ggplot(resultsFrame, aes(x = numSims, 
                         y = AIC, 
                         label = paste0(round(resultsFrame$sampleSize*100,2),"%"))) +
  geom_path(color = "darkblue", size = .25) + 
  geom_point(size = 1.5, color = "darkblue") +
  geom_point(size = 1, color = "white") +
  theme_bw() + ggtitle('100k MovieLens dataset\nAIC from CLM() Predictions') +
  xlab("Number of Features used per Feature Category") +
  ylab("AIC") +
  theme(axis.title.x = element_text(size = 8)) +
  theme(axis.title.y = element_text(size = 8)) +
  theme(plot.title = element_text(size = 9.5)) +
  scale_x_continuous(breaks = seq(5, 30, by = 5),
                     labels = seq(5, 30, by = 5))

### --- plot regression coefficients
# Define the top and bottom of the errorbars
limits <- aes(ymax = Max, ymin = Min)
dodge <- position_dodge(width = 1)
ggplot(regPlotFrame, aes(x = numFeats, 
                         y = Coefficient, 
                         color = Regressor)) +
  geom_errorbar(limits, width = 3, size = .25, position = dodge) +
  geom_path(size = .25, position = dodge) + 
  geom_point(size = 1.5, position = dodge) +
  theme_bw() + ggtitle('100k MovieLens dataset\nMedian Exp(Coefficient) and Range') +
  xlab("Number of Features used per Feature Category") +
  ylab("Coefficient") +
  theme(axis.title.x = element_text(size = 8)) +
  theme(axis.title.y = element_text(size = 8)) +
  theme(plot.title = element_text(size = 9.5)) +
  theme(legend.key = element_blank()) +
  scale_x_continuous(breaks = seq(5, 30, by = 5),
                     labels = seq(5, 30, by = 5))


### --------------------------------------------------
### --- Part 3.D: Model w. clm() {ordinal}
### --- No imputation
### --- Model Selection:
### --- Proximity + Similarity Neighbourhoods VS
### --- Similarity Neighbourhoods Only
### --------------------------------------------------

modelFiles <- list.files()
modelRes <- matrix(rep(0,6*7), nrow = 6, ncol = 7)
numSims <- seq(5, 30, by = 5)
ct = 0
for (k in numSims) {
  ct = ct + 1
  fileNameSimProx <- modelFiles[which(grepl(paste0("Model_",k,"F"), modelFiles, fixed = T))]
  modelSimProx <- readRDS(fileNameSimProx)
  fileNameSim <- modelFiles[which(grepl(paste0("SimMatricesOnly_",k,"F"), modelFiles, fixed = T))]
  modelSim <- readRDS(fileNameSim)
  testRes <- anova(modelSimProx, modelSim)
  modelRes[ct, ] <- c(testRes$no.par, testRes$AIC, testRes$LR.stat[2],
                     testRes$df[2], testRes$`Pr(>Chisq)`[2])
}
modelRes <- as.data.frame(modelRes)
colnames(modelRes) <- c('Parameters_Model1', 'Parameters_Model2',
                        'AIC_Model1', 'AIC_Model2',
                        'LRTest','DF','Pr_TypeIErr')
write.csv(modelRes, 'ModelSelection.csv')



